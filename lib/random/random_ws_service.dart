import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../config.dart';

class RandomWsService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  String? _token;
  bool _disposed = false;
  bool _reconnectScheduled = false;
  bool _connected = false;

  final _connectedController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;
  Stream<bool> get connectionChanges => _connectedController.stream;
  bool get isConnected => _connected;

  Future<void> connect(String token) async {
    _token = token;
    _disposed = false;
    await _open();
  }

  Future<void> _open() async {
    final token = _token;
    if (token == null || token.isEmpty || _disposed) return;

    await _tearDownSocket();

    final base = await AppConfig.getBaseUrl();
    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws/random');

    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['bearer', token],
    );
    _channel = channel;

    try {
      await channel.ready;
    } catch (_) {
      _setConnected(false);
      if (!_disposed) _scheduleReconnect();
      return;
    }
    if (_disposed || !identical(_channel, channel)) return;

    _setConnected(true);

    _sub = channel.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (_) {}
      },
      onError: (_) {
        _setConnected(false);
        if (!_disposed) _scheduleReconnect();
      },
      onDone: () {
        _setConnected(false);
        if (!_disposed) _scheduleReconnect();
      },
      cancelOnError: false,
    );
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    if (!_connectedController.isClosed) {
      _connectedController.add(value);
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectScheduled || _token == null) return;
    _reconnectScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 1500), () async {
      _reconnectScheduled = false;
      if (_disposed || _token == null) return;
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
    _token = null;
    _reconnectScheduled = false;
    _setConnected(false);
    await _tearDownSocket();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    if (!_controller.isClosed) _controller.close();
    if (!_connectedController.isClosed) _connectedController.close();
  }
}
