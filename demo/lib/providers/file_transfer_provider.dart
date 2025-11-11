// lib/providers/file_transfer_provider.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pointycastle/export.dart';
import 'package:synchronized/synchronized.dart';
import 'package:collection/collection.dart';

// --- THAY ĐỔI IMPORT ---
import '../services/identity_service.dart';
import '../services/p2p_service.dart'; // Sẽ cần cho P2P
import '../models/file_transfer.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/file_service.dart';
import '../services/rsa_service.dart'; // Sẽ cần sửa file RSA
import '../services/websocket_service.dart';
// import '../services/streaming_service.dart'; // P2P WebRTC sẽ lo
// import 'auth_provider.dart'; // ĐÃ XÓA
// --- KẾT THÚC THAY ĐỔI ---

class FileTransferProvider with ChangeNotifier {
  final Map<String, double> _uploadProgress = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, FileStatus> _fileStatuses = {};
  final List<FileMetadata> _sentFiles = [];
  final List<FileMetadata> _receivedFiles = [];

  // --- THAY ĐỔI ---
  late WebSocketService _webSocketService; // Vẫn cần cho Signaling
  P2PService? _p2pService; // Dùng cho truyền P2P
  IdentityService? _identityService;
  // --- KẾT THÚC THAY ĐỔI ---

  final Set<String> _activeTransfers = {};
  final Lock _dbLock = Lock();

  final Map<String, Map<String, Set<int>>> _chunkAvailabilityMap = {};
  final Map<String, List<String>> _fileTags = {};
  List<String> getTagsForFile(String fileId) => _fileTags[fileId] ?? [];

  bool _isLoading = false;
  String? _error;

  // --- THAY ĐỔI: setAuthProvider -> setIdentityService ---
  void setIdentityService(IdentityService identityService) {
    _identityService = identityService;
  }
  // --- KẾT THÚC THAY ĐỔI ---

  Lock get dbLock => _dbLock;

  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  Map<String, double> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);
  Map<String, FileStatus> get fileStatuses => Map.unmodifiable(_fileStatuses);
  List<FileMetadata> get sentFiles => List.unmodifiable(_sentFiles);
  List<FileMetadata> get receivedFiles => List.unmodifiable(_receivedFiles);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- CẬP NHẬT: Thêm P2PService ---
  void setServices(WebSocketService wsService, P2PService p2pService) {
    _webSocketService = wsService;
    _p2pService = p2pService;

    // TODO: Lắng nghe P2PService để nhận file/chunk
    // _p2pService.onFileReceived = (senderId, metadata) { ... }
    // _p2pService.onChunkReceived = (senderId, chunk) { ... }
  }
  // --- KẾT THÚC CẬP NHẬT ---

  Future<void> handleIncomingFileTags(String fileId, List<String> tags) async {
    try {
      await DBService.addFileTags(fileId, tags);
      _fileTags[fileId] = tags;
      notifyListeners();
      print("🏷️  Đã nhận và lưu tags cho file $fileId.");
    } catch (e) {
      print("Lỗi lưu file tags: $e");
    }
  }

  // --- THAY ĐỔI: int groupId -> String groupId ---
  Future<void> sendFileTags(
      String fileId, String groupId, List<String> tags) async {
    if (tags.isEmpty) return;
    await DBService.addFileTags(fileId, tags);
    _fileTags[fileId] = tags;
    // TODO: Gửi P2P
    // _p2pService.broadcastToGroup(groupId, {'type': 'file_tags', 'fileId': fileId, 'tags': tags});
    print("P2P: Gửi file tags (chưa implement)");
    notifyListeners();
  }

  // (Hàm _handleChunkRequest đã bị xóa vì P2PService lo)

  // --- THAY ĐỔI: UserModel -> String (PeerId) ---
  Future<Message?> processIncomingFileMetadata(
      FileMetadata metadata, String senderPeerId) async {
    return _dbLock.synchronized(() async {
      print('🔒 [RECEIVER] Nhận metadata: ${metadata.fileName}');

      String? receiverId = metadata.receiverId;
      if (metadata.groupId != null) {
        receiverId = _identityService?.myPeerId;
      }

      final sender = await DBService.getUserById(senderPeerId);
      final senderUsername = sender?.username ??
          'Peer...${senderPeerId.substring(senderPeerId.length - 6)}';

      final fileMessage = Message(
        content: 'Đã nhận tệp: ${metadata.fileName}',
        senderId: metadata.senderId, // Đã là String
        receiverId: receiverId, // Đã là String
        groupId: metadata.groupId, // Đã là String
        timestamp: metadata.timestamp,
        type: MessageType.file,
        fileId: metadata.id,
        fileName: metadata.fileName,
        fileSize: metadata.fileSize,
        fileStatus: metadata.status,
        senderUsername: senderUsername,
      );
      try {
        final metadataToSave = metadata.copyWith(receiverId: receiverId);

        await DBService.saveIncomingFileTransferAndMessage(
            metadataToSave, fileMessage);
        print('✅ [RECEIVER] Đã lưu metadata: ${metadata.fileName}');

        if (metadata.groupId == null) {
          final existing =
              _receivedFiles.firstWhereOrNull((f) => f.id == metadata.id);
          if (existing == null) _receivedFiles.insert(0, metadataToSave);
        }

        _fileStatuses[metadata.id] = metadata.status;
        notifyListeners();
        return fileMessage;
      } catch (e) {
        print("💥 [RECEIVER] Lỗi processIncomingFileMetadata: $e");
        _setError("Failed to process incoming file: $e");
        return null;
      }
    });
  }

  // (Các hàm streaming sẽ được thay bằng WebRTC streaming)

  // --- THAY ĐỔI: int userId -> String userId ---
  Future<void> loadFileHistory(String userId) async {
    if (userId.isEmpty) return;
    _setLoading(true);
    try {
      final sent = await DBService.getSentFiles(userId);
      final received = await DBService.getReceivedFiles(userId);
      _sentFiles.clear();
      _sentFiles.addAll(sent);
      _receivedFiles.clear();
      _receivedFiles.addAll(received);
      for (final file in [...sent, ...received]) {
        _fileStatuses[file.id] = file.status;
      }
    } catch (e) {
      _setError('Failed to load file history: $e');
    } finally {
      _setLoading(false);
    }
    notifyListeners();
  }

  // --- THAY ĐỔI: int -> String, và dùng P2PService ---
  Future<FileMetadata?> sendFile(String filePath, String targetPeerId) async {
    FileMetadata? metadata;
    try {
      final senderId = _identityService?.myPeerId;
      if (senderId == null) throw Exception('Chưa có định danh (Identity)');

      _setError(null);
      metadata = await FileService.prepareFileForUpload(
          filePath: filePath, senderId: senderId, receiverId: targetPeerId);
      if (metadata == null) throw Exception('Failed to prepare file');

      final chunks = await FileService.splitFileIntoChunks(
          metadata, targetPeerId,
          isEncrypted: false); // Tương lai: dùng E2E

      _sentFiles.insert(0, metadata);
      _fileStatuses[metadata.id] = FileStatus.pending;
      _uploadProgress[metadata.id] = 0.0;
      await DBService.saveNewFileTransfer(metadata, chunks);

      // GỬI P2P
      // TODO: Gửi metadata qua P2PService
      // _p2pService.sendMessage(targetPeerId, json.encode({'type': 'file_meta', ...metadata.toMap()}));
      print("P2P: Gửi file metadata (chưa implement)");
    } catch (e) {
      _setError('Failed to send file metadata: $e');
      if (metadata != null) _fileStatuses[metadata.id] = FileStatus.failed;
    }
    notifyListeners();
    return metadata;
  }

  // --- THAY ĐỔI: int -> String, và dùng P2PService ---
  Future<FileMetadata?> sendFileToGroup({
    required String filePath,
    required String groupId,
    bool isEncrypted = false,
  }) async {
    FileMetadata? metadata;
    try {
      final senderId = _identityService?.myPeerId;
      if (senderId == null) throw Exception('Chưa có định danh (Identity)');

      _setError(null);

      metadata = await FileService.prepareFileForUpload(
          filePath: filePath, senderId: senderId, groupId: groupId);
      if (metadata == null) throw Exception('Failed to prepare file');

      final chunks = await FileService.splitFileIntoChunks(
        metadata,
        "group_$groupId",
        isEncrypted: isEncrypted,
      );

      _sentFiles.insert(0, metadata);
      _fileStatuses[metadata.id] = FileStatus.pending;
      _uploadProgress[metadata.id] = 0.0;

      await DBService.saveNewFileTransfer(metadata, chunks);

      // GỬI P2P (Broadcase cho nhóm)
      // TODO: Gửi metadata qua P2PService
      // _p2pService.broadcastToGroup(groupId, json.encode({'type': 'file_meta', ...metadata.toMap()}));
      print("P2P: Gửi file metadata nhóm (chưa implement)");
    } catch (e) {
      _setError('Failed to send file to group: $e');
      if (metadata != null) _fileStatuses[metadata.id] = FileStatus.failed;
    }
    notifyListeners();
    return metadata;
  }

  // (startSendingFileChunks, requestDownload... sẽ được thay bằng P2PService)
  // ...

  // --- THAY ĐỔI: int -> String ---
  Future<void> receiveFileChunk(
      String fileId,
      int chunkIndex,
      Uint8List chunkData,
      String senderPeerId, // Đã là String
      String? checksum,
      String? signature) async {
    await _dbLock.synchronized(() async {
      print('🔒 [RECEIVER] Nhận chunk $chunkIndex của $fileId');
      try {
        if (checksum != null) {
          final receivedChecksum = sha256.convert(chunkData).toString();
          if (receivedChecksum != checksum)
            throw Exception('Checksum mismatch');
        }

        // --- THAY ĐỔI: Xác thực chữ ký bằng P2P ---
        if (signature != null) {
          // TODO: Cần có cơ chế lấy Public Key của Peer
          // final sender = await DBService.getUserById(senderPeerId);
          // if (sender?.publicKey == null) throw Exception('Không tìm thấy Public Key');
          //
          // final isValid = await Future(() => RSAService.verifySignature(
          //     data: chunkData,
          //     base64Signature: signature,
          //     publicKeyPem: sender!.publicKey!)); // Dùng publicKey
          // if (!isValid) throw Exception('SIGNATURE INVALID');
          print("P2P: Xác thực chữ ký (chưa implement)");
        }
        // --- KẾT THÚC THAY ĐỔI ---

        final chunkPath = await FileService.writeReceivedChunk(
            fileId, chunkIndex, chunkData,
            senderUsername: senderPeerId); // Dùng PeerId làm tên
        if (chunkPath != null) {
          final record = FileChunkData(
              fileId: fileId,
              chunkIndex: chunkIndex,
              chunkSize: chunkData.length,
              chunkPath: chunkPath,
              status: ChunkStatus.transferred,
              checksum: checksum);
          await DBService.insertFileChunk(record);

          final metadata = await DBService.getFileTransfer(fileId);
          if (metadata != null) {
            final count = await DBService.getCompletedChunksCount(fileId);
            final progress = count / metadata.totalChunks;
            _downloadProgress[fileId] = progress;

            if (progress >= 1.0 &&
                _fileStatuses[fileId] != FileStatus.completed) {
              _fileStatuses[fileId] = FileStatus.completed;
              print(
                  '✅ [RECEIVER] Download complete for ${metadata.fileName}. Updating status.');
              await DBService.updateFileTransferStatus(
                  fileId, FileStatus.completed);
            }
          }
        }
      } catch (e) {
        print(
            "💥 [RECEIVER] Error processing chunk $chunkIndex for $fileId: $e");
        _setError('Failed to process received chunk: $e');
        _fileStatuses[fileId] = FileStatus.failed;
        await DBService.updateFileTransferStatus(fileId, FileStatus.failed);
      } finally {
        print(
            '🔑 [RECEIVER] Releasing lock after chunk $chunkIndex of $fileId');
      }
    });
    notifyListeners();
  }

  Future<void> openFile(String fileId) async {
    // (Giữ nguyên logic)
    try {
      _setError(null);
      final metadata = await DBService.getFileTransfer(fileId);
      if (metadata == null) throw Exception('Metadata not found');
      if (metadata.status != FileStatus.completed)
        throw Exception('File not ready');
      String filePath = metadata.filePath ?? '';
      if (filePath.isEmpty || !await File(filePath).exists()) {
        final chunks = await DBService.getFileChunks(fileId);
        if (chunks.isEmpty) throw Exception('No chunks to assemble');
        final assembledFile =
            await FileService.assembleFileFromChunks(metadata, chunks);
        if (assembledFile == null) throw Exception('Failed to assemble');
        filePath = assembledFile.path;
        await DBService.updateFileTransferPath(fileId, filePath);
      }
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) throw Exception(result.message);
    } catch (e) {
      _setError('Failed to open file: $e');
    }
    notifyListeners();
  }

  Future<void> deleteFile(String fileId) async {
    // (Giữ nguyên)
    try {
      // TODO: Rời P2P room (nếu có)
      // _webSocketService.leaveFileRoom(fileId);
      final metadata = await DBService.getFileTransfer(fileId);
      await DBService.deleteFileTransfer(fileId);
      if (metadata?.filePath != null &&
          await File(metadata!.filePath!).exists()) {
        await File(metadata.filePath!).delete();
      }
      await FileService.deleteFileChunks(fileId, isIncoming: true);
      await FileService.deleteFileChunks(fileId, isIncoming: false);
      _activeTransfers.remove(fileId);
      _sentFiles.removeWhere((f) => f.id == fileId);
      _receivedFiles.removeWhere((f) => f.id == fileId);
      _fileStatuses.remove(fileId);
      _uploadProgress.remove(fileId);
      _downloadProgress.remove(fileId);
    } catch (e) {
      _setError('Failed to delete file: $e');
    }
    notifyListeners();
  }

  void cancelFileTransfer(String fileId) async {
    // (Giữ nguyên)
    try {
      await DBService.updateFileTransferStatus(fileId, FileStatus.failed);
      _fileStatuses[fileId] = FileStatus.failed;
      _uploadProgress.remove(fileId);
      _downloadProgress.remove(fileId);
    } catch (e) {
      _setError('Failed to cancel transfer: $e');
    }
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }
}
