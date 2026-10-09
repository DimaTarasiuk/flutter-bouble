import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import '../config.dart';
import '../session_store.dart';

class ChatWsService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  int? _conversationId;
  bool _disposed = false;
  bool _reconnectScheduled = false;

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect(int conversationId) async {
    _conversationId = conversationId;
    _disposed = false;
    await _open();
  }

  Future<void> _open() async {
    final token = await SessionStore.getToken();
    final conversationId = _conversationId;
    if (token == null || conversationId == null || _disposed) return;

    await _tearDownSocket();

    final base = await AppConfig.getBaseUrl();
    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws?conversation_id=$conversationId');

    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['bearer', token],
    );
    _channel = channel;

    try {
      await channel.ready;
    } catch (_) {
      if (!_disposed) _scheduleReconnect();
      return;
    }
    if (_disposed || !identical(_channel, channel)) return;

    _sub = channel.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
      },
      onError: (_) {
        if (!_disposed) _scheduleReconnect();
      },
      onDone: () {
        if (!_disposed) _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled || _conversationId == null) return;
    _reconnectScheduled = true;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      _reconnectScheduled = false;
      if (_disposed || _conversationId == null) return;
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
    _conversationId = null;
    _reconnectScheduled = false;
    await _tearDownSocket();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    if (!_controller.isClosed) _controller.close();
  }
}
