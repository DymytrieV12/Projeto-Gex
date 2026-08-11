import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_service.dart';

/// Notificação local exibida no sininho do app.
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
        createdAtIso:
            j['createdAtIso']?.toString() ?? DateTime.now().toIso8601String(),
        read: j['read'] as bool? ?? false,
      );
}

/// Serviço de notificações baseado em polling do endpoint de pedidos.
/// Detecta alterações de status e gera notificações locais nativas.
class NotificationService extends ChangeNotifier {
  static const Duration _pollInterval = Duration(minutes: 20);
  static const int _maxNotifications = 50;
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pedido_status_channel',
    'Status dos pedidos',
    description: 'Notificações nativas sobre alterações de status dos pedidos',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _localReady = false;
  Timer? _timer;
  bool _polling = false;
  List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  String get _userKey => 'notifs_${ApiService.userId ?? "global"}';
  String get _statusKey => 'pedidos_status_${ApiService.userId ?? "global"}';

  Future<void> init() async {
    await _initLocalNotifications();
    await _restore();
    unawaited(syncNow());
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => syncNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initLocalNotifications() async {
    if (_localReady) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _localNotifications.initialize(settings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    _localReady = true;
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
            final notification = AppNotification(
              id: 'status_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
              type: 'status',
              title: 'Pedido #${entry.key} atualizado',
              body: 'Status: "$oldStatus" → "$newStatus"',
              createdAtIso: DateTime.now().toIso8601String(),
            );
            _items.insert(0, notification);
            unawaited(_showNativeNotification(notification));
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
      // silencioso — polling em background
    } finally {
      _polling = false;
    }
  }

  Future<void> _showNativeNotification(AppNotification item) async {
    if (!_localReady) return;

    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwin = DarwinNotificationDetails();

    await _localNotifications.show(
      item.id.hashCode,
      item.title,
      item.body,
      NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      payload: item.id,
    );
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
    await _localNotifications.cancelAll();
    notifyListeners();
  }

  Future<void> reset() async {
    _timer?.cancel();
    _items.clear();
    await _localNotifications.cancelAll();
    notifyListeners();
  }
}
