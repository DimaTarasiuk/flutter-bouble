import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'config.dart';
import 'session_store.dart';

class PresenceEvent {
  final String type;
  final Map<String, dynamic> raw;
  PresenceEvent(this.type, this.raw);
}

class PresenceService {
  IOWebSocketChannel? _channel;
  StreamController<PresenceEvent>? _controller;
  StreamSubscription? _sub;
  bool _disposed = false;
  bool _wantConnected = false;
  bool _reconnectScheduled = false;

  Stream<PresenceEvent> get events {
    _controller ??= StreamController<PresenceEvent>.broadcast();
    return _controller!.stream;
  }

  Future<void> connect() async {
    _wantConnected = true;
    _disposed = false;
    await _open();
  }

  Future<void> _open() async {
    final token = await SessionStore.getToken();
    if (token == null || _disposed || !_wantConnected) return;

    await _tearDownSocket();

    final base = await AppConfig.getBaseUrl();
    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws/presence');

    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['bearer', token],
    );
    _channel = channel;
    _controller ??= StreamController<PresenceEvent>.broadcast();

    // Слухаємо одразу — snapshot часто приходить ще до ready.
    _sub = channel.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'unknown';
          _controller?.add(PresenceEvent(type, data));
        } catch (_) {
          // ігноруємо повідомлення, що не парсяться як JSON
        }
      },
      onError: (_) {
        if (_wantConnected && !_disposed) _scheduleReconnect();
      },
      onDone: () {
        if (_wantConnected && !_disposed) _scheduleReconnect();
      },
      cancelOnError: false,
    );

    try {
      await channel.ready;
    } catch (_) {
      if (_wantConnected && !_disposed) _scheduleReconnect();
      return;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || !_wantConnected || _reconnectScheduled) return;
    _reconnectScheduled = true;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      _reconnectScheduled = false;
      if (_disposed || !_wantConnected) return;
      await _open();
    });
  }

  Future<void> _tearDownSocket() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> disconnect() async {
    _wantConnected = false;
    _reconnectScheduled = false;
    await _tearDownSocket();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller?.close();
    _controller = null;
  }
}
