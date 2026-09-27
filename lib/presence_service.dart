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

  Stream<PresenceEvent> get events {
    _controller ??= StreamController<PresenceEvent>.broadcast();
    return _controller!.stream;
  }

  Future<void> connect() async {
    final token = await SessionStore.getToken();
    if (token == null) return;

    final base = await AppConfig.getBaseUrl();
    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws/presence');

    await disconnect();

    _channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['bearer', token],
    );

    _controller ??= StreamController<PresenceEvent>.broadcast();

    _sub = _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'unknown';
          _controller?.add(PresenceEvent(type, data));
        } catch (_) {
          // ігноруємо повідомлення, що не парсяться як JSON
        }
      },
      onError: (_) {},
      onDone: () {},
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _controller?.close();
    _controller = null;
  }
}
