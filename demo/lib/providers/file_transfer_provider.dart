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
import '../models/file_transfer.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/file_service.dart';
import '../services/rsa_service.dart';
import '../services/websocket_service.dart';
import '../services/streaming_service.dart';
import 'auth_provider.dart';

class FileTransferProvider with ChangeNotifier {
  final Map<String, double> _uploadProgress = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, FileStatus> _fileStatuses = {};
  final List<FileMetadata> _sentFiles = [];
  final List<FileMetadata> _receivedFiles = [];
  late WebSocketService _webSocketService;
  final Map<String, StreamingManager> _streamingManagers = {};
  final Set<String> _activeTransfers = {};
  final Lock _dbLock = Lock();
  AuthProvider? _authProvider;

  final Map<String, Map<String, Set<int>>> _chunkAvailabilityMap = {};

  final Map<String, List<String>> _fileTags = {};
  List<String> getTagsForFile(String fileId) => _fileTags[fileId] ?? [];

  bool _isLoading = false;
  String? _error;

  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  Lock get dbLock => _dbLock;

  Map<String, double> get uploadProgress => Map.unmodifiable(_uploadProgress);
  Map<String, double> get downloadProgress =>
      Map.unmodifiable(_downloadProgress);
  Map<String, FileStatus> get fileStatuses => Map.unmodifiable(_fileStatuses);
  List<FileMetadata> get sentFiles => List.unmodifiable(_sentFiles);
  List<FileMetadata> get receivedFiles => List.unmodifiable(_receivedFiles);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setWebSocketService(WebSocketService service) {
    _webSocketService = service;
    _webSocketService.onRequestSpecificChunk = _handleChunkRequest;

    _webSocketService.onAnnounceChunkReceived =
        (fromUsername, fileId, chunkIndex) {
      if (fromUsername == _authProvider?.user?.username) return;
      if (!_chunkAvailabilityMap.containsKey(fileId)) {
        _chunkAvailabilityMap[fileId] = {};
      }
      if (!_chunkAvailabilityMap[fileId]!.containsKey(fromUsername)) {
        _chunkAvailabilityMap[fileId]![fromUsername] = <int>{};
      }
      _chunkAvailabilityMap[fileId]![fromUsername]!.add(chunkIndex);
      print(
          '🗺️ [Map] Peer $fromUsername now has chunk $chunkIndex for file $fileId.');
    };

    _webSocketService.onFileTagsReceived = (fileId, tags, groupId) {
      final tagList = tags.map((t) => t.toString()).toList();
      handleIncomingFileTags(fileId, tagList); // <-- ĐÃ SỬA
    };
  }

  // ---- HÀM ĐÃ SỬA (BỎ DẤU GẠCH DƯỚI) ----
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
  // ------------------------------------

  Future<void> sendFileTags(
      String fileId, int groupId, List<String> tags) async {
    if (tags.isEmpty) return;
    await DBService.addFileTags(fileId, tags);
    _fileTags[fileId] = tags;
    _webSocketService.sendFileTags(fileId, tags, groupId);
    notifyListeners();
  }

  // (Các hàm còn lại giữ nguyên)

  Future<void> _handleChunkRequest(
      String fromUsername, String fileId, int chunkIndex) async {
    // ... (Giữ nguyên)
    print(
        '📬 [SEEDER] Received request for chunk $chunkIndex of file $fileId from $fromUsername.');
    final privateKey = _authProvider?.privateKey;
    if (privateKey == null) {
      print('❌ [SEEDER] Error: Private key not available.');
      return;
    }
    try {
      final chunkInfo = await _dbLock.synchronized(
          () async => await DBService.getSingleFileChunk(fileId, chunkIndex));

      if (chunkInfo == null || chunkInfo.chunkPath == null) {
        print('⚠️ [SEEDER] Warning: Chunk $chunkIndex not found locally.');
        return;
      }
      final chunkData = await FileService.readChunk(chunkInfo);
      if (chunkData == null) {
        print('❌ [SEEDER] Error: Failed to read chunk data.');
        return;
      }
      final signature = RSAService.signData(chunkData, privateKey);
      final metadata = await DBService.getFileTransfer(fileId);
      _webSocketService.sendFileChunk(
        fileId: fileId,
        chunkIndex: chunkIndex,
        chunkData: chunkData,
        recipient: fromUsername,
        totalChunks: metadata?.totalChunks ?? 0,
        checksum: chunkInfo.checksum,
        signature: signature,
      );
      print('✅ [SEEDER] Sent chunk $chunkIndex to $fromUsername.');
    } catch (e) {
      print('💥 [SEEDER] Error handling chunk request: $e');
    }
  }

  Future<Message?> processIncomingFileMetadata(
      FileMetadata metadata, UserModel currentUser, UserModel sender) async {
    // ... (Giữ nguyên)
    return _dbLock.synchronized(() async {
      print('🔒 [RECEIVER] Acquiring lock for metadata: ${metadata.fileName}');

      int? receiverId = metadata.receiverId;
      if (metadata.groupId != null) {
        receiverId = currentUser.id;
      }

      final senderUsername = _authProvider?.availableUsers
              .firstWhereOrNull((u) => u.id == metadata.senderId)
              ?.username ??
          'Unknown';

      final fileMessage = Message(
        content: 'Đã nhận tệp: ${metadata.fileName}',
        senderId: metadata.senderId,
        receiverId: receiverId,
        groupId: metadata.groupId,
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
        print(
            '✅ [RECEIVER] Attempted save for metadata/message: ${metadata.fileName}');

        _webSocketService.joinFileRoom(metadata.id);
        print('🚪 [P2P] Joined file room: ${metadata.id}');

        if (metadata.groupId == null) {
          final existing =
              _receivedFiles.firstWhereOrNull((f) => f.id == metadata.id);
          if (existing == null) _receivedFiles.insert(0, metadataToSave);
        }

        _fileStatuses[metadata.id] = metadata.status;
        notifyListeners();
        return fileMessage;
      } catch (e) {
        print("💥 [RECEIVER] Error in processIncomingFileMetadata: $e");
        _setError("Failed to process incoming file: $e");
        return null;
      } finally {
        print(
            '🔑 [RECEIVER] Releasing lock after metadata: ${metadata.fileName}');
      }
    });
  }

  Future<StreamingManager?> startStreamingSession(String fileId) async {
    // ... (Giữ nguyên)
    if (_streamingManagers.containsKey(fileId)) {
      return _streamingManagers[fileId];
    }
    final metadata = await DBService.getFileTransfer(fileId);
    if (metadata == null) {
      _setError("Could not find metadata for streaming file $fileId");
      return null;
    }

    _webSocketService.joinFileRoom(fileId);
    print('🚪 [P2P] Joined file room: ${fileId}');

    final manager = StreamingManager(
      fileId: fileId,
      totalChunks: metadata.totalChunks,
      onChunkNeeded: (chunkIndex) async {
        print('💡 [Provider] StreamingManager needs chunk $chunkIndex.');
        List<String> availablePeers = [];

        if (_chunkAvailabilityMap.containsKey(fileId)) {
          _chunkAvailabilityMap[fileId]!.forEach((username, chunkIndices) {
            if (chunkIndices.contains(chunkIndex)) {
              availablePeers.add(username);
            }
          });
        }

        final owner = await DBService.getUserById(metadata.senderId);
        if (owner != null && !availablePeers.contains(owner.username)) {
          availablePeers.add(owner.username);
        }

        if (availablePeers.isNotEmpty) {
          final peerToRequest = availablePeers[
              DateTime.now().millisecond % availablePeers.length];
          print(
              '      -> Found ${availablePeers.length} peers. Requesting from: $peerToRequest');
          _webSocketService.requestSpecificChunk(
              peerToRequest, fileId, chunkIndex);
        } else {
          print(
              '      -> ERROR: No peers found (not even owner). Cannot request chunk.');
        }
      },
      onChunkShouldBeDeleted: (chunkIndex) async {
        await FileService.deleteSingleChunk(fileId, chunkIndex);
      },
    );
    _streamingManagers[fileId] = manager;
    return manager;
  }

  void updateStreamingPlaybackPosition(String fileId, int currentChunkIndex) {
    // ... (Giữ nguyên)
    final manager = _streamingManagers[fileId];
    if (manager != null) {
      manager.updatePlaybackPosition(currentChunkIndex);
    }
  }

  Future<void> loadFileHistory(int userId) async {
    // ... (Giữ nguyên)
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

  Future<FileMetadata?> sendFile(String filePath, String recipientUsername,
      int senderId, int receiverId) async {
    // ... (Giữ nguyên)
    FileMetadata? metadata;
    try {
      _setError(null);
      metadata = await FileService.prepareFileForUpload(
          filePath: filePath, senderId: senderId, receiverId: receiverId);
      if (metadata == null) throw Exception('Failed to prepare file');

      final chunks = await FileService.splitFileIntoChunks(
          metadata, recipientUsername,
          isEncrypted: false);
      _sentFiles.insert(0, metadata);
      _fileStatuses[metadata.id] = FileStatus.pending;
      _uploadProgress[metadata.id] = 0.0;
      await DBService.saveNewFileTransfer(metadata, chunks);

      _webSocketService.sendFileMetadata(metadata,
          recipient: recipientUsername);
    } catch (e) {
      _setError('Failed to send file metadata: $e');
      if (metadata != null) _fileStatuses[metadata.id] = FileStatus.failed;
    }
    notifyListeners();
    return metadata;
  }

  // ---- HÀM ĐÃ SỬA (Sử dụng tham số có tên) ----
  Future<FileMetadata?> sendFileToGroup({
    required String filePath,
    required int groupId,
    required int senderId,
    bool isEncrypted = false, // <-- THÊM THAM SỐ
  }) async {
    FileMetadata? metadata;
    try {
      _setError(null);

      metadata = await FileService.prepareFileForUpload(
          filePath: filePath, senderId: senderId, groupId: groupId);
      if (metadata == null) throw Exception('Failed to prepare file');

      // ---- TRUYỀN THAM SỐ VÀO ĐÂY ----
      final chunks = await FileService.splitFileIntoChunks(
        metadata,
        "group_$groupId",
        isEncrypted: isEncrypted, // <-- SỬ DỤNG GIÁ TRỊ
      );
      // -------------------------------

      _sentFiles.insert(0, metadata);
      _fileStatuses[metadata.id] = FileStatus.pending;
      _uploadProgress[metadata.id] = 0.0;

      await DBService.saveNewFileTransfer(metadata, chunks);

      _webSocketService.sendFileMetadata(metadata, groupId: groupId);

      if (_authProvider?.privateKey != null) {
        startSendingFileChunks(metadata.id, null, _authProvider!.privateKey!,
            groupId: groupId);
      }
    } catch (e) {
      _setError('Failed to send file to group: $e');
      if (metadata != null) _fileStatuses[metadata.id] = FileStatus.failed;
    }
    notifyListeners();
    return metadata;
  }
  // --------------------

  Future<void> startSendingFileChunks(
      String fileId, String? recipientUsername, RSAPrivateKey privateKey,
      {int? groupId}) async {
    // ... (Giữ nguyên)
    if (recipientUsername == null && groupId == null) {
      print("Error: Must provide recipient or groupId to send chunks.");
      return;
    }
    if (_activeTransfers.contains(fileId)) return;
    _activeTransfers.add(fileId);
    try {
      FileMetadata? metadata;
      List<FileChunkData> chunks = [];
      final db = await DBService.database;
      await db.transaction((txn) async {
        final metaRes = await txn.query('file_transfers',
            where: 'id = ?', whereArgs: [fileId], limit: 1);
        if (metaRes.isEmpty) throw Exception('Metadata not found');
        metadata = FileMetadata.fromMap(metaRes.first);
        if (metadata!.status == FileStatus.transferring)
          throw Exception('Already transferring');
        final chunkRes = await txn.query('file_chunks',
            where: 'fileId = ?',
            whereArgs: [fileId],
            orderBy: 'chunkIndex ASC');
        if (chunkRes.isEmpty) throw Exception('No chunks found');
        chunks = chunkRes.map((c) => FileChunkData.fromMap(c)).toList();
        await txn.update(
            'file_transfers', {'status': FileStatus.transferring.toString()},
            where: 'id = ?', whereArgs: [fileId]);
      });
      _fileStatuses[fileId] = FileStatus.transferring;
      _uploadProgress[fileId] = 0.0;
      notifyListeners();
      for (int i = 0; i < chunks.length; i++) {
        final chunkData = await FileService.readChunk(chunks[i]);
        if (chunkData == null) throw Exception('Failed to read chunk');
        final signature = RSAService.signData(chunkData, privateKey);
        _webSocketService.sendFileChunk(
            fileId: fileId,
            chunkIndex: i,
            chunkData: chunkData,
            recipient: recipientUsername,
            groupId: groupId,
            totalChunks: metadata!.totalChunks,
            checksum: chunks[i].checksum,
            signature: signature);
        _uploadProgress[fileId] = (i + 1) / chunks.length;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 50));
      }
      await DBService.updateFileTransferStatus(fileId, FileStatus.completed);
      _fileStatuses[fileId] = FileStatus.completed;
    } catch (e) {
      _setError('Failed to send file chunks: $e');
      _fileStatuses[fileId] = FileStatus.failed;
      await DBService.updateFileTransferStatus(fileId, FileStatus.failed);
    } finally {
      _activeTransfers.remove(fileId);
    }
    notifyListeners();
  }

  Future<void> requestDownload(String fileId) async {
    // ... (Giữ nguyên)
    try {
      final metadata = await DBService.getFileTransfer(fileId);
      if (metadata == null) throw Exception('Metadata not found');
      if (metadata.groupId != null) {
        await requestGroupFileDownload(fileId);
        return;
      }
      final sender = await DBService.getUserById(metadata.senderId);
      if (sender == null) throw Exception('Sender not found');
      _setError(null);
      _downloadProgress[fileId] = 0.0;
      _fileStatuses[fileId] = FileStatus.transferring;
      notifyListeners();
      _webSocketService.requestFileDownload(fileId, sender.username);
    } catch (e) {
      _setError("Failed to start download: $e");
      _fileStatuses[fileId] = FileStatus.failed;
      notifyListeners();
    }
  }

  Future<void> requestGroupFileDownload(String fileId) async {
    // ... (Giữ nguyên)
    try {
      _setError(null);
      _downloadProgress[fileId] = 0.0;
      _fileStatuses[fileId] = FileStatus.transferring;
      notifyListeners();

      final manager = await startStreamingSession(fileId);
      if (manager == null) throw Exception("Failed to start streaming manager");

      for (int i = 0; i < manager.totalChunks; i++) {
        manager.onChunkNeeded(i);
        await Future.delayed(Duration(milliseconds: 10));
      }
      print(
          "P2P Download: Requested all ${manager.totalChunks} chunks for $fileId.");
    } catch (e) {
      _setError("Failed to start P2P download: $e");
      _fileStatuses[fileId] = FileStatus.failed;
      notifyListeners();
    }
  }

  Future<void> receiveFileChunk(
      String fileId,
      int chunkIndex,
      Uint8List chunkData,
      String senderUsername,
      String? checksum,
      String? signature) async {
    // ... (Giữ nguyên)
    await _dbLock.synchronized(() async {
      print('🔒 [RECEIVER] Acquiring lock for chunk $chunkIndex of $fileId');
      try {
        final manager = _streamingManagers[fileId];
        if (manager != null) manager.markChunkAsDownloaded(chunkIndex);
        if (checksum != null) {
          final receivedChecksum = sha256.convert(chunkData).toString();
          if (receivedChecksum != checksum)
            throw Exception('Checksum mismatch');
        }
        if (signature != null) {
          final isValid = await Future(() => RSAService.verifySignature(
              data: chunkData,
              base64Signature: signature,
              username: senderUsername));
          if (!isValid) throw Exception('SIGNATURE INVALID');
        }
        final chunkPath = await FileService.writeReceivedChunk(
            fileId, chunkIndex, chunkData,
            senderUsername: senderUsername);
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

            _webSocketService.announceChunk(fileId, chunkIndex);
            print('📣 [Announce] Broadcasting that I have chunk $chunkIndex.');
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
    // ... (Giữ nguyên)
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
    // ... (Giữ nguyên)
    try {
      _webSocketService.leaveFileRoom(fileId);
      print('🚪 [P2P] Left file room: ${fileId}');
      final metadata = await DBService.getFileTransfer(fileId);
      await DBService.deleteFileTransfer(fileId);
      if (metadata?.filePath != null &&
          await File(metadata!.filePath!).exists()) {
        await File(metadata.filePath!).delete();
      }
      await FileService.deleteFileChunks(fileId, isIncoming: true);
      await FileService.deleteFileChunks(fileId, isIncoming: false);
      _streamingManagers.remove(fileId);
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
    // ... (Giữ nguyên)
    try {
      _webSocketService.leaveFileRoom(fileId);
      print('🚪 [P2P] Left file room: ${fileId}');
      await DBService.updateFileTransferStatus(fileId, FileStatus.failed);
      _fileStatuses[fileId] = FileStatus.failed;
      _uploadProgress.remove(fileId);
      _downloadProgress.remove(fileId);
      _streamingManagers.remove(fileId);
    } catch (e) {
      _setError('Failed to cancel transfer: $e');
    }
    notifyListeners();
  }

  void _setLoading(bool loading) {
    // ... (Giữ nguyên)
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    // ... (Giữ nguyên)
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }
}
