// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/file_transfer.dart';
import '../config/app_config.dart';
import '../models/group.dart';
import '../models/comment.dart';

class WebSocketService {
  static const String _serverUrl = AppConfig.webSocketUrl;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  UserModel? _currentUser;
  Timer? _heartbeatTimer;
  StreamSubscription? _streamSubscription;

  // Callbacks
  Function(bool connected)? onConnectionChanged;
  Function(Map<String, dynamic> data)? onMessageReceived;
  Function(String username, bool isTyping)? onTypingReceived;
  Function(String error)? onError;
  Function(FileMetadata metadata)? onFileMetadataReceived;
  Function(String fileId, int chunkIndex, Uint8List chunkData, String from,
      String? checksum, String? signature)? onFileChunkReceived;
  Function(String fileId, String fromUsername)? onDownloadRequestReceived;
  Function(Map<String, dynamic> groupData, String fromUsername)?
      onGroupInviteReceived;
  Function(Map<String, dynamic> commentData, int groupId)?
      onFileCommentReceived;
  Function(String fileId, List<dynamic> tags, int groupId)? onFileTagsReceived;

  Function(Map<String, dynamic> data)? onFriendRequest;
  Function(Map<String, dynamic> data)? onFriendAccept;
  // ---- THÊM CALLBACK MỚI ----
  Function(Map<String, dynamic> data)? onFriendReject;
  // -----------------------------

  // Callbacks P2P
  Function(String fromUsername, String fileId, int chunkIndex)?
      onAnnounceChunkReceived;
  Function(String fromUsername, String fileId, int chunkIndex)?
      onRequestSpecificChunk;

  bool get isConnected => _isConnected;

  Future<void> connect(UserModel user) async {
    if (_isConnected) await disconnect();
    try {
      _currentUser = user;
      _channel = IOWebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;
      _streamSubscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      _sendMessage({'type': 'auth', 'username': user.username});
      onConnectionChanged?.call(true);
      _startHeartbeat();
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final Map<String, dynamic> message = json.decode(data as String);
      final String type = message['type'] ?? 'unknown';

      switch (type) {
        case 'message':
        case 'group_message':
          onMessageReceived?.call(message);
          break;
        case 'typing':
          _handleTypingIndicator(message);
          break;
        case 'file_metadata':
          _handleFileMetadata(message);
          break;
        case 'file_chunk':
          _handleFileChunk(message);
          break;
        case 'group_invite':
          onGroupInviteReceived?.call(
            message['groupData'] as Map<String, dynamic>,
            message['from'] as String,
          );
          break;
        case 'file_comment':
          onFileCommentReceived?.call(
            message['commentData'] as Map<String, dynamic>,
            message['groupId'] as int,
          );
          break;
        case 'file_tags':
          onFileTagsReceived?.call(
            message['fileId'] as String,
            message['tags'] as List<dynamic>,
            message['groupId'] as int,
          );
          break;
        case 'request_download':
          onDownloadRequestReceived?.call(
              message['fileId'] as String, message['from'] as String);
          break;
        case 'announce_chunk':
          onAnnounceChunkReceived?.call(message['from'] as String,
              message['fileId'] as String, message['chunkIndex'] as int);
          break;
        case 'request_specific_chunk':
          onRequestSpecificChunk?.call(message['from'] as String,
              message['fileId'] as String, message['chunkIndex'] as int);
          break;

        case 'friend_request':
          onFriendRequest?.call(message);
          break;
        case 'friend_accept':
          onFriendAccept?.call(message);
          break;
        // ---- THÊM CASE MỚI ----
        case 'friend_reject':
          onFriendReject?.call(message);
          break;
        // -------------------------

        case 'error':
          onError?.call(message['message'] ?? 'Unknown server error');
          break;
        case 'pong':
          break;
        case 'ping':
          _sendMessage({'type': 'pong'});
          break;
        default:
          print('Unknown message type: $type');
      }
    } catch (e) {
      onError?.call('Failed to parse message: $e');
    }
  }

  void _handleTypingIndicator(Map<String, dynamic> data) {
    final username = data['from'] as String?;
    final isTyping = data['isTyping'] as bool? ?? false;
    if (username != null && username != _currentUser?.username) {
      onTypingReceived?.call(username, isTyping);
    }
  }

  void _handleFileMetadata(Map<String, dynamic> data) {
    try {
      Map<String, dynamic> metadataMap = data['metadata'];
      if (data['groupId'] != null) {
        metadataMap['groupId'] = data['groupId'];
      }
      onFileMetadataReceived?.call(FileMetadata.fromMap(metadataMap));
    } catch (e) {
      print("Error handling file metadata: $e");
    }
  }

  void _handleFileChunk(Map<String, dynamic> data) {
    try {
      final fileId = data['fileId'] as String?;
      final chunkIndex = data['chunkIndex'] as int?;
      final chunkDataBase64 = data['chunkData'] as String?;
      final from = data['from'] as String?;
      final checksum = data['checksum'] as String?;
      final signature = data['signature'] as String?;
      if (fileId != null &&
          chunkIndex != null &&
          chunkDataBase64 != null &&
          from != null) {
        onFileChunkReceived?.call(fileId, chunkIndex,
            base64.decode(chunkDataBase64), from, checksum, signature);
      }
    } catch (e) {
      print("Error handling file chunk: $e");
    }
  }

  void sendMessage(Message message, String recipientUsername) {
    if (!_isConnected || recipientUsername.isEmpty) return;
    String content = message.content;
    _sendMessage({
      'type': 'message',
      'from': _currentUser?.username,
      'to': recipientUsername,
      'text': content, // (Nội dung này đã được mã hóa ở provider)
    });
  }

  void sendGroupMessage(Message message) {
    if (!_isConnected || message.groupId == null) return;
    _sendMessage({
      'type': 'group_message',
      'from': _currentUser?.username,
      'groupId': message.groupId,
      'text': message.content,
    });
  }

  void sendTypingIndicator(bool isTyping, String? recipientUsername) {
    if (!_isConnected || recipientUsername == null || recipientUsername.isEmpty)
      return;
    _sendMessage({
      'type': 'typing',
      'from': _currentUser?.username,
      'to': recipientUsername,
      'isTyping': isTyping,
    });
  }

  void sendFileMetadata(FileMetadata metadata,
      {String? recipient, int? groupId}) {
    if (!_isConnected) return;
    if (recipient == null && groupId == null) return;
    _sendMessage({
      'type': 'file_metadata',
      'metadata': metadata.toMap(),
      'from': _currentUser?.username,
      'to': recipient,
      'groupId': groupId,
    });
  }

  void sendFileChunk({
    required String fileId,
    required int chunkIndex,
    required Uint8List chunkData,
    required int totalChunks,
    String? recipient,
    int? groupId,
    String? checksum,
    String? signature,
  }) {
    if (!_isConnected) return;
    if (recipient == null && groupId == null) return;
    _sendMessage({
      'type': 'file_chunk',
      'fileId': fileId,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
      'chunkData': base64.encode(chunkData),
      'checksum': checksum,
      'signature': signature,
      'from': _currentUser?.username,
      'to': recipient,
      'groupId': groupId,
    });
  }

  void sendGroupInvite(Group group, String toUsername) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'group_invite',
      'from': _currentUser!.username,
      'to': toUsername,
      'groupData': group.toMap(),
    });
  }

  void sendFileComment(Comment comment, int groupId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'file_comment',
      'from': _currentUser!.username,
      'groupId': groupId,
      'commentData': comment.toMap(),
    });
  }

  void sendFileTags(String fileId, List<String> tags, int groupId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'file_tags',
      'from': _currentUser!.username,
      'groupId': groupId,
      'fileId': fileId,
      'tags': tags,
    });
  }

  void requestFileDownload(String fileId, String toUsername) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'request_download',
      'fileId': fileId,
      'from': _currentUser!.username,
      'to': toUsername,
    });
  }

  void announceChunk(String fileId, int chunkIndex) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'announce_chunk',
      'from': _currentUser!.username,
      'fileId': fileId,
      'chunkIndex': chunkIndex,
    });
  }

  void requestSpecificChunk(String toUsername, String fileId, int chunkIndex) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'request_specific_chunk',
      'from': _currentUser!.username,
      'to': toUsername,
      'fileId': fileId,
      'chunkIndex': chunkIndex,
    });
  }

  void joinFileRoom(String fileId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'join_file_room',
      'username': _currentUser!.username,
      'fileId': fileId,
    });
  }

  void leaveFileRoom(String fileId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'leave_file_room',
      'username': _currentUser!.username,
      'fileId': fileId,
    });
  }

  void joinGroupRoom(int groupId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'join_group_room',
      'groupId': groupId,
    });
  }

  void leaveGroupRoom(int groupId) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'leave_group_room',
      'groupId': groupId,
    });
  }

  /// Gửi yêu cầu kết bạn đến
  void sendFriendRequest(String toUsername) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'friend_request',
      'from': _currentUser!.username,
      'to': toUsername,
    });
  }

  /// Gửi phản hồi chấp nhận kết bạn
  void sendFriendAccept(String toUsername) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'friend_accept',
      'from': _currentUser!.username,
      'to': toUsername,
    });
  }

  // ---- THÊM HÀM GỬI MỚI ----
  /// Gửi phản hồi từ chối kết bạn
  void sendFriendReject(String toUsername) {
    if (!_isConnected || _currentUser == null) return;
    _sendMessage({
      'type': 'friend_reject',
      'from': _currentUser!.username,
      'to': toUsername,
    });
  }
  // -------------------------

  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(json.encode(message));
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) _sendMessage({'type': 'ping'});
    });
  }

  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    onError?.call('Connection error');
    _handleDisconnection();
  }

  void _handleDisconnection() {
    if (!_isConnected) return;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    onConnectionChanged?.call(false);
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    await _streamSubscription?.cancel();
    if (_channel != null) {
      await _channel!.sink.close();
    }
    _currentUser = null;
    if (_isConnected) {
      _handleDisconnection();
    }
  }
}
