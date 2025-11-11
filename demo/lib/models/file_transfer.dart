// lib/models/file_transfer.dart

enum FileStatus { pending, transferring, completed, failed }

enum ChunkStatus { pending, transferred, verified, failed }

class FileMetadata {
  final String id;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int senderId;
  final int? receiverId;
  final int? groupId;
  final DateTime timestamp;
  final String? filePath;
  final FileStatus status;
  final String? mimeType;

  // ---- THÊM TRƯỜNG MỚI (CHỈ DÙNG CHO UI) ----
  final List<String> tags;

  FileMetadata({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.timestamp,
    this.filePath,
    this.status = FileStatus.pending,
    this.mimeType,
    this.tags = const [], // <-- Thêm
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'totalChunks': totalChunks,
      'senderId': senderId,
      'receiverId': receiverId,
      'groupId': groupId,
      'timestamp': timestamp.toIso8601String(),
      'filePath': filePath,
      'status': status.toString(),
      'mimeType': mimeType,
      // 'tags' không được lưu vào bảng này
    };
  }

  factory FileMetadata.fromMap(Map<String, dynamic> map) {
    return FileMetadata(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      totalChunks: map['totalChunks'] ?? 0,
      senderId: map['senderId'] ?? 0,
      receiverId: map['receiverId'],
      groupId: map['groupId'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      filePath: map['filePath'],
      status: _parseFileStatus(map['status']),
      mimeType: map['mimeType'],
      // 'tags' sẽ được tải riêng
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
    int? senderId,
    int? receiverId,
    int? groupId,
    DateTime? timestamp,
    String? filePath,
    FileStatus? status,
    String? mimeType,
    List<String>? tags, // <-- Thêm
  }) {
    return FileMetadata(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      totalChunks: totalChunks ?? this.totalChunks,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId ?? this.groupId,
      timestamp: timestamp ?? this.timestamp,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      mimeType: mimeType ?? this.mimeType,
      tags: tags ?? this.tags, // <-- Thêm
    );
  }
}

// (FileChunkData giữ nguyên)
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
