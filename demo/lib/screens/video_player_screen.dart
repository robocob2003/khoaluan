import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/file_transfer.dart';
import '../providers/file_transfer_provider.dart';
import '../services/local_http_server.dart';
import '../services/streaming_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final FileMetadata fileMetadata;

  const VideoPlayerScreen({Key? key, required this.fileMetadata})
      : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  StreamingManager? _streamingManager;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final fileProvider = context.read<FileTransferProvider>();
    final server = LocalHttpServer();

    // Bắt đầu server HTTP cục bộ
    await server.startServer();

    // Bắt đầu phiên streaming
    _streamingManager =
        await fileProvider.startStreamingSession(widget.fileMetadata.id);
    if (_streamingManager == null) {
      // Xử lý lỗi nếu không thể bắt đầu streaming
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error starting streaming session.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Lấy URL từ server cục bộ
    final url = server.getStreamUrl(widget.fileMetadata.id);
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play();

      // Lắng nghe sự thay đổi vị trí phát và cập nhật cho StreamingManager
      _controller.addListener(() {
        final position = _controller.value.position;
        final chunkSizeInSeconds =
            5; // Giả sử mỗi chunk tương đương 5 giây video
        final currentChunkIndex =
            (position.inSeconds / chunkSizeInSeconds).floor();
        fileProvider.updateStreamingPlaybackPosition(
            widget.fileMetadata.id, currentChunkIndex);
      });
    } catch (e) {
      print("💥 Video player initialization error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not play video: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dọn dẹp controller và dừng server khi màn hình bị đóng
    _controller.dispose();
    LocalHttpServer().stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileMetadata.fileName),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    _buildControlsOverlay(),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
          child: AnimatedOpacity(
            opacity: _controller.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: Colors.black26,
              child: Center(
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 100.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
