// lib/providers/websocket_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/db_service.dart';
import '../services/websocket_service.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/file_transfer.dart';
import 'file_transfer_provider.dart';
import 'group_provider.dart';
import '../models/group.dart';
import '../models/comment.dart';
import 'comment_provider.dart';
import 'friend_provider.dart';
import '../services/rsa_service.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  final List<Message> _messages = [];
  final Map<String, bool> _typingUsers = {};

  bool _isConnected = false;
  String? _error;
  UserModel? _currentUser;
  AuthProvider? _authProvider;
  GroupProvider? _groupProvider;
  CommentProvider? _commentProvider;
  FileTransferProvider? _fileTransferProvider;
  FriendProvider? _friendProvider;

  Timer? _typingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  String? get error => _error;
  Map<String, bool> get typingUsers => Map.unmodifiable(_typingUsers);
  WebSocketService get webSocketService => _webSocketService;
  bool get isReconnecting => _reconnectTimer?.isActive ?? false;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  void setGroupProvider(GroupProvider groupProvider) {
    _groupProvider = groupProvider;
  }

  void setCommentProvider(CommentProvider commentProvider) {
    _commentProvider = commentProvider;
  }

  void setFriendProvider(FriendProvider friendProvider) {
    _friendProvider = friendProvider;
  }

  WebSocketProvider() {
    _setupWebSocketListeners();
  }

  void setupFileTransferListeners(FileTransferProvider fileProvider) {
    _fileTransferProvider = fileProvider;

    _webSocketService.onFileMetadataReceived = (metadata) {
      _handleIncomingFileMetadata(metadata, fileProvider);
    };
    _webSocketService.onFileChunkReceived =
        (fileId, chunkIndex, chunkData, sender, checksum, signature) {
      fileProvider.receiveFileChunk(
          fileId, chunkIndex, chunkData, sender, checksum, signature);
    };
    _webSocketService.onDownloadRequestReceived = (fileId, fromUsername) {
      print(
          'WebSocketProvider: Received download request for $fileId from $fromUsername');
      final privateKey = _authProvider?.privateKey;
      if (privateKey != null) {
        fileProvider.startSendingFileChunks(fileId, fromUsername, privateKey);
      } else {
        print(
            'Error: Could not start sending chunks because private key is not loaded.');
      }
    };
  }

  void _handleIncomingFileMetadata(
      FileMetadata metadata, FileTransferProvider fileProvider) async {
    if (_authProvider == null || _currentUser == null) return;
    final sender = _authProvider!.availableUsers.firstWhere(
      (user) => user.id == metadata.senderId,
      orElse: () => UserModel(
          id: metadata.senderId, username: 'Unknown', email: '', password: ''),
    );
    final Message? fileMessage = await fileProvider.processIncomingFileMetadata(
        metadata, _currentUser!, sender);
    if (fileMessage != null) {
      if (fileMessage.groupId != null) {
        _groupProvider?.handleIncomingGroupMessage(fileMessage);
      } else {
        addLocalMessage(fileMessage);
      }
    }
  }

  void _handleIncomingMessageData(Map<String, dynamic> data) {
    if (_authProvider == null || _currentUser == null) return;

    final privateKey = _authProvider?.privateKey;
    if (privateKey == null) {
      print("Không thể giải mã tin nhắn: Khóa riêng tư chưa được tải.");
      return;
    }

    String? content = data['text'] as String?;
    final String? fromUsername = data['from'] as String?;
    final int? groupId = data['groupId'] as int?;

    if (fromUsername == null || content == null) return;

    // Chỉ giải mã tin nhắn 1-1 (không phải tin nhóm)
    if (groupId == null) {
      final decryptedContent = RSAService.decrypt(content, privateKey);
      if (decryptedContent == null) {
        print("Lỗi giải mã tin nhắn từ $fromUsername.");
        content = "[Không thể giải mã]";
      } else {
        content = decryptedContent;
      }
    }

    final sender = _authProvider!.availableUsers.firstWhere(
      (user) => user.username == fromUsername,
      orElse: () =>
          UserModel(id: -1, username: 'Unknown', email: '', password: ''),
    );

    final message = Message(
      content: content,
      senderId: sender.id ?? -1,
      receiverId: groupId == null ? _currentUser!.id : null,
      groupId: groupId,
      timestamp: DateTime.now(),
      senderUsername: fromUsername,
    );

    DBService.insertMessage(message);
    if (groupId != null) {
      _groupProvider?.handleIncomingGroupMessage(message);
    } else {
      addLocalMessage(message);
    }
  }

  Future<void> _handleIncomingGroupInvite(
      Map<String, dynamic> groupData) async {
    if (_currentUser?.id == null || _authProvider == null) return;
    try {
      final group = Group.fromMap(groupData);
      var owner = await DBService.getUserById(group.ownerId);
      if (owner == null) {
        print(
            "Owner ID ${group.ownerId} not found locally. Forcing user sync...");
        await _authProvider!.fetchUsers();
        owner = await DBService.getUserById(group.ownerId);

        if (owner == null) {
          print(
              "LỖI NGHIÊM TRỌNG: Không thể xử lý lời mời. Owner (ID: ${group.ownerId}) không tồn tại trên server. Lời mời bị hủy.");
          return;
        }
      }

      await DBService.insertGroup(group);
      await DBService.addUserToGroup(group.id, _currentUser!.id!, 'member');
      await DBService.addUserToGroup(group.id, group.ownerId, 'admin');
      print("Đã tham gia nhóm ${group.name} từ lời mời.");
      await _groupProvider?.loadGroups();
    } catch (e) {
      print("Lỗi xử lý lời mời tham gia nhóm: $e");
    }
  }

  void _handleIncomingFileComment(Map<String, dynamic> commentData) {
    try {
      final comment = Comment.fromMap(commentData);
      DBService.addFileComment(comment);
      _commentProvider?.addComment(comment);
    } catch (e) {
      print("Lỗi xử lý bình luận nhận được: $e");
    }
  }

  // ---- CÁC HÀM HANDLE FRIEND ĐÃ ĐƯỢC KẾT NỐI ----
  void _handleFriendRequest(Map<String, dynamic> data) {
    _friendProvider?.loadFriendships(); // Tạm thời tải lại, sau sẽ tối ưu
  }

  void _handleFriendRequestAccepted(Map<String, dynamic> data) {
    _friendProvider?.loadFriendships(); // Tạm thời tải lại, sau sẽ tối ưu
  }
  // ---------------------------------------------

  void _setupWebSocketListeners() {
    _webSocketService.onConnectionChanged = (connected) {
      _isConnected = connected;
      if (connected) {
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _error = null;
      } else if (_currentUser != null) {
        _scheduleReconnect();
      }
      notifyListeners();
    };

    _webSocketService.onMessageReceived = (data) {
      _handleIncomingMessageData(data);
    };

    _webSocketService.onGroupInviteReceived = (groupData, fromUsername) {
      print("Nhận được lời mời tham gia nhóm từ $fromUsername");
      _handleIncomingGroupInvite(groupData);
    };

    _webSocketService.onFileCommentReceived = (commentData, groupId) {
      _handleIncomingFileComment(commentData);
    };

    _webSocketService.onFileTagsReceived = (fileId, tags, groupId) {
      _fileTransferProvider?.handleIncomingFileTags(
          fileId, tags.map((t) => t.toString()).toList());
    };

    _webSocketService.onTypingReceived = (username, isTyping) {
      _updateTypingStatus(username, isTyping);
    };

    _webSocketService.onError = (errorMessage) {
      _setError(errorMessage);
    };

    // ---- BỘ LẮNG NGHE MỚI ĐÃ ĐƯỢC KÍCH HOẠT ----
    _webSocketService.onFriendRequest = _handleFriendRequest;
    _webSocketService.onFriendAccept = _handleFriendRequestAccepted;
    // ---------------------------------------------
  }

  Future<void> connect(UserModel user) async {
    _currentUser = user;
    _error = null;
    try {
      await _webSocketService.connect(user);
    } catch (e) {
      _setError('Connection failed: $e');
    }
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts || _currentUser == null)
      return;
    final delay = Duration(seconds: 2 << _reconnectAttempts);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      print("Reconnecting... attempt $_reconnectAttempts");
      connect(_currentUser!);
    });
    notifyListeners();
  }

  void sendMessage(String content, String recipientUsername) {
    if (_currentUser == null || !_isConnected) return;

    final encryptedContent = RSAService.encrypt(content, recipientUsername);

    if (encryptedContent == null) {
      print(
          "Không thể gửi tin nhắn: Lỗi mã hóa. Khóa công khai của người nhận có thể không tồn tại.");
      return;
    }

    final message = Message(
        content: content,
        senderId: _currentUser!.id!,
        timestamp: DateTime.now());

    _webSocketService.sendMessage(
        message.copyWith(content: encryptedContent), recipientUsername);
  }

  void sendGroupMessage(String content, int groupId) {
    if (_currentUser == null || !_isConnected) return;
    final message = Message(
      content: content,
      senderId: _currentUser!.id!,
      groupId: groupId,
      timestamp: DateTime.now(),
      senderUsername: _currentUser!.username,
    );
    _webSocketService.sendGroupMessage(message);
    DBService.insertMessage(message);
    _groupProvider?.handleIncomingGroupMessage(message);
  }

  void addLocalMessage(Message message) {
    _messages.add(message);
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  void sendTypingIndicator(bool isTyping, String? recipientUsername) {
    if (!_isConnected || recipientUsername == null || recipientUsername.isEmpty)
      return;
    _webSocketService.sendTypingIndicator(isTyping, recipientUsername);
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        sendTypingIndicator(false, recipientUsername);
      });
    }
  }

  void _updateTypingStatus(String username, bool isTyping) {
    if (isTyping) {
      _typingUsers[username] = true;
    } else {
      _typingUsers.remove(username);
    }
    notifyListeners();
  }

  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
    Timer(const Duration(seconds: 5), () {
      if (_error == errorMessage) {
        _error = null;
        notifyListeners();
      }
    });
  }

  void loadMessages(List<Message> messages) {
    _messages.clear();
    _groupProvider?.loadGroupMessages(messages);
    _messages.addAll(messages.where((m) => m.groupId == null));
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  void disconnect() {
    _webSocketService.disconnect();
    _reconnectTimer?.cancel();
    _typingTimer?.cancel();
    _currentUser = null;
    _isConnected = false;
    _reconnectAttempts = 0;
    _messages.clear();
    _typingUsers.clear();
    notifyListeners();
  }
}
