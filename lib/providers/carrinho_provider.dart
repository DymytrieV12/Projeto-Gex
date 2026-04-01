import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class CarrinhoProvider extends ChangeNotifier {
  final List<ItemCarrinho> _itens = [];
  List<ItemCarrinho> get itens => List.unmodifiable(_itens);
  int get totalItens => _itens.fold(0, (s, i) => s + i.quantidade);
  double get totalValor => _itens.fold(0.0, (s, i) => s + i.subtotal);

  void addItem(String pid, String nome, double preco, String? img, [int q = 1]) { final idx = _itens.indexWhere((i) => i.produtoId == pid); if (idx >= 0) { _itens[idx].quantidade += q; } else { _itens.add(ItemCarrinho(produtoId: pid, nomeProduto: nome, preco: preco, imagemUrl: img, quantidade: q)); } _save(); notifyListeners(); }
  void removeItem(String pid) { _itens.removeWhere((i) => i.produtoId == pid); _save(); notifyListeners(); }
  void updateQuantidade(String pid, int q) { if (q <= 0) { removeItem(pid); return; } final idx = _itens.indexWhere((i) => i.produtoId == pid); if (idx >= 0) { _itens[idx].quantidade = q; _save(); notifyListeners(); } }
  void limpar() { _itens.clear(); _save(); notifyListeners(); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setString('carrinho', jsonEncode(_itens.map((i) => i.toJson()).toList())); }
  Future<void> loadCarrinho() async { final p = await SharedPreferences.getInstance(); final r = p.getString('carrinho'); if (r != null) { try { final l = jsonDecode(r) as List; _itens.clear(); _itens.addAll(l.map((j) => ItemCarrinho.fromJson(j as Map<String, dynamic>))); notifyListeners(); } catch (_) {} } }
}
