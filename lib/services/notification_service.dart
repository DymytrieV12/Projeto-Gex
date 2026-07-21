import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_service.dart';

/// Notifica\u00e7\u00e3o local exibida no sininho do app.
class AppNotification {
  final String id;
  final String type; // 'status', 'promo', 'sistema'
  final String title;
  final String body;
  final String createdAtIso;
  bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAtIso,
    this.read = false,
  });

  DateTime get createdAt => DateTime.tryParse(createdAtIso) ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'createdAtIso': createdAtIso,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? 'sistema',
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        createdAtIso: j['createdAtIso']?.toString() ?? DateTime.now().toIso8601String(),
        read: j['read'] as bool? ?? false,
      );
}

/// Servi\u00e7o de notifica\u00e7\u00f5es baseado em polling do endpoint de pedidos.
/// Detecta altera\u00e7\u00f5es de status e gera notifica\u00e7\u00f5es locais.
class NotificationService extends ChangeNotifier {
  static const Duration _pollInterval = Duration(minutes: 5);
  static const int _maxNotifications = 50;

  Timer? _timer;
  bool _polling = false;
  List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  String get _userKey => 'notifs_${ApiService.userId ?? "global"}';
  String get _statusKey => 'pedidos_status_${ApiService.userId ?? "global"}';

  Future<void> init() async {
    await _restore();
    // Primeira sincroniza\u00e7\u00e3o em background
    unawaited(syncNow());
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => syncNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _items = list;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _userKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  /// Executa polling: busca pedidos e compara status com o snapshot local.
  Future<void> syncNow() async {
    if (_polling) return;
    if (ApiService.userId == null) return;
    _polling = true;
    try {
      final resp = await ApiService.getPedidosRevendedor(pageSize: 100);
      if (resp['success'] != true) return;
      final data = resp['data'];
      final list = data is List ? data : const <dynamic>[];
      final pedidos = list
          .whereType<Map>()
          .map((e) => Pedido.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final oldRaw = prefs.getString(_statusKey);
      Map<String, dynamic> oldMap = {};
      if (oldRaw != null && oldRaw.isNotEmpty) {
        try {
          oldMap = Map<String, dynamic>.from(jsonDecode(oldRaw) as Map);
        } catch (_) {}
      }

      final newMap = <String, String>{};
      for (final p in pedidos) {
        final ref = (p.numeroPedido?.trim().isNotEmpty == true)
            ? p.numeroPedido!.trim()
            : p.id;
        newMap[ref] = p.status.trim();
      }

      bool changed = false;
      if (oldMap.isNotEmpty) {
        for (final entry in newMap.entries) {
          final oldStatus = oldMap[entry.key]?.toString();
          final newStatus = entry.value;
          if (oldStatus != null && oldStatus.isNotEmpty && oldStatus != newStatus) {
            _items.insert(
              0,
              AppNotification(
                id: 'status_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
                type: 'status',
                title: 'Pedido #${entry.key} atualizado',
                body: 'Status: "$oldStatus" \u2192 "$newStatus"',
                createdAtIso: DateTime.now().toIso8601String(),
              ),
            );
            changed = true;
          }
        }
        if (_items.length > _maxNotifications) {
          _items = _items.take(_maxNotifications).toList();
        }
      }

      await prefs.setString(_statusKey, jsonEncode(newMap));
      if (changed) {
        await _persist();
        notifyListeners();
      }
    } catch (_) {
      // silencioso \u2014 polling em background
    } finally {
      _polling = false;
    }
  }

  Future<void> markAllRead() async {
    for (final n in _items) {
      n.read = true;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    // Usado no logout \u2014 limpa snapshot para novo usu\u00e1rio
    _timer?.cancel();
    _items.clear();
    notifyListeners();
  }
}
