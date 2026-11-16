import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/api_client.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.disconnect);
  return service;
});

class SocketService {
  io.Socket? _socket;
  String? _currentUserId;
  final _storage = const FlutterSecureStorage();

  // ✅ Persistent registry of active listeners.
  // Survives logout/login cycles and socket recreation so NotificationService
  // and Riverpod providers never lose their bindings.
  final Map<String, Set<void Function(dynamic)>> _listeners = {};

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String userId) async {
    if (userId.isEmpty) return;

    // If already connected for this exact user, do nothing
    if (_socket != null && _socket!.connected && _currentUserId == userId) {
      return;
    }

    // Tear down any previous stale socket instance before creating a fresh one
    if (_socket != null) {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    }

    _currentUserId = userId;
    final token = await _storage.read(key: 'jwt_token');

    // Safely parse URI: `authority` preserves "host:port" while stripping "/api" paths
    final uri = Uri.parse(ApiClient.baseUrl);
    final String socketUrl = '${uri.scheme}://${uri.authority}';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(['websocket'])
          // ✅ Crucial: prevents socket_io_client from returning a disposed cached instance after logout
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(99999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': token ?? '', 'userId': userId, 'role': 'WORKER'})
          .disableAutoConnect()
          .build(),
    );

    // Attach all registered listeners to the new socket instance
    _listeners.forEach((event, callbacks) {
      for (final callback in callbacks) {
        _socket?.off(event, callback);
        _socket?.on(event, callback);
      }
    });

    _socket?.onConnect((_) {
      log('✅ Socket Connected to $socketUrl (ID: ${_socket?.id})');
    });

    _socket?.onDisconnect((reason) {
      log('⚠️ Socket Disconnected ($reason)');
    });

    _socket?.onReconnect((attempt) {
      log('🔄 Socket Reconnected after $attempt attempts');
    });

    _socket?.onConnectError((err) => log('❌ Socket Connection Error: $err'));
    _socket?.onError((err) => log('❌ Socket Error: $err'));

    _socket?.connect();
  }

  void listen(String event, void Function(dynamic) callback) {
    final eventSet = _listeners.putIfAbsent(event, () => {});
    eventSet.add(callback);

    if (_socket != null) {
      // Prevent duplicate registration on the underlying socket
      _socket?.off(event, callback);
      _socket?.on(event, callback);
    }
  }

  /// Removes a specific [callback] for [event], or all listeners for [event] if [callback] is omitted.
  void stopListening(String event, [void Function(dynamic)? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
      if (_listeners[event]?.isEmpty ?? false) {
        _listeners.remove(event);
      }
      _socket?.off(event, callback);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  void emit(String event, dynamic data) {
    if (_socket != null) {
      _socket?.emit(event, data);
    } else {
      log('⚠️ Tried to emit "$event" before socket was initialized.');
    }
  }

  /// Disconnects the socket on logout while keeping global listeners (e.g. NotificationService)
  /// ready to re-bind when the next user logs in.
  void disconnect() {
    _currentUserId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    log('🛑 Socket disconnected.');
  }
}
