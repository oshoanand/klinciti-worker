import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/providers/active_chat_provider.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../router/route_names.dart';
import '../socket/socket_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Background FCM received: ${message.messageId}');
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref.watch(apiClientProvider),
    rootNavigatorKey,
    ref.watch(socketServiceProvider),
    ref,
  );
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  final ApiClient _apiClient;
  final GlobalKey<NavigatorState> _navigatorKey;
  final SocketService _socketService;
  final Ref _ref;

  // Prevents duplicate notifications if BOTH Socket and FCM deliver the same event
  final Set<String> _recentNotificationIds = {};
  bool _isInitialized = false;

  NotificationService(
    this._apiClient,
    this._navigatorKey,
    this._socketService,
    this._ref,
  );

  void dispose() {
    _socketService.stopListening('notification', _handleSocketMessage);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to socket notifications regardless of FCM permission state
    _socketService.listen('notification', _handleSocketMessage);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'klinciti_high_priority',
        'Важные уведомления',
        description: 'Уведомления о заказах и сообщениях',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      await _localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      await _localPlugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onSelectNotification,
      );

      final token = await _fcm.getToken();
      if (token != null) await _registerDeviceToken(token);
      _fcm.onTokenRefresh.listen(_registerDeviceToken);

      FirebaseMessaging.onMessage.listen(_handleFcmForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (msg) => _routeFromData(msg.data),
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _routeFromData(initialMessage.data),
        );
      }
    }
  }

  void _processIncomingNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) {
    if (_recentNotificationIds.contains(id)) return;
    _recentNotificationIds.add(id);
    if (_recentNotificationIds.length > 50) _recentNotificationIds.clear();

    final type = payloadData['type']?.toString().toUpperCase() ?? '';
    final sessionId =
        payloadData['sessionId']?.toString() ??
        payloadData['chatSessionId']?.toString() ??
        payloadData['chatId']?.toString();

    // 1. Suppress OS banner if the user is already inside this exact chat session
    if (sessionId != null && sessionId.isNotEmpty) {
      final activeSessionId = _ref.read(activeChatSessionProvider);
      if (activeSessionId == sessionId) {
        return;
      }
    }

    // 2. Fallback route inspection via GoRouter
    final context = _navigatorKey.currentContext;
    if (context != null) {
      try {
        final router = GoRouter.of(context);
        final currentRoute = router.routerDelegate.currentConfiguration.uri
            .toString();

        if ((type.contains('CHAT')) &&
            sessionId != null &&
            sessionId.isNotEmpty) {
          if (currentRoute.contains('${AppRoutes.chatDetail}/$sessionId')) {
            return;
          }
        }
      } catch (e) {
        log('⚠️ Route check failed, proceeding to show notification: $e');
      }
    }

    String stringifiedPayload = '{}';
    try {
      stringifiedPayload = jsonEncode(payloadData);
    } catch (_) {}

    _localPlugin.show(
      id.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'klinciti_high_priority',
          'Важные уведомления',
          channelDescription: 'Уведомления о заказах и сообщениях',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: stringifiedPayload,
    );
  }

  // ==============================================================
  // AUTH BRIDGES
  // ==============================================================

  Future<void> registerTokenAfterLogin() async {
    try {
      final fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        await _registerDeviceToken(fcmToken, forceRegister: true);
      }
    } catch (e) {
      log('Failed to register token after login: $e');
    }
  }

  Future<void> subscribeToUserTopics(String? mobile) async {
    try {
      await _fcm.subscribeToTopic('kilinciti_workers_topic');
      final userTopic = _buildMobileTopic(mobile);
      if (userTopic.isNotEmpty) {
        await _fcm.subscribeToTopic(userTopic);
      }
    } catch (e) {
      log('❌ Failed to subscribe to topics: $e');
    }
  }

  Future<void> unsubscribeFromTopics(String? mobile) async {
    try {
      await _fcm.unsubscribeFromTopic('kilinciti_workers_topic');
      final userTopic = _buildMobileTopic(mobile);
      if (userTopic.isNotEmpty) {
        await _fcm.unsubscribeFromTopic(userTopic);
      }
    } catch (_) {}
  }

  String _buildMobileTopic(String? mobile) {
    if (mobile == null || mobile.trim().isEmpty) return '';
    final String digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 &&
        (digits.startsWith('7') || digits.startsWith('8'))) {
      return 'user_${digits.substring(1)}';
    } else if (digits.isNotEmpty) {
      return 'user_$digits';
    }
    return '';
  }

  // ==============================================================
  // INTERNAL HELPERS
  // ==============================================================

  Future<void> _registerDeviceToken(
    String fcmToken, {
    bool forceRegister = false,
  }) async {
    try {
      final token = await _apiClient.storage.read(key: 'jwt_token');
      if (!forceRegister && (token == null || token.isEmpty)) return;

      final String deviceType = Platform.isIOS ? 'IOS' : 'ANDROID';
      await _apiClient.dio.post(
        '/fcm/save-fcm',
        data: {'fcmToken': fcmToken, 'deviceType': deviceType},
      );
      log('✅ FCM Token registered ($deviceType)');
    } catch (e) {
      log('❌ FCM Token registration failed: $e');
    }
  }

  void _handleFcmForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      _processIncomingNotification(
        id:
            message.messageId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: message.notification!.title ?? 'Уведомление',
        body: message.notification!.body ?? '',
        payloadData: Map<String, dynamic>.from(message.data),
      );
    }
  }

  void _handleSocketMessage(dynamic payload) {
    try {
      final Map<String, dynamic> data = payload is String
          ? Map<String, dynamic>.from(jsonDecode(payload) as Map)
          : Map<String, dynamic>.from(payload as Map);

      final String uniqueId =
          data['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      Map<String, dynamic> nestedData = {};
      if (data['data'] is Map) {
        nestedData = Map<String, dynamic>.from(data['data'] as Map);
      } else if (data['data'] is String &&
          (data['data'] as String).trim().isNotEmpty) {
        try {
          nestedData = Map<String, dynamic>.from(
            jsonDecode(data['data'] as String) as Map,
          );
        } catch (_) {}
      }

      // ✅ Merge top-level metadata so `type`, `sessionId`, `jobId`, and `url` are never lost
      final Map<String, dynamic> mergedPayload = {
        if (data['type'] != null) 'type': data['type'],
        if (data['sessionId'] != null) 'sessionId': data['sessionId'],
        if (data['partnerId'] != null) 'partnerId': data['partnerId'],
        if (data['jobId'] != null) 'jobId': data['jobId'],
        if (data['url'] != null) 'url': data['url'],
        ...nestedData,
      };

      final String title =
          data['title']?.toString() ??
          mergedPayload['title']?.toString() ??
          'Уведомление';
      final String body =
          data['body']?.toString() ??
          data['message']?.toString() ??
          mergedPayload['body']?.toString() ??
          '';

      _processIncomingNotification(
        id: uniqueId,
        title: title,
        body: body,
        payloadData: mergedPayload,
      );
    } catch (e) {
      log('❌ Socket Payload Parse Error: $e');
    }
  }

  void _onSelectNotification(NotificationResponse response) {
    final rawPayload = response.payload;
    if (rawPayload != null && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          _routeFromData(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        log('❌ Notification tap payload decode error: $e');
      }
    }
  }

  // ==============================================================
  // DEEP LINK & NOTIFICATION TAP ROUTER
  // Matches exact routes in `lib/core/router/app_router.dart`
  // ==============================================================
  void _routeFromData(Map<String, dynamic> data) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type']?.toString().toUpperCase() ?? '';
    final sessionId =
        data['sessionId']?.toString() ??
        data['chatSessionId']?.toString() ??
        data['chatId']?.toString();
    final partnerId =
        data['partnerId']?.toString() ?? data['senderId']?.toString();
    final jobId = data['jobId']?.toString() ?? data['orderId']?.toString();
    final rawUrl = data['url']?.toString();

    // 1. Direct Chat Room Navigation (`/chats/room/:sessionId?partnerId=...`)
    if (sessionId != null && sessionId.isNotEmpty) {
      final uri = Uri(
        path: '${AppRoutes.chatDetail}/$sessionId',
        queryParameters: {
          if (partnerId != null && partnerId.isNotEmpty) 'partnerId': partnerId,
        },
      );
      context.push(uri.toString());
      return;
    }

    // 2. Direct Job Detail Navigation (`/jobs/detail/:id`)
    if (jobId != null && jobId.isNotEmpty) {
      context.push('${AppRoutes.jobDetail}/$jobId');
      return;
    }

    // 3. Parse backend `url` field (e.g. `/chat/:sessionId/:partnerId`)
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final cleanUrl = rawUrl.trim();
      if (cleanUrl.startsWith('/chat/')) {
        final parts = cleanUrl.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.length >= 2) {
          final parsedSessionId = parts[1];
          final parsedPartnerId = parts.length >= 3 ? parts[2] : '';
          final uri = Uri(
            path: '${AppRoutes.chatDetail}/$parsedSessionId',
            queryParameters: {
              if (parsedPartnerId.isNotEmpty) 'partnerId': parsedPartnerId,
            },
          );
          context.push(uri.toString());
          return;
        }
      }
      if (cleanUrl.startsWith('/chat-detail/')) {
        final parsedSessionId = cleanUrl.replaceFirst('/chat-detail/', '');
        context.push('${AppRoutes.chatDetail}/$parsedSessionId');
        return;
      }
    }

    // 4. Fallback by Notification Type
    if (type.contains('CHAT')) {
      context.go(AppRoutes.chatList);
    } else if (type.contains('JOB') || type.contains('ORDER')) {
      context.go(AppRoutes.jobDashboard);
    } else {
      context.push(AppRoutes.notifications);
    }
  }
}
