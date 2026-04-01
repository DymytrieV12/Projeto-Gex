import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key});

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Pedido> _pedidos = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final response = await ApiService.getPedidosRevendedor();
    if (!mounted) return;

    if (response['success'] == true) {
      final data = response['data'];
      final list = data is List ? data : <dynamic>[];
      final pedidos = list
          .whereType<Map>()
          .map((e) => Pedido.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      pedidos.sort((a, b) {
        if (a.dataPedido == null && b.dataPedido == null) return 0;
        if (a.dataPedido == null) return 1;
        if (b.dataPedido == null) return -1;
        return b.dataPedido!.compareTo(a.dataPedido!);
      });

      setState(() {
        _pedidos = pedidos;
        _loading = false;
      });
      return;
    }

    if (response['unauthorized'] == true) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    setState(() {
      _loading = false;
      _error = response['error']?.toString() ?? 'Erro ao carregar pedidos';
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregue':
        return Colors.green;
      case 'enviado':
        return Colors.blue;
      case 'recebido':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _currency(double value) => 'R\$ ${value.toStringAsFixed(2)}';

  String _titlePedido(Pedido pedido) {
    final numero = pedido.numeroPedido;
    if (numero != null && numero.isNotEmpty) {
      return 'Pedido #$numero';
    }
    return 'Pedido #${pedido.id}';
  }

  void _showDetails(Pedido pedido) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text(
                    'Detalhes do Pedido',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _detailRow('Pedido', _titlePedido(pedido)),
                  if (pedido.dataPedido != null)
                    _detailRow('Data', dateFormat.format(pedido.dataPedido!)),
                  if (pedido.dataPrevisaoEntrega != null)
                    _detailRow(
                      'Entrega',
                      dateFormat.format(pedido.dataPrevisaoEntrega!),
                    ),
                  _detailRow('Status', pedido.status),
                  if (pedido.formaPagamento != null && pedido.formaPagamento!.isNotEmpty)
                    _detailRow('Pagamento', pedido.formaPagamento!),
                  if (pedido.tipoEntrega != null && pedido.tipoEntrega!.isNotEmpty)
                    _detailRow('Tipo entrega', pedido.tipoEntrega!),
                  if (pedido.quantidadeParcelas > 1)
                    _detailRow('Parcelas', '${pedido.quantidadeParcelas}x'),
                  if (pedido.observacao != null && pedido.observacao!.isNotEmpty)
                    _detailRow('Observação', pedido.observacao!),
                  const Divider(height: 28),
                  const Text(
                    'Itens do pedido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (pedido.itens.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Nenhum item retornado pela API.'),
                    )
                  else
                    ...pedido.itens.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.fotoProduto != null && item.fotoProduto!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.fotoProduto!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 52,
                                      height: 52,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        color: Color(0xFF0E5A35),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nomeProduto,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantidade}x ${_currency(item.valorUnitario)}',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Subtotal: ${_currency(item.subtotal)}',
                                    style: const TextStyle(
                                      color: Color(0xFF0E5A35),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: 28),
                  _totalRow('Valor dos produtos', pedido.valorPedido > 0 ? pedido.valorPedido : pedido.valorTotal),
                  if (pedido.valorFrete > 0)
                    _totalRow('Frete', pedido.valorFrete),
                  if (pedido.valorDesconto > 0)
                    _totalRow('Desconto', -pedido.valorDesconto),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total do pedido',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _currency(pedido.valorTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E5A35),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value) {
    final negative = value < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            _currency(value.abs() * (negative ? -1 : 1)),
            style: TextStyle(
              color: negative ? Colors.red : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pedidos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum pedido', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pedidos.length,
        itemBuilder: (context, index) {
          final pedido = _pedidos[index];
          final color = _statusColor(pedido.status);
          final resumoItens = pedido.itens.take(2).map((e) => '${e.quantidade}x ${e.nomeProduto}').join(' • ');

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              onTap: () => _showDetails(pedido),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.receipt_long, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titlePedido(pedido),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (pedido.dataPedido != null)
                            Text(
                              dateFormat.format(pedido.dataPedido!),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  pedido.status,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (pedido.tipoEntrega != null && pedido.tipoEntrega!.isNotEmpty)
                                Text(
                                  pedido.tipoEntrega!,
                                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                ),
                            ],
                          ),
                          if (resumoItens.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              resumoItens,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currency(pedido.valorTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0E5A35),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
