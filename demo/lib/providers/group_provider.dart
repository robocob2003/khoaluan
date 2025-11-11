// lib/providers/group_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

class GroupProvider with ChangeNotifier {
  AuthProvider? _authProvider;
  WebSocketService? _webSocketService;

  List<Group> _groups = [];
  bool _isLoading = false;

  // Key: groupId, Value: List of messages
  final Map<int, List<Message>> _groupMessages = {};

  // Key: groupId, Value: unread count
  final Map<int, int> _unreadCounts = {};

  // Getters
  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  Map<int, int> get unreadCounts => _unreadCounts;

  List<Message> getMessagesForGroup(int groupId) {
    return _groupMessages[groupId] ?? [];
  }

  // Được gọi từ main.dart
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
    // Khi provider được cấp Auth, hãy tải các nhóm
    if (_authProvider?.user != null) {
      loadGroups();
    }
  }

  // Được gọi từ main.dart
  void setWebSocketService(WebSocketService ws) {
    _webSocketService = ws;
  }

  /// Tải danh sách nhóm từ DB
  Future<void> loadGroups() async {
    if (_authProvider?.user?.id == null) return;

    _isLoading = true;
    notifyListeners();

    _groups = await DBService.getGroupsForUser(_authProvider!.user!.id!);

    // Tự động tham gia tất cả các phòng chat nhóm
    if (_webSocketService != null) {
      for (final group in _groups) {
        _webSocketService!.joinGroupRoom(group.id);
      }
      print("GroupProvider: Đã tham gia ${_groups.length} phòng chat nhóm.");
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tạo nhóm mới (sẽ được gọi từ UI)
  Future<Group?> createGroup(String name, String description) async {
    if (_authProvider?.user?.id == null) return null;

    final ownerId = _authProvider!.user!.id!;
    final newGroup = await DBService.createGroup(name, description, ownerId);

    if (newGroup != null) {
      _groups.insert(0, newGroup);

      // Tự động tham gia phòng của nhóm mới tạo
      _webSocketService?.joinGroupRoom(newGroup.id);
      print("GroupProvider: Đã tạo và tham gia phòng ${newGroup.id}.");

      notifyListeners();
      return newGroup;
    }
    return null;
  }

  /// Được gọi 1 lần bởi WebSocketProvider khi tải toàn bộ lịch sử
  void loadGroupMessages(List<Message> allMessages) {
    _groupMessages.clear();
    for (final msg in allMessages) {
      if (msg.groupId != null) {
        final int groupId = msg.groupId!;
        if (!_groupMessages.containsKey(groupId)) {
          _groupMessages[groupId] = [];
        }
        _groupMessages[groupId]!.add(msg);
      }
    }
    // Sắp xếp tất cả các nhóm
    _groupMessages.forEach((key, value) {
      value.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    print(
        "GroupProvider: Đã phân loại tin nhắn cũ cho ${_groupMessages.length} nhóm.");
    notifyListeners();
  }

  /// Được gọi khi có tin nhắn MỚI (real-time)
  void handleIncomingGroupMessage(Message message) {
    if (message.groupId == null) return;
    final int groupId = message.groupId!;

    if (!_groupMessages.containsKey(groupId)) {
      _groupMessages[groupId] = [];
    }

    _groupMessages[groupId]!.add(message);
    // Không cần sắp xếp lại toàn bộ list, chỉ cần thêm vào cuối

    _unreadCounts[groupId] = (_unreadCounts[groupId] ?? 0) + 1;

    notifyListeners();
  }

  /// Lấy thành viên của một nhóm (sẽ dùng ở bước sau)
  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    return await DBService.getMembersInGroup(groupId);
  }
}
