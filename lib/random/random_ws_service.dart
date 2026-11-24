import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../config.dart';

class RandomWsService {
  static const _readyTimeout = Duration(seconds: 12);
  static const _closeTimeout = Duration(seconds: 1);

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  String? _token;
  bool _disposed = false;
  bool _reconnectScheduled = false;
  bool _connected = false;
  int _generation = 0;

  final _connectedController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;
  Stream<bool> get connectionChanges => _connectedController.stream;
  bool get isConnected => _connected;

  Future<void> connect(String token) async {
    _token = token;
    _disposed = false;
    _generation++;
    _reconnectScheduled = false;
    await _open();
  }

  /// Force a fresh socket (e.g. after app resume). Keeps the same token.
  Future<void> reconnectNow() async {
    if (_disposed) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    _reconnectScheduled = false;
    _generation++;
    if (_connected) {
      _connected = false;
      if (!_connectedController.isClosed) {
        _connectedController.add(false);
      }
    }
    await _open();
  }

  Future<void> _open() async {
    final token = _token;
    final gen = _generation;
    if (token == null || token.isEmpty || _disposed) return;

    await _tearDownSocket();
    if (_disposed || gen != _generation || _token != token) return;

    final base = await AppConfig.getBaseUrl();
    if (_disposed || gen != _generation || _token != token) return;

    final wsBase = AppConfig.toWsUrl(base);
    final uri = Uri.parse('$wsBase/ws/random');

    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: ['bearer', token],
    );
    _channel = channel;

    try {
      await channel.ready.timeout(_readyTimeout);
    } catch (_) {
      if (identical(_channel, channel)) {
        _channel = null;
        try {
          await channel.sink.close().timeout(_closeTimeout);
        } catch (_) {}
      }
      if (_disposed || gen != _generation) return;
      _setConnected(false);
      _scheduleReconnect();
      return;
    }
    if (_disposed || gen != _generation || !identical(_channel, channel)) {
      try {
        await channel.sink.close().timeout(_closeTimeout);
      } catch (_) {}
      return;
    }

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
        if (!_disposed && gen == _generation) _scheduleReconnect();
      },
      onDone: () {
        _setConnected(false);
        if (!_disposed && gen == _generation) _scheduleReconnect();
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
    final sub = _sub;
    _sub = null;
    await sub?.cancel();

    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await channel.sink.close().timeout(_closeTimeout);
    } catch (_) {}
  }

  /// Drop the socket without blocking the UI. Safe to call repeatedly.
  Future<void> disconnect() async {
    _generation++;
    _token = null;
    _reconnectScheduled = false;
    _setConnected(false);
    await _tearDownSocket();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _token = null;
    _reconnectScheduled = false;
    _setConnected(false);
    // Fire-and-forget close — dispose must not hang.
    unawaited(_tearDownSocket());
    if (!_controller.isClosed) _controller.close();
    if (!_connectedController.isClosed) _connectedController.close();
  }
}
