// lib/providers/group_provider.dart
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/identity_service.dart';
import '../services/p2p_service.dart';
import '../services/websocket_service.dart';

class GroupProvider with ChangeNotifier {
  // --- THAY ĐỔI ---
  IdentityService? _identityService;
  WebSocketService? _webSocketService; // Dùng cho signaling
  P2PService? _p2pService; // Dùng cho data
  // --- KẾT THÚC THAY ĐỔI ---

  List<Group> _groups = [];
  final Map<String, List<GroupMember>> _groupMembers = {};
  final Map<String, List<Message>> _groupMessages = {};

  bool _isLoading = false;
  String? _error;

  List<Group> get groups => _groups;
  List<GroupMember> getMembers(String groupId) => _groupMembers[groupId] ?? [];
  List<Message> getMessages(String groupId) => _groupMessages[groupId] ?? [];
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- THAY ĐỔI: setAuthProvider -> setServices ---
  void setServices(IdentityService identityService, WebSocketService wsService,
      P2PService p2pService) {
    _identityService = identityService;
    _webSocketService = wsService;
    _p2pService = p2pService;
    _loadGroups();
  }
  // --- KẾT THÚC THAY ĐỔI ---

  Future<void> _loadGroups() async {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      _groups = await DBService.getGroupsForUser(myId);
    } catch (e) {
      _error = "Failed to load groups: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadGroupDetails(String groupId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final members = await DBService.getMembersInGroup(groupId);
      _groupMembers[groupId] = members;
      // TODO: Tải tin nhắn nhóm
      // final messages = await DBService.getMessagesForGroup(groupId);
      // _groupMessages[groupId] = messages;
    } catch (e) {
      _error = "Failed to load group details: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createGroup(String name, String description) async {
    final myId = _identityService?.myPeerId;
    if (myId == null) {
      _error = "Bạn chưa đăng nhập";
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final newGroup = await DBService.createGroup(name, description, myId);
      if (newGroup != null) {
        _groups.insert(0, newGroup);
        // TODO: Thông báo cho P2P/Server (nếu cần)
        // _webSocketService.createGroup(newGroup);
        print("P2P: Tạo nhóm (chưa implement)");
      }
    } catch (e) {
      _error = "Failed to create group: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> inviteUserToGroup(String groupId, String peerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await DBService.addUserToGroup(groupId, peerId, 'member');
      // TODO: Gửi P2P/Signaling
      // _webSocketService.inviteToGroup(groupId, peerId);
      print("P2P: Mời vào nhóm (chưa implement)");
      await loadGroupDetails(groupId);
    } catch (e) {
      _error = "Failed to invite user: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendGroupMessage(String groupId, String content) async {
    final myId = _identityService?.myPeerId;
    if (myId == null) return;

    final myName = 'Peer...${myId.substring(myId.length - 6)}';

    final message = Message(
      content: content,
      senderId: myId,
      groupId: groupId,
      timestamp: DateTime.now(),
      senderUsername: myName,
    );

    try {
      final msgId = await DBService.insertMessage(message);
      final savedMsg = message; // TODO: Cập nhật message với ID

      if (!_groupMessages.containsKey(groupId)) {
        _groupMessages[groupId] = [];
      }
      _groupMessages[groupId]!.add(savedMsg);

      // TODO: Gửi P2P
      // _p2pService.broadcastToGroup(groupId, json.encode({'type': 'group_msg', ...savedMsg.toMap()}));
      print("P2P: Gửi tin nhắn nhóm (chưa implement)");

      notifyListeners();
    } catch (e) {
      _error = "Failed to send message: $e";
      print(_error);
      notifyListeners();
    }
  }

  // TODO: Thêm các hàm onGroupMessage, onUserJoined, v.v.
  // để P2PService gọi
}
