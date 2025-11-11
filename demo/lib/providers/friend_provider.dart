// lib/providers/friend_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class FriendProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  WebSocketService? _webSocketService;

  List<UserModel> _friends = [];
  List<UserModel> _pendingRequests = []; // Yêu cầu người khác gửi cho tôi
  List<UserModel> _sentRequests = []; // Yêu cầu tôi đã gửi

  bool _isLoading = false;

  // Getters
  List<UserModel> get friends => _friends;
  List<UserModel> get pendingRequests => _pendingRequests;
  List<UserModel> get sentRequests => _sentRequests;
  bool get isLoading => _isLoading;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_authProvider?.user != null) {
      loadFriendships();
    }
  }

  void setWebSocketService(WebSocketService ws) {
    _webSocketService = ws;

    _webSocketService!.onFriendRequest = _handleFriendRequest;
    _webSocketService!.onFriendAccept = _handleFriendRequestAccepted;
    _webSocketService!.onFriendReject = (_) => loadFriendships();
  }

  /// Tải tất cả các mối quan hệ từ CSDL
  Future<void> loadFriendships() async {
    if (_authProvider?.user?.id == null) return;
    final myId = _authProvider!.user!.id!;

    _isLoading = true;
    notifyListeners();

    _friends = await DBService.getFriends(myId);
    _pendingRequests = await DBService.getPendingRequests(myId);
    _sentRequests = await DBService.getSentRequests(myId);

    _isLoading = false;
    notifyListeners();
  }

  /// Gửi yêu cầu kết bạn
  Future<void> sendFriendRequest(UserModel user) async {
    if (_authProvider?.user?.id == null || _webSocketService == null) return;
    final myId = _authProvider!.user!.id!;

    _webSocketService!.sendFriendRequest(user.username);
    await DBService.addFriendRequest(myId, user.id!, myId);

    _sentRequests.add(user);
    notifyListeners();
  }

  /// Chấp nhận yêu cầu kết bạn
  Future<void> acceptFriendRequest(UserModel user) async {
    if (_authProvider?.user?.id == null || _webSocketService == null) return;
    final myId = _authProvider!.user!.id!;

    // ---- SỬA LỖI RACE CONDITION (Giống như hàm Reject) ----
    // 1. Cập nhật UI ngay lập tức
    _pendingRequests.removeWhere((u) => u.id == user.id);
    _friends.add(user);
    notifyListeners();

    try {
      // 2. Gửi thông báo và cập nhật DB
      _webSocketService!.sendFriendAccept(user.username);
      await DBService.updateFriendshipStatus(
          myId, user.id!, FriendshipStatus.accepted);
    } catch (e) {
      print("Lỗi khi chấp nhận yêu cầu: $e. Đang tải lại...");
      await loadFriendships(); // Tải lại để khôi phục
    }
  }

  // ---- HÀM ĐÃ ĐƯỢC CẬP NHẬT ----
  /// Từ chối yêu cầu kết bạn
  Future<void> rejectFriendRequest(UserModel user) async {
    if (_authProvider?.user?.id == null || _webSocketService == null) return;
    final myId = _authProvider!.user!.id!;

    // 1. Cập nhật UI ngay lập tức (Optimistic Update)
    _pendingRequests.removeWhere((u) => u.id == user.id);
    notifyListeners();

    try {
      // 2. Gửi thông báo và cập nhật DB
      _webSocketService!.sendFriendReject(user.username);
      await DBService.updateFriendshipStatus(
          myId, user.id!, FriendshipStatus.rejected);
    } catch (e) {
      // 3. Nếu lỗi, tải lại state từ DB để khôi phục
      print("Lỗi khi từ chối yêu cầu: $e. Đang tải lại...");
      await loadFriendships(); // Tải lại để khôi phục
    }
  }
  // -------------------------

  /// Xử lý khi nhận được yêu cầu kết bạn
  Future<void> _handleFriendRequest(Map<String, dynamic> data) async {
    if (_authProvider?.user?.id == null) return;
    final myId = _authProvider!.user!.id!;

    final fromUsername = data['from'] as String?;
    if (fromUsername == null) return;

    final otherUser = await DBService.getUserByUsername(fromUsername);
    if (otherUser == null) {
      print(
          "Nhận được yêu cầu kết bạn từ user lạ: $fromUsername. Đang tải lại user...");
      await _authProvider?.fetchUsers();
      final reloadedUser = await DBService.getUserByUsername(fromUsername);
      if (reloadedUser == null) {
        print(
            "Không thể xử lý yêu cầu kết bạn. User $fromUsername không tồn tại.");
        return;
      }
      await _processIncomingRequest(myId, reloadedUser);
    } else {
      await _processIncomingRequest(myId, otherUser);
    }
  }

  /// Hàm nội bộ để xử lý request
  Future<void> _processIncomingRequest(int myId, UserModel otherUser) async {
    await DBService.addFriendRequest(myId, otherUser.id!, otherUser.id!);

    await loadFriendships(); // Tải lại toàn bộ
    print("🔔 Nhận được yêu cầu kết bạn từ ${otherUser.username}");
  }

  /// Xử lý khi ai đó chấp nhận yêu cầu của mình
  Future<void> _handleFriendRequestAccepted(Map<String, dynamic> data) async {
    if (_authProvider?.user?.id == null) return;
    final myId = _authProvider!.user!.id!;

    final fromUsername = data['from'] as String?;
    if (fromUsername == null) return;

    final otherUser = await DBService.getUserByUsername(fromUsername);
    if (otherUser == null) {
      print("Không thể xử lý chấp nhận: User $fromUsername không tồn tại.");
      return;
    }

    await DBService.updateFriendshipStatus(
        myId, otherUser.id!, FriendshipStatus.accepted);

    await loadFriendships(); // Tải lại toàn bộ
    print("✅ ${otherUser.username} đã chấp nhận yêu cầu kết bạn.");
  }
}
