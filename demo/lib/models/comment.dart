// lib/models/comment.dart

class Comment {
  final int? id;
  final String fileId;
  final int senderId;
  final String senderUsername;
  final String content;
  final DateTime timestamp;

  Comment({
    this.id,
    required this.fileId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      fileId: map['fileId'] ?? '',
      senderId: map['senderId'] ?? 0,
      senderUsername: map['senderUsername'] ?? 'Unknown',
      content: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  // ---- HÀM BỊ THIẾU ĐÃ ĐƯỢC THÊM VÀO ĐÂY ----
  Comment copyWith({
    int? id,
    String? fileId,
    int? senderId,
    String? senderUsername,
    String? content,
    DateTime? timestamp,
  }) {
    return Comment(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  // -----------------------------------------
}
