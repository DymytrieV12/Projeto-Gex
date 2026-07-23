import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/carrinho_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/pagamento_sheet.dart';

class CarrinhoScreen extends StatefulWidget {
  const CarrinhoScreen({super.key});
  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  bool _finalizando = false;
  bool _loadingOpcoes = true;
  bool _panelExpanded = false;
  List<FormaPagamento> _formasPagamento = [];
  List<TipoEntrega> _tiposEntrega = [];
  List<DescontoProgressivo> _faixasDesconto = [];
  GreenCash? _greenCash;
  FormaPagamento? _formaSelecionada;
  TipoEntrega? _entregaSelecionada;
  int _parcelas = 1;
  double _valorFrete = 0;
  bool _calcFrete = false;
  bool _usarGreenCash = false;
  double _greenCashUsado = 0;
  final _obsC = TextEditingController();
  final _gcC = TextEditingController();

  static const _pgtoPermitidos = {1, 3};

  @override
  void initState() { super.initState(); _loadOpcoes(); }
  @override
  void dispose() { _obsC.dispose(); _gcC.dispose(); super.dispose(); }

  Future<void> _loadOpcoes() async {
    setState(() => _loadingOpcoes = true);
    final results = await Future.wait([
      ApiService.getFormasPagamento(),
      ApiService.getTiposEntrega(),
      ApiService.getDescontoProgressivo(),
      ApiService.getGreenCash(),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0]['success'] == true) { final all = (results[0]['data'] as List).map((j) => FormaPagamento.fromJson(j)).toList(); _formasPagamento = all.where((f) => _pgtoPermitidos.contains(f.id)).toList(); if (_formasPagamento.isNotEmpty) _formaSelecionada = _formasPagamento.first; }
      if (results[1]['success'] == true) {
        final all = (results[1]['data'] as List).map((j) => TipoEntrega.fromJson(j)).toList();
        final fixa = all.where((t) => t.id == 2).cast<TipoEntrega?>().firstWhere(
          (t) => t != null,
          orElse: () => null,
        );
        final selecionada = fixa ?? TipoEntrega(id: 2, descricao: 'Entrega padrão');
        _tiposEntrega = [selecionada];
        _entregaSelecionada = selecionada;
      }
      if (results[2]['success'] == true) { _faixasDesconto = (results[2]['data'] as List).map((j) => DescontoProgressivo.fromJson(j)).toList(); }
      if (results[3]['success'] == true && results[3]['data'] != null) { _greenCash = GreenCash.fromJson(results[3]['data'] as Map<String, dynamic>); }
      _loadingOpcoes = false;
    });
    if (_entregaSelecionada != null) _calcularFrete();
  }

  Future<void> _calcularFrete() async {
    if (_entregaSelecionada == null) return;
    final cart = context.read<CarrinhoProvider>();
    setState(() => _calcFrete = true);
    final r = await ApiService.calcularFrete(tipoEntrega: 2, valorTotal: cart.totalValor);
    if (!mounted) return;
    setState(() { _calcFrete = false; if (r['success'] == true) _valorFrete = (r['data']?['valorFrete'] as num?)?.toDouble() ?? 0; });
  }

  DescontoProgressivo? _descontoAtual(double s) => DescontoProgressivo.findApplicable(_faixasDesconto, s);
  DescontoProgressivo? _proximaFaixa(DescontoProgressivo? a) => DescontoProgressivo.findNext(_faixasDesconto, a);

  double get _saldoGC => _greenCash?.saldoDisponivel ?? 0;

  void _toggleGreenCash(bool v, double maxValue) {
    setState(() {
      _usarGreenCash = v;
      if (v) {
        _greenCashUsado = _saldoGC > maxValue ? maxValue : _saldoGC;
        _gcC.text = _greenCashUsado.toStringAsFixed(2);
      } else {
        _greenCashUsado = 0;
        _gcC.clear();
      }
    });
  }

  String? _extractPedidoRef(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      final raw = data['numeroPedido'] ?? data['numero'] ?? data['idPedido'] ?? data['id'];
      final text = raw?.toString();
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    final text = data.toString().trim();
    if (text.isEmpty || text == '{}' || text.toLowerCase() == 'null') return null;
    final digits = RegExp(r'\d+').firstMatch(text)?.group(0);
    return digits ?? text;
  }

  Future<Pedido?> _resolverPedidoPagamento(dynamic data) async {
    if (data is Map<String, dynamic>) {
      final criado = Pedido.fromJson(data);
      if (criado.temDadosPagamento) return criado;
    } else if (data is Map) {
      final criado = Pedido.fromJson(Map<String, dynamic>.from(data));
      if (criado.temDadosPagamento) return criado;
    }

    final ref = _extractPedidoRef(data);
    final pedidosResp = await ApiService.getPedidosRevendedor(pageSize: 20);
    if (pedidosResp['success'] != true) return null;

    final lista = (pedidosResp['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Pedido.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    lista.sort((a, b) {
      if (a.dataPedido == null && b.dataPedido == null) return 0;
      if (a.dataPedido == null) return 1;
      if (b.dataPedido == null) return -1;
      return b.dataPedido!.compareTo(a.dataPedido!);
    });

    if (ref != null) {
      for (final pedido in lista) {
        if (pedido.numeroPedido == ref || pedido.id == ref) return pedido;
      }
    }

    for (final pedido in lista) {
      if (pedido.temDadosPagamento) return pedido;
    }

    return lista.isNotEmpty ? lista.first : null;
  }

  Future<void> _finalizarPedido() async {
    final cart = context.read<CarrinhoProvider>();
    if (cart.itens.isEmpty || _formaSelecionada == null || _entregaSelecionada == null) return;
    setState(() => _finalizando = true);
    final subtotal = cart.totalValor;
    final desc = _descontoAtual(subtotal);
    final pct = desc?.descontoPorcentagem ?? 0;
    final valDesc = subtotal * (pct / 100);
    final subtotalDesc = subtotal - valDesc;
    final total = (subtotalDesc + _valorFrete) - _greenCashUsado;
    final produtos = cart.itens.map((i) => {'produtoId': int.tryParse(i.produtoId) ?? 0, 'quantidade': i.quantidade, 'valor': i.preco}).toList();
    final obs = _obsC.text.trim().isEmpty ? 'Pedido via App' : _obsC.text.trim();
    final r = await ApiService.criarPedido(
      formaPagamentoId: _formaSelecionada!.id,
      tipoEntrega: 2,
      quantidadeParcela: _parcelas,
      valorTotal: total < 0 ? 0 : total,
      produtos: produtos,
      valorFrete: _valorFrete > 0 ? _valorFrete : null,
      observacao: obs,
      valorGreenCash: _greenCashUsado,
    );
    if (!mounted) return;
    setState(() => _finalizando = false);
    if (r['success'] == true) {
      final pedidoRef = _extractPedidoRef(r['data']);
      final usadoGreenCash = _greenCashUsado;
      final isBoletoPix = (_formaSelecionada?.descricao.toLowerCase().contains('boleto') ?? false) ||
          (_formaSelecionada?.descricao.toLowerCase().contains('pix') ?? false);
      Pedido? pedidoPagamento;
      if (isBoletoPix) {
        pedidoPagamento = await _resolverPedidoPagamento(r['data']);
      }

      cart.limpar();
      _obsC.clear();
      _usarGreenCash = false;
      _greenCashUsado = 0;
      _gcC.clear();

      if (!mounted) return;

      if (isBoletoPix && pedidoPagamento != null && pedidoPagamento.temDadosPagamento) {
        final linkPagto = pedidoPagamento.paginaPix ?? pedidoPagamento.linkPagamento;
        final linkValido = linkPagto != null &&
            linkPagto.trim().isNotEmpty &&
            (linkPagto.startsWith('http://') || linkPagto.startsWith('https://'));

        if (linkValido) {
          // Abre direto o link final de pagamento, quando a API já retornar esse link.
          await openPagamentoNoApp(context, linkPagto);
        } else {
          // Caso só exista o PDF do boleto, a sheet resolve o link exato do PIX a partir do PDF.
          await showPagamentoSheet(
            context,
            pedidoPagamento,
            fallbackNumero: pedidoRef,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #${pedidoRef ?? pedidoPagamento.numeroPedido ?? pedidoPagamento.id} criado com sucesso.'),
            backgroundColor: const Color(0xFF0E5A35),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF0E5A35), size: 32),
              SizedBox(width: 10),
              Text('Pedido criado!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pedido #${pedidoRef ?? ''} registrado com sucesso.'),
              if (pct > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Desconto aplicado: ${pct.toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF0E5A35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (usadoGreenCash > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Green Cash usado: R\$ ${usadoGreenCash.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF0E5A35),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (isBoletoPix) ...[
                const SizedBox(height: 8),
                Text(
                  'Os dados de pagamento ainda não foram retornados pela API. Você poderá visualizar o QR Code e o boleto na tela de pedidos assim que estiverem disponíveis.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Ver pedidos'),
            ),
          ],
        ),
      );
    } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${r['error'] ?? '?'}'), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final subtotal = cart.totalValor;
    final desc = _descontoAtual(subtotal);
    final pct = desc?.descontoPorcentagem ?? 0;
    final valDesc = subtotal * (pct / 100);
    final subtotalDesc = subtotal - valDesc;
    final totalAntesGC = subtotalDesc + _valorFrete;
    final maxGC = _saldoGC > totalAntesGC ? totalAntesGC : _saldoGC;
    // Garantir que GC nao excede o total
    if (_greenCashUsado > totalAntesGC) _greenCashUsado = totalAntesGC;
    final total = totalAntesGC - _greenCashUsado;
    final prox = _proximaFaixa(desc);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho'), actions: [
        if (cart.itens.isNotEmpty) TextButton(onPressed: () => cart.limpar(), child: const Text('Limpar', style: TextStyle(color: Colors.white))),
      ]),
      body: cart.itens.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey), SizedBox(height: 16), Text('Carrinho vazio', style: TextStyle(fontSize: 18, color: Colors.grey))]))
          : _loadingOpcoes ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              if (_faixasDesconto.isNotEmpty) _DiscountBanner(subtotal: subtotal, descontoAtual: desc, proximaFaixa: prox),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.itens.length,
                  itemBuilder: (context, index) {
                    final item = cart.itens[index];
                    final itemDesc = item.preco * (pct / 100);
                    final precoDesc = item.preco - itemDesc;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withValues(alpha: 0.12))),
                      child: Row(children: [
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                          child: item.imagemUrl != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(item.imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: Color(0xFF0E5A35)))) : const Icon(Icons.eco, color: Color(0xFF0E5A35))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.nomeProduto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (pct > 0) ...[
                            Text('R\$ ${item.preco.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 11, decoration: TextDecoration.lineThrough)),
                            Text('R\$ ${precoDesc.toStringAsFixed(2)} (-${pct.toInt()}%)', style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold, fontSize: 13)),
                          ] else Text('R\$ ${item.preco.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('Sub: R\$ ${(precoDesc * item.quantidade).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold, fontSize: 13)),
                        ])),
                        Column(children: [
                          Container(decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () => cart.updateQuantidade(item.produtoId, item.quantidade - 1), constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                              Text('${item.quantidade}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () => cart.updateQuantidade(item.produtoId, item.quantidade + 1), constraints: const BoxConstraints(minWidth: 30, minHeight: 30)),
                            ])),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => cart.removeItem(item.produtoId)),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => setState(() => _panelExpanded = !_panelExpanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999))),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (pct > 0) Text('Desconto ${pct.toInt()}%: -R\$ ${valDesc.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF0E5A35), fontSize: 12, fontWeight: FontWeight.w600)),
                            if (_valorFrete > 0) Text('Frete: R\$ ${_valorFrete.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            if (_greenCashUsado > 0) Text('Green Cash: -R\$ ${_greenCashUsado.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFE6A100), fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
                          ]),
                        ]),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_panelExpanded ? 'Compactar' : 'Expandir opcoes', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          Icon(_panelExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.grey[500]),
                        ]),
                      ]),
                    ),
                  ),
                  if (_panelExpanded) ...[
                    const Divider(height: 8),
                    _dropdownRow(Icons.local_shipping_outlined, 'Entrega:', DropdownButton<TipoEntrega>(
                      value: _entregaSelecionada, isExpanded: true, underline: const SizedBox(),
                      items: _tiposEntrega.map((t) => DropdownMenuItem(value: t, child: Text('${t.descricao} (fixo)', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: null)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Padding(padding: EdgeInsets.only(left: 28), child: Text('Frete:', style: TextStyle(fontSize: 13))),
                      _calcFrete ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_valorFrete == 0 ? 'Gratis' : 'R\$ ${_valorFrete.toStringAsFixed(2)}', style: TextStyle(color: _valorFrete == 0 ? const Color(0xFF0E5A35) : Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    const Divider(height: 14),
                    _dropdownRow(Icons.payment_outlined, 'Pagamento:', DropdownButton<FormaPagamento>(
                      value: _formaSelecionada, isExpanded: true, underline: const SizedBox(),
                      items: _formasPagamento.map((f) => DropdownMenuItem(value: f, child: Text(f.descricao, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() { _formaSelecionada = v; _parcelas = 1; }))),
                    // ────── GREEN CASH ──────
                    if (_greenCash != null && _saldoGC > 0) ...[
                      const Divider(height: 14),
                      _GreenCashSection(
                        saldoDisponivel: _saldoGC,
                        usar: _usarGreenCash,
                        valorUsado: _greenCashUsado,
                        maxValue: maxGC,
                        controller: _gcC,
                        onToggle: (v) => _toggleGreenCash(v, maxGC),
                        onChanged: (v) {
                          final n = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          setState(() {
                            _greenCashUsado = n > maxGC ? maxGC : n;
                            if (n > maxGC) _gcC.text = maxGC.toStringAsFixed(2);
                          });
                        },
                      ),
                    ] else if (_greenCash != null) ...[
                      const Divider(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Green Cash: R\$ ${_saldoGC.toStringAsFixed(2)} (sem saldo disponivel)', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                        ]),
                      ),
                    ],
                    const Divider(height: 14),
                    TextField(controller: _obsC, decoration: InputDecoration(hintText: 'Observacoes...', filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)), maxLines: 1, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    _summaryRow('Subtotal', 'R\$ ${subtotal.toStringAsFixed(2)}'),
                    if (pct > 0) _summaryRow('Desconto ${pct.toInt()}%', '- R\$ ${valDesc.toStringAsFixed(2)}', color: const Color(0xFF0E5A35)),
                    if (_valorFrete > 0) _summaryRow('Frete', 'R\$ ${_valorFrete.toStringAsFixed(2)}'),
                    if (_greenCashUsado > 0) _summaryRow('Green Cash', '- R\$ ${_greenCashUsado.toStringAsFixed(2)}', color: const Color(0xFFE6A100)),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _finalizando ? null : _finalizarPedido,
                    icon: _finalizando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Icon(Icons.check_circle),
                    label: Text(_finalizando ? 'Enviando...' : 'Finalizar Pedido'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  )),
                ]),
              ),
            ]),
    );
  }

  Widget _dropdownRow(IconData icon, String label, Widget dropdown) => Row(children: [Icon(icon, size: 20, color: const Color(0xFF0E5A35)), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 13)), const SizedBox(width: 8), Expanded(child: dropdown)]);
  Widget _summaryRow(String label, String value, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(label, style: TextStyle(color: color ?? Colors.grey[700], fontSize: 13), overflow: TextOverflow.ellipsis)), Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.black87, fontSize: 13))]));
}

class _GreenCashSection extends StatelessWidget {
  final double saldoDisponivel;
  final double maxValue;
  final bool usar;
  final double valorUsado;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onChanged;

  const _GreenCashSection({
    required this.saldoDisponivel,
    required this.maxValue,
    required this.usar,
    required this.valorUsado,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF8E1), Color(0xFFFFF3D6)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6A100).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet, color: Color(0xFFE6A100), size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Green Cash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8B6914)))),
          Switch(
            value: usar,
            onChanged: onToggle,
            activeColor: const Color(0xFFE6A100),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text('Saldo: R\$ ${saldoDisponivel.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF8B6914), fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        if (usar) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('Usar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  prefixStyle: const TextStyle(color: Color(0xFFE6A100), fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.7),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                onChanged: onChanged,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () { controller.text = maxValue.toStringAsFixed(2); onChanged(maxValue.toStringAsFixed(2)); },
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
              child: const Text('Max', style: TextStyle(fontSize: 11, color: Color(0xFFE6A100), fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Maximo: R\$ ${maxValue.toStringAsFixed(2)} (limite do total da compra)', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
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
    final valDesc = subtotal * (pct / 100);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B4D2C), Color(0xFF0E5A35)]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF0E5A35).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.discount, color: Colors.amber, size: 20), const SizedBox(width: 8), Text('Desconto ${pct.toInt()}% aplicado!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 4),
        Text('Economia de R\$ ${valDesc.toStringAsFixed(2)} neste pedido', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        if (proximaFaixa != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [const Icon(Icons.trending_up, color: Colors.amber, size: 16), const SizedBox(width: 6),
              Expanded(child: Text('Faltam R\$ ${(proximaFaixa!.valorMinimoCompra - subtotal).toStringAsFixed(2)} para ${proximaFaixa!.descontoPorcentagem.toInt()}%!', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)))])),
        ],
      ]),
    );
  }
}
