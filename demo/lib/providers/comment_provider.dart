// demo/lib/providers/comment_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/db_service.dart';
import '../services/identity_service.dart'; // THAY THẾ BẰNG IdentityService

class CommentProvider with ChangeNotifier {
  IdentityService? _identityService;

  // Key: fileId, Value: List of comments
  final Map<String, List<Comment>> _comments = {};

  // Getters
  List<Comment> getCommentsForFile(String fileId) {
    return _comments[fileId] ?? [];
  }

  // Dùng IdentityService thay cho AuthProvider
  void setIdentityService(IdentityService identityService) {
    _identityService = identityService;
  }

  /// Tải bình luận từ DB
  Future<void> loadCommentsForFile(String fileId) async {
    final comments = await DBService.getCommentsForFile(fileId);
    _comments[fileId] = comments;
    notifyListeners();
  }

  /// Nhận bình luận (từ DB hoặc WebSocket/P2P)
  void addComment(Comment comment) {
    final fileId = comment.fileId;
    if (!_comments.containsKey(fileId)) {
      _comments[fileId] = [];
    }

    // Tránh thêm trùng lặp (nếu có)
    if (!_comments[fileId]!.any((c) => c.id == comment.id)) {
      _comments[fileId]!.add(comment);
      _comments[fileId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }
  }

  /// Gửi bình luận mới
  Future<Comment?> createComment(String fileId, String content) async {
    if (_identityService?.myPeerId == null) return null;

    final myPeerId = _identityService!.myPeerId!;
    // Giả sử chúng ta muốn hiển thị một tên, có thể lấy 1 phần ID
    final myName = 'Peer...${myPeerId.substring(myPeerId.length - 6)}';

    final comment = Comment(
      fileId: fileId,
      senderId: myPeerId, // Lỗi đã được SỬA (String -> String)
      senderUsername: myName,
      content: content,
      timestamp: DateTime.now(),
    );

    // Lưu vào DB
    final newId = await DBService.addFileComment(comment);
    final savedComment = comment.copyWith(id: newId); // Tạo comment mới với ID

    // Cập nhật state
    addComment(savedComment);

    // Trả về comment đã lưu để gửi đi (qua P2P hoặc server)
    return savedComment;
  }
}
