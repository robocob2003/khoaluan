// lib/services/local_http_server.dart

import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:collection/collection.dart'; // <-- THÊM IMPORT NÀY
import '../models/file_transfer.dart';
import '../services/db_service.dart';
import '../services/file_service.dart';

class LocalHttpServer {
  HttpServer? _server;
  final int _port = 8080;

  static final LocalHttpServer _instance = LocalHttpServer._internal();
  factory LocalHttpServer() => _instance;
  LocalHttpServer._internal();

  Future<void> startServer() async {
    if (_server != null) {
      print('Local HTTP server is already running.');
      return;
    }
    final router = Router();
    router.get('/stream/<fileId>', _streamFileHandler);
    final handler = const Pipeline().addHandler(router);
    try {
      _server = await io.serve(handler, 'localhost', _port);
      print('✅ Local HTTP server started on http://localhost:$_port');
    } catch (e) {
      print('💥 Failed to start local HTTP server: $e');
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    print('🛑 Local HTTP server stopped.');
  }

  String getStreamUrl(String fileId) {
    return 'http://localhost:$_port/stream/$fileId';
  }

  Future<Response> _streamFileHandler(Request request, String fileId) async {
    final FileMetadata? metadata = await DBService.getFileTransfer(fileId);
    if (metadata == null) {
      return Response.notFound('File metadata not found.');
    }
    final controller = StreamController<List<int>>();
    _startChunkStream(controller, fileId, metadata.totalChunks);
    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': metadata.mimeType ?? 'application/octet-stream',
        'Content-Length': metadata.fileSize.toString(),
        'Accept-Ranges': 'bytes',
      },
    );
  }

  void _startChunkStream(StreamController<List<int>> controller, String fileId,
      int totalChunks) async {
    try {
      for (int i = 0; i < totalChunks; i++) {
        FileChunkData? chunk; // <-- Khai báo chunk là nullable
        while (chunk == null) {
          if (controller.isClosed) {
            print('Stream controller closed, stopping chunk fetching.');
            return;
          }
          final chunks = await DBService.getFileChunks(fileId);

          // ---- SỬA LỖI Ở ĐÂY ----
          // Sử dụng firstWhereOrNull thay thế
          chunk = chunks.firstWhereOrNull((c) => c.chunkIndex == i);
          // ------------------------

          if (chunk == null) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
        final chunkData = await FileService.readChunk(chunk);
        if (chunkData != null) {
          controller.add(chunkData);
        }
      }
    } catch (e) {
      print('Error while streaming chunks: $e');
      controller.addError(e);
    } finally {
      print('Finished streaming all chunks. Closing controller.');
      await controller.close();
    }
  }
}
