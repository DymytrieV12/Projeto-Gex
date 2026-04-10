import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/carrinho_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class CarrinhoScreen extends StatefulWidget {
  const CarrinhoScreen({super.key});
  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  bool _finalizando = false;
  bool _loadingOpcoes = true;
  List<FormaPagamento> _formasPagamento = [];
  List<TipoEntrega> _tiposEntrega = [];
  List<DescontoProgressivo> _faixasDesconto = [];
  FormaPagamento? _formaSelecionada;
  TipoEntrega? _entregaSelecionada;
  int _parcelas = 1;
  double _valorFrete = 0;
  bool _calcFrete = false;
  final _obsC = TextEditingController();

  static const _pgtoPermitidos = {1, 3};

  @override
  void initState() {
    super.initState();
    _loadOpcoes();
  }

  @override
  void dispose() {
    _obsC.dispose();
    super.dispose();
  }

  Future<void> _loadOpcoes() async {
    setState(() => _loadingOpcoes = true);
    final results = await Future.wait([
      ApiService.getFormasPagamento(),
      ApiService.getTiposEntrega(),
      ApiService.getDescontoProgressivo(),
    ]);
    if (!mounted) return;

    setState(() {
      if (results[0]['success'] == true) {
        final all = (results[0]['data'] as List).map((j) => FormaPagamento.fromJson(j)).toList();
        _formasPagamento = all.where((f) => _pgtoPermitidos.contains(f.id)).toList();
        if (_formasPagamento.isNotEmpty) _formaSelecionada = _formasPagamento.first;
      }

      if (results[1]['success'] == true) {
        final all = (results[1]['data'] as List).map((j) => TipoEntrega.fromJson(j)).toList();
        _tiposEntrega = all.where((t) {
          final desc = t.descricao.toLowerCase();
          return desc.contains('moto') || desc.contains('enviar') || desc.contains('receber em casa');
        }).toList();
        if (_tiposEntrega.isEmpty) _tiposEntrega = all;
        if (_tiposEntrega.isNotEmpty) _entregaSelecionada = _tiposEntrega.first;
      }

      if (results[2]['success'] == true) {
        _faixasDesconto = (results[2]['data'] as List)
            .map((j) => DescontoProgressivo.fromJson(j))
            .toList();
      }

      _loadingOpcoes = false;
    });

    if (_entregaSelecionada != null) _calcularFrete();
  }

  Future<void> _calcularFrete() async {
    if (_entregaSelecionada == null) return;
    final cart = context.read<CarrinhoProvider>();
    setState(() => _calcFrete = true);
    final r = await ApiService.calcularFrete(tipoEntrega: _entregaSelecionada!.id, valorTotal: cart.totalValor);
    if (!mounted) return;
    setState(() {
      _calcFrete = false;
      if (r['success'] == true) _valorFrete = (r['data']?['valorFrete'] as num?)?.toDouble() ?? 0;
    });
  }

  DescontoProgressivo? _descontoAtual(double subtotal) {
    return DescontoProgressivo.findApplicable(_faixasDesconto, subtotal);
  }

  DescontoProgressivo? _proximaFaixa(DescontoProgressivo? atual) {
    return DescontoProgressivo.findNext(_faixasDesconto, atual);
  }

  Future<void> _finalizarPedido() async {
    final cart = context.read<CarrinhoProvider>();
    if (cart.itens.isEmpty || _formaSelecionada == null || _entregaSelecionada == null) return;
    setState(() => _finalizando = true);

    final subtotal = cart.totalValor;
    final desconto = _descontoAtual(subtotal);
    final pctDesconto = desconto?.descontoPorcentagem ?? 0;
    final valorDesconto = subtotal * (pctDesconto / 100);
    final subtotalComDesconto = subtotal - valorDesconto;
    final total = subtotalComDesconto + _valorFrete;

    final produtos = cart.itens.map((i) => {
      'produtoId': int.tryParse(i.produtoId) ?? 0,
      'quantidade': i.quantidade,
      'valor': i.preco,
    }).toList();

    final obs = _obsC.text.trim().isEmpty ? 'Pedido via App' : _obsC.text.trim();

    final r = await ApiService.criarPedido(
      formaPagamentoId: _formaSelecionada!.id,
      tipoEntrega: _entregaSelecionada!.id,
      quantidadeParcela: _parcelas,
      valorTotal: total,
      produtos: produtos,
      valorFrete: _valorFrete > 0 ? _valorFrete : null,
      observacao: obs,
      valorGreenCash: 0,
    );

    if (!mounted) return;
    setState(() => _finalizando = false);

    if (r['success'] == true) {
      cart.limpar();
      _obsC.clear();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(children: [Icon(Icons.check_circle, color: Color(0xFF0E5A35), size: 32), SizedBox(width: 10), Text('Pedido Criado!')]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pedido #${r['data']?.toString() ?? ''} registrado!'),
              if (pctDesconto > 0) ...[
                const SizedBox(height: 8),
                Text('Desconto aplicado: ${pctDesconto.toInt()}%', style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Ver Pedidos'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${r['error'] ?? 'Desconhecido'}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final subtotal = cart.totalValor;
    final desconto = _descontoAtual(subtotal);
    final pctDesconto = desconto?.descontoPorcentagem ?? 0;
    final valorDesconto = subtotal * (pctDesconto / 100);
    final subtotalComDesconto = subtotal - valorDesconto;
    final total = subtotalComDesconto + _valorFrete;
    final proxFaixa = _proximaFaixa(desconto);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrinho'),
        actions: [
          if (cart.itens.isNotEmpty)
            TextButton(onPressed: () => cart.limpar(), child: const Text('Limpar', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: cart.itens.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey), SizedBox(height: 16), Text('Carrinho vazio', style: TextStyle(fontSize: 18, color: Colors.grey))]))
          : _loadingOpcoes
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Discount progress bar
                    if (_faixasDesconto.isNotEmpty)
                      _DiscountBanner(
                        subtotal: subtotal,
                        descontoAtual: desconto,
                        proximaFaixa: proxFaixa,
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: cart.itens.length,
                        itemBuilder: (context, index) {
                          final item = cart.itens[index];
                          final itemDesconto = item.preco * (pctDesconto / 100);
                          final precoComDesconto = item.preco - itemDesconto;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                  child: item.imagemUrl != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item.imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: Color(0xFF0E5A35))))
                                      : const Icon(Icons.eco, color: Color(0xFF0E5A35)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.nomeProduto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      if (pctDesconto > 0) ...[
                                        Text('R\$ ${item.preco.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 11, decoration: TextDecoration.lineThrough)),
                                        Text('R\$ ${precoComDesconto.toStringAsFixed(2)} (-${pctDesconto.toInt()}%)', style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold, fontSize: 13)),
                                      ] else
                                        Text('R\$ ${item.preco.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      Text('Sub: R\$ ${(precoComDesconto * item.quantidade).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => cart.updateQuantidade(item.produtoId, item.quantidade - 1), constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                                        Text('${item.quantidade}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => cart.updateQuantidade(item.produtoId, item.quantidade + 1), constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                                      ]),
                                    ),
                                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => cart.removeItem(item.produtoId)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Bottom checkout panel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _dropdownRow(Icons.local_shipping_outlined, 'Entrega:', DropdownButton<TipoEntrega>(
                            value: _entregaSelecionada, isExpanded: true, underline: const SizedBox(),
                            items: _tiposEntrega.map((t) => DropdownMenuItem(value: t, child: Text(t.descricao, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) { setState(() => _entregaSelecionada = v); _calcularFrete(); },
                          )),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Padding(padding: EdgeInsets.only(left: 28), child: Text('Frete:', style: TextStyle(fontSize: 13))),
                            _calcFrete ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_valorFrete == 0 ? 'Gratis' : 'R\$ ${_valorFrete.toStringAsFixed(2)}', style: TextStyle(color: _valorFrete == 0 ? const Color(0xFF0E5A35) : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                          const Divider(height: 14),
                          _dropdownRow(Icons.payment_outlined, 'Pagamento:', DropdownButton<FormaPagamento>(
                            value: _formaSelecionada, isExpanded: true, underline: const SizedBox(),
                            items: _formasPagamento.map((f) => DropdownMenuItem(value: f, child: Text(f.descricao, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() { _formaSelecionada = v; _parcelas = 1; }),
                          )),
                          const Divider(height: 14),
                          TextField(
                            controller: _obsC,
                            decoration: InputDecoration(hintText: 'Observacoes...', filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            maxLines: 1, style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          // Summary with discount
                          _summaryRow('Subtotal', 'R\$ ${subtotal.toStringAsFixed(2)}'),
                          if (pctDesconto > 0)
                            _summaryRow('Desconto ${pctDesconto.toInt()}% (${desconto?.descricao ?? ""})', '- R\$ ${valorDesconto.toStringAsFixed(2)}', color: const Color(0xFF0E5A35)),
                          if (_valorFrete > 0)
                            _summaryRow('Frete', 'R\$ ${_valorFrete.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
                          ]),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _finalizando ? null : _finalizarPedido,
                              icon: _finalizando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Icon(Icons.check_circle),
                              label: Text(_finalizando ? 'Enviando...' : 'Finalizar Pedido'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _dropdownRow(IconData icon, String label, Widget dropdown) {
    return Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF0E5A35)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 8),
      Expanded(child: dropdown),
    ]);
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(color: color ?? Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.black87, fontSize: 13)),
      ]),
    );
  }
}

class _DiscountBanner extends StatelessWidget {
  final double subtotal;
  final DescontoProgressivo? descontoAtual;
  final DescontoProgressivo? proximaFaixa;

  const _DiscountBanner({required this.subtotal, this.descontoAtual, this.proximaFaixa});

  @override
  Widget build(BuildContext context) {
    final pct = descontoAtual?.descontoPorcentagem ?? 0;
    final valorDesconto = subtotal * (pct / 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B4D2C), Color(0xFF0E5A35)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF0E5A35).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.discount, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Desconto ${pct.toInt()}% aplicado!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Economia de R\$ ${valorDesconto.toStringAsFixed(2)} neste pedido',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
          if (proximaFaixa != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Faltam R\$ ${(proximaFaixa!.valorMinimoCompra - subtotal).toStringAsFixed(2)} para ${proximaFaixa!.descontoPorcentagem.toInt()}% de desconto!',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
