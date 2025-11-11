// demo/lib/models/comment.dart
class Comment {
  final int? id;
  final String fileId;
  // --- THAY ĐỔI TỪ int -> String ---
  final String senderId;
  // --- KẾT THÚC THAY ĐỔI ---
  final String senderUsername;
  final String content;
  final DateTime timestamp;

  Comment({
    this.id,
    required this.fileId,
    required this.senderId, // Đã là String
    required this.senderUsername,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'senderId': senderId, // Đã là String
      'senderUsername': senderUsername,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      fileId: map['fileId'],
      // --- THAY ĐỔI TỪ int -> String ---
      // (Không cần parse, vì nó đã là String)
      senderId: map['senderId'],
      // --- KẾT THÚC THAY ĐỔI ---
      senderUsername: map['senderUsername'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  Comment copyWith({int? id}) {
    return Comment(
      id: id ?? this.id,
      fileId: fileId,
      senderId: senderId, // Đã là String
      senderUsername: senderUsername,
      content: content,
      timestamp: timestamp,
    );
  }
}
