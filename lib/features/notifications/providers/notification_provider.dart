import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;
  final Map<String, dynamic>? data;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'INFO',
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    final rawData = json['data'];

    if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          parsedData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final resolvedType =
        json['type']?.toString() ?? parsedData?['type']?.toString() ?? 'INFO';

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      // Supports both `message` and `body` column names
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      type: resolvedType,
      isRead: _parseBool(json['is_read'] ?? json['isRead']),
      createdAt:
          json['created_at']?.toString() ??
          json['createdAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      data: parsedData,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    String? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }
}

class NotificationRepository {
  final ApiClient _api;
  NotificationRepository(this._api);

  Future<List<NotificationModel>> fetchNotifications() async {
    final res = await _api.dio.get('/notifications');
    final rawList = res.data is List
        ? res.data as List
        : (res.data is Map && res.data['notifications'] is List
              ? res.data['notifications'] as List
              : const []);

    return rawList
        .map(
          (e) =>
              NotificationModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> markAsRead(String id) async {
    await _api.dio.patch('/notifications/$id/read', data: {});
  }

  Future<void> markAllAsRead() async {
    await _api.dio.patch('/notifications/mark-all-read', data: {});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final notificationsProvider =
    StateNotifierProvider<
      NotificationNotifier,
      AsyncValue<List<NotificationModel>>
    >((ref) {
      final repo = ref.watch(notificationRepositoryProvider);
      final socket = ref.watch(socketServiceProvider);
      final isAuthenticated = ref.watch(isAuthenticatedProvider);

      return NotificationNotifier(
        repo,
        socket,
        isAuthenticated: isAuthenticated,
      );
    });

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  final NotificationRepository _repository;
  final SocketService _socket;
  final bool isAuthenticated;

  NotificationNotifier(
    this._repository,
    this._socket, {
    required this.isAuthenticated,
  }) : super(
         isAuthenticated
             ? const AsyncValue.loading()
             : const AsyncValue.data([]),
       ) {
    if (isAuthenticated) {
      fetchInitial();
      _socket.listen('notification', _onSocketNotification);
    }
  }

  void _onSocketNotification(dynamic payload) {
    if (!mounted) return;
    fetchInitial();
  }

  @override
  void dispose() {
    _socket.stopListening('notification', _onSocketNotification);
    super.dispose();
  }

  Future<void> fetchInitial() async {
    if (!isAuthenticated || !mounted) return;
    try {
      final data = await _repository.fetchNotifications();
      if (mounted) {
        state = AsyncValue.data(data);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;

    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncValue.data(
        currentList
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
      );
    }

    try {
      await _repository.markAsRead(id);
    } catch (e) {
      log('Failed to mark notification $id as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (state.hasValue) {
      final currentList = state.value!;
      if (currentList.every((n) => n.isRead)) return;

      state = AsyncValue.data(
        currentList.map((n) => n.copyWith(isRead: true)).toList(),
      );
    }

    try {
      await _repository.markAllAsRead();
    } catch (e) {
      log('Failed to mark all notifications as read: $e');
    }
  }
}

// Automatically counts unread notifications for the Bell Badge
final unreadCountProvider = Provider<int>((ref) {
  final asyncNotifications = ref.watch(notificationsProvider);
  return asyncNotifications.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
