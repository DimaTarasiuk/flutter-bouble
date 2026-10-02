import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import '../config.dart';
import '../session_store.dart';

class ChatWsService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect(int conversationId) async {
    final token = await SessionStore.getToken();
    if (token == null) return;

    await disconnect();

    final base = await AppConfig.getBaseUrl();
    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws?conversation_id=$conversationId');

    _channel = IOWebSocketChannel.connect(uri, protocols: ['bearer', token]);
    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
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
    _controller.close();
  }
}
