// demo/lib/models/file_transfer.dart

enum FileStatus { pending, transferring, completed, failed }

enum ChunkStatus { pending, transferred, verified, failed }

class FileMetadata {
  final String id;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  // --- THAY ĐỔI TỪ int -> String ---
  final String senderId;
  final String? receiverId;
  final String? groupId;
  // --- KẾT THÚC THAY ĐỔI ---
  final DateTime timestamp;
  final String? filePath;
  final FileStatus status;
  final String? mimeType;
  final List<String> tags;

  FileMetadata({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.senderId, // Đã là String
    this.receiverId, // Đã là String?
    this.groupId, // Đã là String?
    required this.timestamp,
    this.filePath,
    this.status = FileStatus.pending,
    this.mimeType,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'totalChunks': totalChunks,
      'senderId': senderId, // Đã là String
      'receiverId': receiverId, // Đã là String?
      'groupId': groupId, // Đã là String?
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'status': status.toString(),
      'mimeType': mimeType,
    };
  }

  factory FileMetadata.fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      totalChunks: map['totalChunks'] ?? 0,
      // --- THAY ĐỔI TỪ int -> String ---
      senderId: map['senderId']?.toString() ?? '', // Chuyển đổi an toàn
      receiverId: map['receiverId']?.toString(),
      groupId: map['groupId']?.toString(),
      // --- KẾT THÚC THAY ĐỔI ---
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      filePath: map['filePath'],
      status: _parseFileStatus(map['status']),
      mimeType: map['mimeType'],
    );
  }

  static FileStatus _parseFileStatus(String? statusStr) {
    if (statusStr == null) return FileStatus.pending;
    return FileStatus.values.firstWhere(
      (e) => e.toString() == statusStr,
      orElse: () => FileStatus.pending,
    );
  }

  FileMetadata copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    int? totalChunks,
    String? senderId, // Đã là String
    String? receiverId, // Đã là String?
    String? groupId, // Đã là String?
    DateTime? timestamp,
    String? filePath,
    FileStatus? status,
    String? mimeType,
    List<String>? tags,
  }) {
    return FileMetadata(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      totalChunks: totalChunks ?? this.totalChunks,
      senderId: senderId ?? this.senderId, // Đã là String
      receiverId: receiverId ?? this.receiverId, // Đã là String?
      groupId: groupId ?? this.groupId, // Đã là String?
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      mimeType: mimeType ?? this.mimeType,
      tags: tags ?? this.tags,
    );
  }
}

// (FileChunkData giữ nguyên, nó đã dùng fileId là String)
class FileChunkData {
  final int? id;
  final String fileId;
  final int chunkIndex;
  final int chunkSize;
  final String? chunkPath;
  final bool isEncrypted;
  final ChunkStatus status;
  final String? checksum;

  FileChunkData({
    this.id,
    required this.fileId,
    required this.chunkIndex,
    required this.chunkSize,
    this.chunkPath,
    this.isEncrypted = false,
    this.status = ChunkStatus.pending,
    this.checksum,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileId': fileId,
      'chunkIndex': chunkIndex,
      'chunkSize': chunkSize,
      'chunkPath': chunkPath,
      'isEncrypted': isEncrypted ? 1 : 0,
      'status': status.toString(),
      'checksum': checksum,
    };
  }

  factory FileChunkData.fromMap(Map<String, dynamic> map) {
    return FileChunkData(
      id: map['id'],
      fileId: map['fileId'] ?? '',
      chunkIndex: map['chunkIndex'] ?? 0,
      chunkSize: map['chunkSize'] ?? 0,
      chunkPath: map['chunkPath'],
      isEncrypted: map['isEncrypted'] == 1,
      status: _parseChunkStatus(map['status']),
      checksum: map['checksum'],
    );
  }

  static ChunkStatus _parseChunkStatus(String? statusStr) {
    if (statusStr == null) return ChunkStatus.pending;
    return ChunkStatus.values.firstWhere(
      (e) => e.toString() == statusStr,
      orElse: () => ChunkStatus.pending,
    );
  }

  FileChunkData copyWith({
    int? id,
    String? fileId,
    int? chunkIndex,
    int? chunkSize,
    String? chunkPath,
    bool? isEncrypted,
    ChunkStatus? status,
    String? checksum,
  }) {
    return FileChunkData(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkPath: chunkPath ?? this.chunkPath,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      status: status ?? this.status,
      checksum: checksum ?? this.checksum,
    );
  }
}
