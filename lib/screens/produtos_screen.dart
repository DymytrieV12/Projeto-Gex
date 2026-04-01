import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../providers/carrinho_provider.dart';

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});
  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Produto> _todos = [];
  List<Produto> _filtrados = [];
  bool _loading = false;
  String _erro = '';
  final _searchC = TextEditingController();
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _erro = '';
    });
    final r = await ApiService.getProdutos(pageSize: 200);
    if (!mounted) return;
    if (r['success'] == true) {
      final data = r['data'];
      final list = data is List ? data : <dynamic>[];
      final produtos = list
          .whereType<Map>()
          .map((e) => Produto.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.ativo)
          .toList();
      // Expand all categories by default
      final cats = produtos.map((p) => p.tipoProduto ?? 'Outros').toSet();
      setState(() {
        _todos = produtos;
        _filtrados = produtos;
        _expanded.addAll(cats);
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _erro = r['error']?.toString() ?? 'Erro';
      });
    }
  }

  void _filter(String q) {
    setState(() {
      _filtrados = q.isEmpty
          ? _todos
          : _todos.where((p) => p.nome.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Map<String, List<Produto>> get _grouped {
    final map = <String, List<Produto>>{};
    for (final p in _filtrados) {
      final cat = p.tipoProduto ?? 'Outros';
      map.putIfAbsent(cat, () => []).add(p);
    }
    // Sort categories: Frasco first, then alphabetical
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) {
        if (a.key == 'Frasco') return -1;
        if (b.key == 'Frasco') return 1;
        return a.key.compareTo(b.key);
      }),
    );
    return sorted;
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'frasco':
        return Icons.science_outlined;
      case 'saco':
        return Icons.inventory_2_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  void _showDetail(Produto p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, sc) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: SingleChildScrollView(
                    controller: sc,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 42, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999)))),
                        if (p.imagemUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(p.imagemUrl!, width: double.infinity, height: 260, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, size: 60, color: Color(0xFF0E5A35))))),
                          ),
                        const SizedBox(height: 18),
                        Text(p.nome, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('R\$ ${p.precoExibicao.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
                        if (p.tipoProduto != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(p.tipoProduto!, style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.w600)),
                          ),
                        ],
                        if (p.descricao != null && p.descricao!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text('Sobre o produto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(p.descricao!, style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.6)),
                        ],
                        const SizedBox(height: 28),
                        _DetailCartWidget(produto: p),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: TextField(
                controller: _searchC,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Buscar produtos...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.85),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  suffixIcon: _searchC.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchC.clear(); _filter(''); }) : null,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _erro.isNotEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_erro), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const Text('Tentar novamente'))]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        children: _grouped.entries.map((entry) {
                          final cat = entry.key;
                          final prods = entry.value;
                          final isExpanded = _expanded.contains(cat);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        onTap: () => setState(() {
                                          if (isExpanded) {
                                            _expanded.remove(cat);
                                          } else {
                                            _expanded.add(cat);
                                          }
                                        }),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              Icon(_catIcon(cat), color: const Color(0xFF0E5A35), size: 22),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '$cat (${prods.length})',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35)),
                                                ),
                                              ),
                                              AnimatedRotation(
                                                turns: isExpanded ? 0.5 : 0,
                                                duration: const Duration(milliseconds: 250),
                                                child: const Icon(Icons.expand_more, color: Color(0xFF0E5A35)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isExpanded)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                          child: GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              childAspectRatio: 0.50,
                                              crossAxisSpacing: 8,
                                              mainAxisSpacing: 8,
                                            ),
                                            itemCount: prods.length,
                                            itemBuilder: (c, i) => _GlassProductCard(produto: prods[i], onDetail: () => _showDetail(prods[i])),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _GlassProductCard extends StatelessWidget {
  final Produto produto;
  final VoidCallback onDetail;
  const _GlassProductCard({required this.produto, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image — aspect ratio ~1:1
              AspectRatio(
                aspectRatio: 1.0,
                child: produto.imagemUrl != null
                    ? Image.network(
                        produto.imagemUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, size: 28, color: Color(0xFF0E5A35)))),
                      )
                    : Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, size: 28, color: Color(0xFF0E5A35)))),
              ),
              // Info section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.nome,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'R\$ ${produto.precoExibicao.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35)),
                      ),
                      const Spacer(),
                      // "Ver mais" button — bigger and styled
                      SizedBox(
                        width: double.infinity,
                        height: 30,
                        child: OutlinedButton(
                          onPressed: onDetail,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Color(0xFF0E5A35), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Ver mais', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0E5A35))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCartWidget extends StatefulWidget {
  final Produto produto;
  const _DetailCartWidget({required this.produto});
  @override
  State<_DetailCartWidget> createState() => _DetailCartWidgetState();
}

class _DetailCartWidgetState extends State<_DetailCartWidget> {
  late TextEditingController _qtyC;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CarrinhoProvider>();
    final existing = cart.itens.where((i) => i.produtoId == widget.produto.id).firstOrNull;
    _qty = existing?.quantidade ?? 1;
    _qtyC = TextEditingController(text: '$_qty');
  }

  @override
  void dispose() {
    _qtyC.dispose();
    super.dispose();
  }

  void _updateQty(int delta) {
    setState(() {
      _qty = (_qty + delta).clamp(1, 999);
      _qtyC.text = '$_qty';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final inCart = cart.itens.where((i) => i.produtoId == widget.produto.id).firstOrNull;

    return Column(
      children: [
        // Quantity selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0E5A35).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Quantidade:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _qty > 1 ? () => _updateQty(-1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: const Color(0xFF0E5A35),
              ),
              SizedBox(
                width: 56,
                child: TextField(
                  controller: _qtyC,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) setState(() => _qty = n);
                  },
                ),
              ),
              IconButton(
                onPressed: () => _updateQty(1),
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFF0E5A35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Add to cart button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final p = widget.produto;
              // Remove existing and add with new qty
              cart.removeItem(p.id);
              cart.addItem(p.id, p.nome, p.precoExibicao, p.imagemUrl, _qty);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${_qty}x ${p.nome} adicionado ao carrinho'),
                backgroundColor: const Color(0xFF0E5A35),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: Text(
              inCart != null
                  ? 'Atualizar Carrinho ($_qty un.)'
                  : 'Adicionar ao Carrinho ($_qty un.)',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
