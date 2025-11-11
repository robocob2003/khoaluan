// lib/providers/comment_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import 'auth_provider.dart';

class CommentProvider with ChangeNotifier {
  AuthProvider? _authProvider;

  // Key: fileId, Value: List of comments
  final Map<String, List<Comment>> _comments = {};

  // Getters
  List<Comment> getCommentsForFile(String fileId) {
    return _comments[fileId] ?? [];
  }

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  /// Tải bình luận từ DB
  Future<void> loadCommentsForFile(String fileId) async {
    final comments = await DBService.getCommentsForFile(fileId);
    _comments[fileId] = comments;
    notifyListeners();
  }

  /// Nhận bình luận (từ DB hoặc WebSocket)
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
    if (_authProvider?.user == null) return null;

    final user = _authProvider!.user!;

    final comment = Comment(
      fileId: fileId,
      senderId: user.id!,
      senderUsername: user.username,
      content: content,
      timestamp: DateTime.now(),
    );

    // Lưu vào DB
    final newId = await DBService.addFileComment(comment);
    final savedComment = comment.copyWith(id: newId); // Tạo comment mới với ID

    // Cập nhật state
    addComment(savedComment);

    // Trả về comment đã lưu để WebSocket gửi đi
    return savedComment;
  }
}
