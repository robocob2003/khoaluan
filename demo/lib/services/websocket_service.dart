// demo/lib/services/websocket_service.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _myPeerId;

  bool get isConnected => _isConnected;

  // Callback để P2PService (sẽ tạo ở bước 5) xử lý
  Function(String senderPeerId, dynamic payload)? onRelayMessage;

  // Kết nối đến Server Điều phối
  void connect(String url, String myPeerId) {
    if (_isConnected) return;

    _myPeerId = myPeerId;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      print('Đã kết nối đến Signaling Server');

      // 1. Đăng ký ID của mình với server
      _channel!.sink
          .add(json.encode({'type': 'register', 'peerId': _myPeerId}));

      notifyListeners();

      // 2. Lắng nghe tin nhắn điều phối
      _channel!.stream.listen((message) {
        try {
          final data = json.decode(message);
          if (data['type'] == 'relay' && onRelayMessage != null) {
            // Chuyển cho P2PService xử lý
            onRelayMessage!(data['senderPeerId'], data['payload']);
          }
        } catch (e) {
          print('Lỗi khi xử lý tin nhắn từ server: $e');
        }
      }, onDone: () {
        print('Đã ngắt kết nối khỏi Signaling Server');
        _isConnected = false;
        notifyListeners();
      }, onError: (error) {
        print('Lỗi WebSocket: $error');
        _isConnected = false;
        notifyListeners();
      });
    } catch (e) {
      print('Lỗi khi kết nối WebSocket: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  // 3. Hàm mới: Gửi tin nhắn điều phối (để gửi offer, answer, v.v.)
  void relayMessage(String targetPeerId, dynamic payload) {
    if (!_isConnected) {
      print('Không thể relay: Chưa kết nối WebSocket');
      return;
    }
    _channel?.sink.add(json.encode({
      'type': 'relay',
      'targetPeerId': targetPeerId,
      'payload': payload,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
