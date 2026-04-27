import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  // SINGLETON

  WebSocketService._internal();

  static final WebSocketService _instance = WebSocketService._internal();

  factory WebSocketService() => _instance;

  // CONFIG

  static const String _url = "wss://wryttedev.azurewebsites.net/ws0a";

  IOWebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  Timer? _reconnectTimer;
  bool _manuallyClosed = false;
  bool _isConnecting = false;
  String? _lastToken;

  // PUBLIC STREAM

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _channel != null;

  // CONNECT

  Future<void> connect({required String token}) async {
    if (_channel != null || _isConnecting) return;

    _isConnecting = true;
    _manuallyClosed = false;
    _lastToken = token;

    try {
      debugPrint(" Connecting to WebSocket...");
      debugPrint(" Using token: $token");

      final socket = await WebSocket.connect(
        _url,
        headers: {
          "Authorization": "Bearer $token",
          "Origin": "https://wryttedev.azurewebsites.net",
        },
      );

      _channel = IOWebSocketChannel(socket);

      debugPrint(" WebSocket connected");

      _channel!.stream.listen(
        (data) {
          debugPrint(" WS MESSAGE: $data");
          _handleMessage(data);
        },
        onDone: () {
          debugPrint(" WebSocket closed");
          _cleanupConnection();
          if (!_manuallyClosed) _scheduleReconnect();
        },
        onError: (error) {
          debugPrint(" WebSocket error: $error");
          _cleanupConnection();
          if (!_manuallyClosed) _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint(" Connection failed: $e");
      _cleanupConnection();
      _scheduleReconnect();
    }

    _isConnecting = false;
  }

  // HANDLE MESSAGE

  void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        _messageController.add(decoded);
      }
    } catch (_) {
      debugPrint(" Invalid JSON received");
    }
  }

  // SEND

  void send(Map<String, dynamic> data) {
    if (_channel == null) {
      debugPrint(" Cannot send. WebSocket not connected.");
      return;
    }

    final encoded = jsonEncode(data);
    debugPrint(" WS SEND: $encoded");

    _channel!.sink.add(encoded);
  }

  // AUTO RECONNECT

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;

    debugPrint(" Reconnecting in 5 seconds...");

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_lastToken != null) {
        connect(token: _lastToken!);
      }
    });
  }

  // CLEANUP

  void _cleanupConnection() {
    _channel = null;
    _isConnecting = false;
  }

  // MANUAL DISCONNECT

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _channel?.sink.close(status.normalClosure);
    _cleanupConnection();
    debugPrint(" WebSocket manually disconnected");
  }

  // DISPOSE

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
