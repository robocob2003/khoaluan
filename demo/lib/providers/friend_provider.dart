// lib/providers/friend_provider.dart
import 'package:flutter/material.dart';
import '../services/identity_service.dart';
import '../services/websocket_service.dart';
import '../models/user.dart';
import '../services/db_service.dart';

class FriendProvider with ChangeNotifier {
  // --- THAY ĐỔI ---
  IdentityService? _identityService;
  WebSocketService? _webSocketService;
  // --- KẾT THÚC THAY ĐỔI ---

  List<UserModel> _friends = [];
  List<UserModel> _pendingRequests = [];
  List<UserModel> _sentRequests = [];
  Map<String, FriendshipStatus> _friendshipStatus = {};

  bool _isLoading = false;
  String? _error;

  List<UserModel> get friends => _friends;
  List<UserModel> get pendingRequests => _pendingRequests;
  List<UserModel> get sentRequests => _sentRequests;
  Map<String, FriendshipStatus> get friendshipStatus => _friendshipStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- THAY ĐỔI: setAuthProvider -> setServices ---
  void setServices(
      IdentityService identityService, WebSocketService wsService) {
    _identityService = identityService;
    _webSocketService = wsService;
    _loadAllFriendData(); // Tải dữ liệu khi có identity
  }
  // --- KẾT THÚC THAY ĐỔI ---

  Future<void> _loadAllFriendData() async {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      _friends = await DBService.getFriends(myId);
      _pendingRequests = await DBService.getPendingRequests(myId);
      _sentRequests = await DBService.getSentRequests(myId);
    } catch (e) {
      _error = 'Failed to load friend data: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFriend(String username) async {
    final myId = _identityService?.myPeerId;
    final myUsername =
        _identityService?.myPeerId; // TODO: Cần 1 trường username
    if (myId == null || myUsername == null) {
      _error = "Bạn chưa đăng nhập";
      notifyListeners();
      return;
    }

    if (username == myUsername) {
      _error = "Bạn không thể tự kết bạn";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      // TODO: Cần một cách để lấy PeerId từ username (ví dụ: qua server)
      // Giả sử username CHÍNH LÀ PeerId
      final otherPeerId = username;

      // TODO: Gửi yêu cầu qua P2P/Signaling
      // _webSocketService.sendFriendRequest(otherPeerId);
      print("P2P: Gửi lời mời kết bạn (chưa implement)");

      await DBService.addFriendRequest(myId, otherPeerId, myId);
      await _loadAllFriendData();
    } catch (e) {
      _error = 'Failed to send friend request: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleFriendRequest(String senderPeerId, bool accept) async {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      final status =
          accept ? FriendshipStatus.accepted : FriendshipStatus.rejected;
      await DBService.updateFriendshipStatus(myId, senderPeerId, status);

      // TODO: Gửi phản hồi qua P2P/Signaling
      // _webSocketService.sendFriendResponse(senderPeerId, accept);
      print("P2P: Gửi phản hồi kết bạn (chưa implement)");

      await _loadAllFriendData();
    } catch (e) {
      _error = 'Failed to handle friend request: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Được gọi khi nhận phản hồi từ người khác
  void onFriendResponse(String otherPeerId, bool accepted) {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    final status =
        accepted ? FriendshipStatus.accepted : FriendshipStatus.rejected;
    DBService.updateFriendshipStatus(myId, otherPeerId, status)
        .then((_) => _loadAllFriendData());
  }

  // Được gọi khi nhận yêu cầu
  void onFriendRequest(String senderPeerId) {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    DBService.addFriendRequest(myId, senderPeerId, senderPeerId)
        .then((_) => _loadAllFriendData());
  }
}
