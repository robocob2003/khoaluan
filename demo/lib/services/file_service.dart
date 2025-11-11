// lib/services/file_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:crypto/crypto.dart';
import '../models/file_transfer.dart';
import '../utils/helpers.dart';

class FileService {
  static const int _chunkSize = 250 * 1024;
  static const int _maxFileSize = 100 * 1024 * 1024;

  static Future<String> getAppDirectoryPath() async {
    if (kIsWeb) return 'files';
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<Directory> _ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<FileMetadata?> prepareFileForUpload({
    required String filePath,
    required int senderId,
    int? receiverId, // Cho phép null
    int? groupId, // Thêm groupId
  }) async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('File operations not supported on web.');
      }
      if (receiverId == null && groupId == null) {
        throw Exception('Must provide either receiverId or groupId');
      }

      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        print('File size exceeds the limit of $_maxFileSize bytes.');
        return null;
      }

      final fileName = path.basename(filePath);
      final totalChunks = (fileSize / _chunkSize).ceil();
      final fileId =
          'file_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

      return FileMetadata(
        id: fileId,
        fileName: fileName,
        fileSize: fileSize,
        totalChunks: totalChunks,
        senderId: senderId,
        receiverId: receiverId,
        groupId: groupId,
        timestamp: DateTime.now(),
        filePath: filePath,
        mimeType: _getMimeType(fileName),
      );
    } catch (e) {
      print('Error preparing file for upload: $e');
      return null;
    }
  }

  // ---- HÀM ĐÃ SỬA ----
  static Future<List<FileChunkData>> splitFileIntoChunks(
    FileMetadata metadata,
    String recipientUsername, {
    required bool isEncrypted, // <-- THÊM THAM SỐ
  }) async {
    if (kIsWeb || metadata.filePath == null) {
      throw UnsupportedError(
          'File splitting is not supported on this platform.');
    }
    final file = File(metadata.filePath!);
    final appDir = await getAppDirectoryPath();
    final chunksDir = await _ensureDirectoryExists(
        path.join(appDir, 'chunks', 'outgoing', metadata.id));
    final chunks = <FileChunkData>[];

    for (int i = 0; i < metadata.totalChunks; i++) {
      final start = i * _chunkSize;
      final end = min(start + _chunkSize, metadata.fileSize);
      final fileStream = file.openRead(start, end);
      final chunkBytesList = await fileStream.toList();
      final chunkBytes =
          Uint8List.fromList(chunkBytesList.expand((x) => x).toList());

      // TODO: Thêm logic mã hóa `chunkBytes` ở đây nếu isEncrypted là true

      final chunkPath = path.join(chunksDir.path, 'chunk_$i');
      await File(chunkPath).writeAsBytes(chunkBytes);
      final checksum = sha256.convert(chunkBytes).toString();

      chunks.add(FileChunkData(
        fileId: metadata.id,
        chunkIndex: i,
        chunkSize: end - start,
        chunkPath: chunkPath,
        isEncrypted: isEncrypted, // <-- LƯU GIÁ TRỊ VÀO ĐÂY
        checksum: checksum,
      ));
    }
    return chunks;
  }
  // --------------------

  // (Các hàm còn lại: readChunk, writeReceivedChunk, v.v... giữ nguyên)

  static Future<Uint8List?> readChunk(FileChunkData chunk) async {
    try {
      if (chunk.chunkPath == null) return null;
      final file = File(chunk.chunkPath!);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      print('Error reading chunk: $e');
      return null;
    }
  }

  static Future<String?> writeReceivedChunk(
      String fileId, int chunkIndex, Uint8List data,
      {required String senderUsername}) async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('File operations not supported on web.');
      }
      final appDir = await getAppDirectoryPath();
      final chunksDir = await _ensureDirectoryExists(
          path.join(appDir, 'chunks', 'incoming', fileId));

      final chunkPath = path.join(chunksDir.path, 'chunk_$chunkIndex');
      await File(chunkPath).writeAsBytes(data);
      return chunkPath;
    } catch (e) {
      print('Error writing received chunk: $e');
      return null;
    }
  }

  static Future<File?> assembleFileFromChunks(
      FileMetadata metadata, List<FileChunkData> chunks) async {
    if (kIsWeb) throw UnsupportedError('File assembly not supported on web.');
    chunks.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));

    final appDir = await getAppDirectoryPath();
    final downloadsDir =
        await _ensureDirectoryExists(path.join(appDir, 'downloads'));
    final outputFile = File(path.join(downloadsDir.path, metadata.fileName));
    final sink = outputFile.openWrite();

    try {
      for (final chunk in chunks) {
        final chunkData = await readChunk(chunk);
        if (chunkData == null) {
          throw Exception('Missing chunk data for index ${chunk.chunkIndex}');
        }

        // TODO: Thêm logic giải mã `chunkData` ở đây nếu chunk.isEncrypted là true

        sink.add(chunkData);
      }
      await sink.flush();
      await sink.close();
      return outputFile;
    } catch (e) {
      print('Error assembling file: $e');
      await sink.close();
      if (await outputFile.exists()) await outputFile.delete();
      return null;
    }
  }

  static Future<void> deleteFileChunks(String fileId,
      {required bool isIncoming}) async {
    try {
      if (kIsWeb) return;
      final appDir = await getAppDirectoryPath();
      final type = isIncoming ? 'incoming' : 'outgoing';
      final chunksDir = Directory(path.join(appDir, 'chunks', type, fileId));
      if (await chunksDir.exists()) {
        await chunksDir.delete(recursive: true);
        print('Deleted chunk directory: ${chunksDir.path}');
      }
    } catch (e) {
      print('Error deleting file chunks for $fileId: $e');
    }
  }

  static Future<void> deleteSingleChunk(String fileId, int chunkIndex) async {
    try {
      if (kIsWeb) return;
      final appDir = await getAppDirectoryPath();
      final chunkPath =
          path.join(appDir, 'chunks', 'incoming', fileId, 'chunk_$chunkIndex');
      final chunkFile = File(chunkPath);
      if (await chunkFile.exists()) {
        await chunkFile.delete();
      }
    } catch (e) {
      print('Error deleting single chunk $chunkIndex for $fileId: $e');
    }
  }

  static String _getMimeType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    const mimeTypes = {
      '.pdf': 'application/pdf',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.txt': 'text/plain',
      '.mp4': 'video/mp4',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.doc': 'application/msword',
    };
    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  static bool isImageFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(extension);
  }

  static bool isVideoFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.mp4', '.avi', '.mov', '.mkv', '.webm'].contains(extension);
  }

  static bool isAudioFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return ['.mp3', '.wav', '.aac', 'ogg', '.m4a'].contains(extension);
  }

  static bool isPdfFile(String fileName) {
    return path.extension(fileName).toLowerCase() == '.pdf';
  }
}
