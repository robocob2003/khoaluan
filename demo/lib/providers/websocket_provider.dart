// lib/providers/websocket_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';

// --- THAY ĐỔI IMPORT ---
import '../config/app_config.dart';
import '../services/identity_service.dart';
import '../services/websocket_service.dart'; // Đây là service signaling MỚI
import '../services/p2p_service.dart';
// (Xóa các provider khác vì không cần thiết ở đây)
// --- KẾT THÚC THAY ĐỔI ---

class WebSocketProvider with ChangeNotifier {
  // --- CÁC SERVICE CỐT LÕI ---
  final IdentityService _identityService;
  final WebSocketService _webSocketService;
  final P2PService _p2pService;
  // --- KẾT THÚC ---

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  String? _error;
  String? get error => _error;

  // --- HÀM CONSTRUCTOR MỚI ---
  // Các service được inject (tiêm) vào từ main.dart
  WebSocketProvider(
    this._identityService,
    this._webSocketService,
    this._p2pService,
  ) {
    // Ngay lập tức lắng nghe khi Identity sẵn sàng
    if (_identityService.isInitialized) {
      _initializeServices();
    } else {
      _identityService.addListener(_onIdentityReady);
    }
  }

  void _onIdentityReady() {
    if (_identityService.isInitialized) {
      _initializeServices();
      _identityService.removeListener(_onIdentityReady);
    }
  }
  // --- KẾT THÚC HÀM MỚI ---

  // Hàm này thay thế hàm connect() cũ
  void _initializeServices() {
    if (_isInitialized) return;

    final myPeerId = _identityService.myPeerId;
    if (myPeerId == null) {
      _error = "Không thể kết nối: Định danh không hợp lệ.";
      notifyListeners();
      return;
    }

    try {
      // 1. Kết nối đến Signaling Server
      _webSocketService.connect(AppConfig.webSocketUrl, myPeerId);

      // 2. Thiết lập các listener cho P2PService
      // (P2PService đã được inject wsService, nên nó tự lắng nghe)
      // Bây giờ, chúng ta lắng nghe P2PService để nhận dữ liệu

      // TODO: Thiết lập các listener cho P2PService
      // Ví dụ:
      // _p2pService.onMessageReceived = (senderId, message) {
      //   _chatProvider.handleIncomingMessage(senderId, message);
      // };
      // _p2pService.onFileMetadataReceived = (senderId, metadata) {
      //   _fileTransferProvider.processIncomingFileMetadata(metadata, senderId);
      // };

      print("✅ WebSocketProvider: Đã khởi tạo các service P2P và Signaling.");
      _isInitialized = true;
    } catch (e) {
      _error = "Lỗi khởi tạo WebSocketProvider: $e";
      print("💥 $_error");
    } finally {
      notifyListeners();
    }
  }

  // (Toàn bộ các hàm xử lý sự kiện cũ như _handleAuthSuccess,
  // _handleMessage, _handleFileMetadata... ĐÃ BỊ XÓA
  // vì P2PService giờ sẽ xử lý chúng)

  // (Các hàm send... cũ cũng bị xóa,
  // vì chúng ta sẽ gọi _p2pService.sendMessage(...) trực tiếp)

  @override
  void dispose() {
    print("Disposing WebSocketProvider...");
    _webSocketService.disconnect();
    _identityService.removeListener(_onIdentityReady);
    super.dispose();
  }
}
