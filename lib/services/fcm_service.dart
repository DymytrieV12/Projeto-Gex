import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler para mensagens recebidas com o app encerrado/em background.
///
/// IMPORTANTE:
/// Quando o projeto tiver o arquivo gerado pelo `flutterfire configure`
/// (`firebase_options.dart`), a inicialização abaixo deve ser trocada para:
/// Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Se o Firebase ainda não estiver configurado nativamente no projeto,
    // apenas ignoramos para não quebrar o app.
  }
}

typedef FcmTapHandler = Future<void> Function(RemoteMessage message);

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String _tokenStorageKey = 'fcm_device_token';
  static const String _lastMessageKey = 'fcm_last_message';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'green_express_fcm',
    'Mensagens do app',
    description: 'Notificações remotas enviadas pelo painel do Firebase',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _firebaseReady = false;
  bool _localReady = false;
  bool _interactionHandlersAttached = false;
  FcmTapHandler? _onTap;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e, st) {
      debugPrint('FCM: Firebase não pôde ser inicializado: $e');
      debugPrint('$st');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermission();
    await _captureAndPersistToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_persistDeviceToken(token));
    });

    FirebaseMessaging.onMessage.listen((message) async {
      await _persistLastMessage(message);
      await _showForegroundNotification(message);
    });
  }

  Future<void> attachInteractionHandlers({FcmTapHandler? onTap}) async {
    if (!_firebaseReady) return;
    _onTap = onTap;

    if (_interactionHandlersAttached) return;
    _interactionHandlersAttached = true;

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleTap(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _handleTap(message);
    });
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

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final raw = jsonDecode(payload) as Map<String, dynamic>;
          final message = RemoteMessage.fromMap(raw);
          await _handleTap(message);
        } catch (_) {}
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    _localReady = true;
  }

  Future<void> _requestPermission() async {
    if (!_firebaseReady) return;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _captureAndPersistToken() async {
    if (!_firebaseReady) return;

    if (!kIsWeb && Platform.isIOS) {
      await _waitForApnsToken();
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await _persistDeviceToken(token);
  }

  Future<void> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null && apns.isNotEmpty) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _persistDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_tokenStorageKey);
    if (current == token) return;

    await prefs.setString(_tokenStorageKey, token);

    // TODO: enviar este token para o backend da aplicação assim que existir
    // um endpoint dedicado, por exemplo:
    // POST /api/dispositivos/push-token { token, plataforma, usuarioId }
    // Esse passo é necessário para disparo de notificações direcionadas.
    debugPrint('FCM token atualizado: $token');
  }

  Future<void> _persistLastMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastMessageKey, jsonEncode(message.toMap()));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localReady) return;

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Green Express';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        'Você recebeu uma nova notificação.';

    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0E5A35),
    );
    const darwin = DarwinNotificationDetails();

    await _localNotifications.show(
      message.messageId.hashCode,
      title,
      body,
      NotificationDetails(android: android, iOS: darwin, macOS: darwin),
      payload: jsonEncode(message.toMap()),
    );
  }

  Future<void> _handleTap(RemoteMessage message) async {
    await _persistLastMessage(message);
    if (_onTap != null) {
      await _onTap!(message);
    }
  }
}
