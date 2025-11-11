// lib/models/message.dart

import 'file_transfer.dart';

enum MessageType { text, file }

class Message {
  final int? id;
  final String content;
  final int senderId;
  final int? receiverId; // Null nếu là tin nhắn nhóm
  final int? groupId; // Null nếu là tin nhắn 1-1
  final DateTime timestamp;
  final MessageType type;

  // File-related properties
  final String? fileId;
  final String? fileName;
  final int? fileSize;
  final FileStatus? fileStatus;

  final String? senderUsername;

  Message({
    this.id,
    required this.content,
    required this.senderId,
    this.receiverId,
    this.groupId, // <-- THÊM
    required this.timestamp,
    this.type = MessageType.text,
    this.fileId,
    this.fileName,
    this.fileSize,
    this.fileStatus = FileStatus.pending,
    this.senderUsername,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'receiverId': receiverId,
      'groupId': groupId, // <-- THÊM
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileStatus': fileStatus?.toString(),
      'senderUsername': senderUsername,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'] ?? '',
      senderId: map['senderId'] ?? 0,
      receiverId: map['receiverId'],
      groupId: map['groupId'], // <-- THÊM
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      type: _parseMessageType(map['type']),
      fileId: map['fileId'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      fileStatus: _parseFileStatus(map['fileStatus']),
      senderUsername: map['senderUsername'],
    );
  }

  static MessageType _parseMessageType(String? typeStr) {
    if (typeStr == null) return MessageType.text;
    return MessageType.values.firstWhere((e) => e.toString() == typeStr,
        orElse: () => MessageType.text);
  }

  static FileStatus _parseFileStatus(String? statusStr) {
    if (statusStr == null) return FileStatus.pending;
    return FileStatus.values.firstWhere((e) => e.toString() == statusStr,
        orElse: () => FileStatus.pending);
  }

  // ---- THÊM PHƯƠNG THỨC NÀY ----
  Message copyWith({
    int? id,
    String? content,
    int? senderId,
    int? receiverId,
    int? groupId,
    DateTime? timestamp,
    MessageType? type,
    String? fileId,
    String? fileName,
    int? fileSize,
    FileStatus? fileStatus,
    String? senderUsername,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileStatus: fileStatus ?? this.fileStatus,
      senderUsername: senderUsername ?? this.senderUsername,
    );
  }
  // ---------------------------------
}
