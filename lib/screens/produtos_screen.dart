import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../providers/carrinho_provider.dart';

/// Cache global para não recarregar toda vez que troca de aba
List<Produto>? _cachedProdutos;
DateTime? _cacheTime;

class ProdutosScreen extends StatefulWidget {
  const ProdutosScreen({super.key});
  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> with AutomaticKeepAliveClientMixin {
  List<Produto> _todos = [];
  List<Produto> _filtrados = [];
  bool _loading = false;
  String _erro = '';
  final _searchC = TextEditingController();
  final Set<String> _expanded = {};

  @override
  bool get wantKeepAlive => true; // Manter estado ao trocar aba

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _searchC.dispose(); super.dispose(); }

  Future<void> _load({bool forceRefresh = false}) async {
    // Usar cache se disponível e < 5 min
    if (!forceRefresh && _cachedProdutos != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age.inMinutes < 5) {
        final cats = _cachedProdutos!.map((p) => p.tipoProduto ?? 'Outros').toSet();
        setState(() { _todos = _cachedProdutos!; _filtrados = _cachedProdutos!; _expanded.addAll(cats); _loading = false; });
        return;
      }
    }

    setState(() { _loading = true; _erro = ''; });
    final r = await ApiService.getProdutos(pageSize: 200);
    if (!mounted) return;
    if (r['success'] == true) {
      final data = r['data'];
      final list = data is List ? data : <dynamic>[];
      final produtos = list.whereType<Map>().map((e) => Produto.fromJson(Map<String, dynamic>.from(e))).where((p) => p.ativo).toList();
      final cats = produtos.map((p) => p.tipoProduto ?? 'Outros').toSet();
      _cachedProdutos = produtos;
      _cacheTime = DateTime.now();
      setState(() { _todos = produtos; _filtrados = produtos; _expanded.addAll(cats); _loading = false; });
    } else {
      setState(() { _loading = false; _erro = r['error']?.toString() ?? 'Erro'; });
    }
  }

  void _filter(String q) {
    setState(() { _filtrados = q.isEmpty ? _todos : _todos.where((p) => p.nome.toLowerCase().contains(q.toLowerCase())).toList(); });
  }

  Map<String, List<Produto>> get _grouped {
    final map = <String, List<Produto>>{};
    for (final p in _filtrados) { map.putIfAbsent(p.tipoProduto ?? 'Outros', () => []).add(p); }
    return Map.fromEntries(map.entries.toList()..sort((a, b) { if (a.key == 'Frasco') return -1; if (b.key == 'Frasco') return 1; return a.key.compareTo(b.key); }));
  }

  IconData _catIcon(String cat) { switch (cat.toLowerCase()) { case 'frasco': return Icons.science_outlined; case 'saco': return Icons.inventory_2_outlined; default: return Icons.category_outlined; } }

  void _showDetail(Produto p) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.94, expand: false,
            builder: (ctx, sc) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.94), Colors.white.withValues(alpha: 0.82)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: SingleChildScrollView(
                    controller: sc,
                    padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(child: Container(width: 42, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(999)))),
                      if (p.imagemUrl != null) ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.network(p.imagemUrl!, width: double.infinity, height: 240, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, size: 60, color: Color(0xFF0E5A35)))))),
                      const SizedBox(height: 16),
                      Text(p.nome, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('R\$ ${p.precoExibicao.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
                      if (p.tipoProduto != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(p.tipoProduto!, style: const TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.w600)))],
                      if (p.descricao != null && p.descricao!.isNotEmpty) ...[const SizedBox(height: 18), const Text('Sobre o produto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(p.descricao!, style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.6))],
                      const SizedBox(height: 24),
                      _DetailCartWidget(produto: p),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cart = context.watch<CarrinhoProvider>();

    return Container(
      // Fundo com brasão sutil da marca
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE8F0EB), Color(0xFFF0F5F2)]),
      ),
      child: Stack(
        children: [
          // Brasão sutil no fundo
          Positioned(
            right: -40, bottom: 60, width: 260, height: 260,
            child: Opacity(opacity: 0.04, child: Image.asset('assets/images/brasao_green_express.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox())),
          ),
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _searchC, onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Buscar produtos...', prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: Colors.white.withValues(alpha: 0.9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  suffixIcon: _searchC.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchC.clear(); _filter(''); }) : null,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _erro.isNotEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_erro), const SizedBox(height: 12), ElevatedButton(onPressed: () => _load(forceRefresh: true), child: const Text('Tentar novamente'))]))
                      : RefreshIndicator(
                          onRefresh: () => _load(forceRefresh: true),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(10, 4, 10, cart.totalItens > 0 ? 80 : 8),
                            children: _grouped.entries.map((e) => _buildCat(e.key, e.value, _expanded.contains(e.key))).toList(),
                          ),
                        ),
            ),
          ]),
          if (cart.totalItens > 0)
            Positioned(left: 12, right: 12, bottom: 8, child: _CartFloatingBar(cart: cart, onTap: () => Navigator.pushNamed(context, '/carrinho'))),
        ],
      ),
    );
  }

  Widget _buildCat(String cat, List<Produto> prods, bool isExp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          InkWell(
            onTap: () => setState(() { isExp ? _expanded.remove(cat) : _expanded.add(cat); }),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(_catIcon(cat), color: const Color(0xFF0E5A35), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('$cat (${prods.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35)))),
                AnimatedRotation(turns: isExp ? 0.5 : 0, duration: const Duration(milliseconds: 250), child: const Icon(Icons.expand_more, color: Color(0xFF0E5A35))),
              ]),
            ),
          ),
          if (isExp)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.40, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: prods.length,
                itemBuilder: (c, i) => _GlassProductCard(produto: prods[i], onDetail: () => _showDetail(prods[i])),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Floating Cart Bar (iFood) ──
class _CartFloatingBar extends StatelessWidget {
  final CarrinhoProvider cart;
  final VoidCallback onTap;
  const _CartFloatingBar({required this.cart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B4D2C), Color(0xFF0E5A35)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: const Color(0xFF0E5A35).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('R\$ ${cart.totalValor.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${cart.totalItens} ${cart.totalItens == 1 ? "item" : "itens"}', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Text('Ver carrinho', style: TextStyle(color: Color(0xFF0E5A35), fontWeight: FontWeight.bold, fontSize: 14))),
        ]),
      ),
    );
  }
}

// ── LIQUID GLASS Product Card ──
class _GlassProductCard extends StatefulWidget {
  final Produto produto;
  final VoidCallback onDetail;
  const _GlassProductCard({required this.produto, required this.onDetail});
  @override
  State<_GlassProductCard> createState() => _GlassProductCardState();
}

class _GlassProductCardState extends State<_GlassProductCard> {
  late TextEditingController _qtyC;
  int _qty = 1;

  @override
  void initState() { super.initState(); _qtyC = TextEditingController(text: '1'); }
  @override
  void dispose() { _qtyC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final inCart = cart.itens.where((i) => i.produtoId == widget.produto.id).firstOrNull;
    if (inCart != null && _qty != inCart.quantidade) { _qty = inCart.quantidade; _qtyC.text = '$_qty'; }

    return Container(
      decoration: BoxDecoration(
        // Liquid Glass: gradiente verde sutil + borda luminosa + sombra dupla
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0E5A35).withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.55),
            const Color(0xFF0E5A35).withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          width: 1.5,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        boxShadow: [
          // Sombra externa para profundidade
          BoxShadow(color: const Color(0xFF0E5A35).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
          // Brilho interno no topo (efeito vidro)
          BoxShadow(color: Colors.white.withValues(alpha: 0.7), blurRadius: 2, offset: const Offset(0, -1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 1.05,
          child: Stack(children: [
            widget.produto.imagemUrl != null
                ? Image.network(widget.produto.imagemUrl!, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ph())
                : _ph(),
            // Reflexo sutil no topo da imagem
            Positioned(top: 0, left: 0, right: 0, height: 30,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent])))),
          ]),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.produto.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('R\$ ${widget.produto.precoExibicao.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0E5A35))),
            const Spacer(),
            SizedBox(width: double.infinity, height: 26,
              child: OutlinedButton(onPressed: widget.onDetail,
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, side: const BorderSide(color: Color(0xFF0E5A35), width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Ver mais', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0E5A35))))),
            const SizedBox(height: 4),
            SizedBox(height: 26, child: Row(children: [
              _miniBtn(Icons.remove, () { if (_qty > 1) setState(() { _qty--; _qtyC.text = '$_qty'; }); }),
              Expanded(child: TextField(controller: _qtyC, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) setState(() => _qty = n); })),
              _miniBtn(Icons.add, () { setState(() { _qty++; _qtyC.text = '$_qty'; }); }),
            ])),
            const SizedBox(height: 3),
            SizedBox(width: double.infinity, height: 28,
              child: ElevatedButton(onPressed: () {
                final p = widget.produto;
                cart.removeItem(p.id);
                cart.addItem(p.id, p.nome, p.precoExibicao, p.imagemUrl, _qty);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_qty}x ${p.nome}'), backgroundColor: const Color(0xFF0E5A35), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 1)));
              }, style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_shopping_cart, size: 12), const SizedBox(width: 3), Text(inCart != null ? 'Atualizar' : 'Comprar')]))),
          ]),
        )),
      ]),
    );
  }

  Widget _ph() => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.eco, size: 28, color: Color(0xFF0E5A35))));
  Widget _miniBtn(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 14, color: const Color(0xFF0E5A35))));
}

// ── Detail popup cart controls ──
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
  void initState() { super.initState(); final c = context.read<CarrinhoProvider>(); final e = c.itens.where((i) => i.produtoId == widget.produto.id).firstOrNull; _qty = e?.quantidade ?? 1; _qtyC = TextEditingController(text: '$_qty'); }
  @override
  void dispose() { _qtyC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CarrinhoProvider>();
    final inCart = cart.itens.where((i) => i.produtoId == widget.produto.id).firstOrNull;
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF0E5A35).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Quantidade:', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(width: 16),
          IconButton(onPressed: _qty > 1 ? () { setState(() { _qty--; _qtyC.text = '$_qty'; }); } : null, icon: const Icon(Icons.remove_circle_outline), color: const Color(0xFF0E5A35)),
          SizedBox(width: 56, child: TextField(controller: _qtyC, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
            onChanged: (v) { final n = int.tryParse(v); if (n != null && n > 0) setState(() => _qty = n); }, onTapOutside: (_) => FocusScope.of(context).unfocus())),
          IconButton(onPressed: () { setState(() { _qty++; _qtyC.text = '$_qty'; }); }, icon: const Icon(Icons.add_circle_outline), color: const Color(0xFF0E5A35)),
        ])),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {
        final p = widget.produto; cart.removeItem(p.id); cart.addItem(p.id, p.nome, p.precoExibicao, p.imagemUrl, _qty);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_qty}x ${p.nome} adicionado'), backgroundColor: const Color(0xFF0E5A35), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 2)));
        Navigator.pop(context);
      }, icon: const Icon(Icons.add_shopping_cart), label: Text(inCart != null ? 'Atualizar Carrinho ($_qty un.)' : 'Adicionar ao Carrinho ($_qty un.)'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
    ]);
  }
}
