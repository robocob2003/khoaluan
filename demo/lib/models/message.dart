// demo/lib/models/message.dart
import '../models/file_transfer.dart';

enum MessageType { text, file, image, system }

class Message {
  final int? id;
  final String content;
  // --- THAY ĐỔI: int -> String ---
  final String senderId;
  final String? receiverId;
  final String? groupId;
  // --- KẾT THÚC THAY ĐỔI ---
  final DateTime timestamp;
  final MessageType type;
  final String? senderUsername;

  // File props
  final String? fileId;
  final String? fileName;
  final int? fileSize;
  final FileStatus? fileStatus;

  Message({
    this.id,
    required this.content,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.timestamp,
    this.type = MessageType.text,
    this.senderUsername,
    this.fileId,
    this.fileName,
    this.fileSize,
    this.fileStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId, // Đã là String
      'receiverId': receiverId, // Đã là String
      'groupId': groupId, // Đã là String
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString(),
      'senderUsername': senderUsername,
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileStatus': fileStatus?.toString(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'] ?? '',
      // --- THAY ĐỔI: Chuyển đổi an toàn sang String ---
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString(),
      groupId: map['groupId']?.toString(),
      // --- KẾT THÚC THAY ĐỔI ---
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => MessageType.text,
      ),
      senderUsername: map['senderUsername'],
      fileId: map['fileId'],
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      fileStatus: map['fileStatus'] != null
          ? FileStatus.values.firstWhere(
              (e) => e.toString() == map['fileStatus'],
              orElse: () => FileStatus.pending,
            )
          : null,
    );
  }
}
