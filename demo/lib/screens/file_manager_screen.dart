// lib/screens/file_manager_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/file_transfer_provider.dart';
import '../providers/auth_provider.dart';
import '../models/file_transfer.dart';
import '../services/file_service.dart';
import '../utils/helpers.dart';
import 'video_player_screen.dart'; // Thêm import này

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({Key? key}) : super(key: key);

  @override
  _FileManagerScreenState createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFileHistory());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFileHistory() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user?.id != null) {
      await context
          .read<FileTransferProvider>()
          .loadFileHistory(authProvider.user!.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sent', icon: Icon(Icons.upload_file)),
            Tab(text: 'Received', icon: Icon(Icons.download_for_offline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFileHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFilesList(isSent: true),
          _buildFilesList(isSent: false),
        ],
      ),
    );
  }

  Widget _buildFilesList({required bool isSent}) {
    return Consumer<FileTransferProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final files = isSent ? provider.sentFiles : provider.receivedFiles;

        if (files.isEmpty) {
          return Center(
              child: Text('No ${isSent ? 'sent' : 'received'} files yet.'));
        }

        return RefreshIndicator(
          onRefresh: _loadFileHistory,
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: files.length,
            itemBuilder: (context, index) {
              return _FileCard(
                metadata: files[index],
                isSent: isSent,
              );
            },
          ),
        );
      },
    );
  }
}

class _FileCard extends StatelessWidget {
  final FileMetadata metadata;
  final bool isSent;

  const _FileCard({
    Key? key,
    required this.metadata,
    required this.isSent,
  }) : super(key: key);

  // ---- HÀM ĐÃ ĐƯỢC CẬP NHẬT ----
  void _openFile(BuildContext context) async {
    if (FileService.isVideoFile(metadata.fileName)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(fileMetadata: metadata),
        ),
      );
    } else {
      context.read<FileTransferProvider>().openFile(metadata.id);
    }
  }

  void _deleteFile(BuildContext context) =>
      context.read<FileTransferProvider>().deleteFile(metadata.id);
  void _cancelTransfer(BuildContext context) =>
      context.read<FileTransferProvider>().cancelFileTransfer(metadata.id);
  void _requestDownload(BuildContext context) =>
      context.read<FileTransferProvider>().requestDownload(metadata.id);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileTransferProvider>();
    final status = provider.fileStatuses[metadata.id] ?? metadata.status;
    final progress = (isSent
            ? provider.uploadProgress[metadata.id]
            : provider.downloadProgress[metadata.id]) ??
        0.0;
    final isActive = status == FileStatus.transferring;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFileIcon(metadata.fileName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Helpers.formatFileSize(metadata.fileSize)} • ${DateFormat.yMd().format(metadata.timestamp)}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ---- CẬP NHẬT NÚT BẤM ----
                if (!isSent && status == FileStatus.completed)
                  TextButton(
                      onPressed: () => _openFile(context),
                      child: Text(FileService.isVideoFile(metadata.fileName)
                          ? 'PLAY'
                          : 'OPEN')),
                if (!isSent &&
                    (status == FileStatus.pending ||
                        status == FileStatus.failed))
                  TextButton(
                      onPressed: () => _requestDownload(context),
                      child: Text(
                          status == FileStatus.failed ? 'RETRY' : 'DOWNLOAD')),
                if (isActive)
                  TextButton(
                      onPressed: () => _cancelTransfer(context),
                      child: const Text('CANCEL')),
                TextButton(
                  onPressed: () => _deleteFile(context),
                  child: const Text('DELETE'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(String fileName) {
    final IconData icon;
    final Color color;

    if (FileService.isImageFile(fileName)) {
      icon = Icons.image;
      color = Colors.green;
    } else if (FileService.isVideoFile(fileName)) {
      icon = Icons.videocam;
      color = Colors.red;
    } else if (FileService.isAudioFile(fileName)) {
      icon = Icons.audiotrack;
      color = Colors.purple;
    } else if (FileService.isPdfFile(fileName)) {
      icon = Icons.picture_as_pdf;
      color = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.blue;
    }

    return Icon(icon, color: color, size: 36);
  }

  Widget _buildStatusChip(FileStatus status) {
    final String text;
    final Color color;
    switch (status) {
      case FileStatus.pending:
        text = 'Pending';
        color = Colors.orange;
        break;
      case FileStatus.transferring:
        text = 'In Progress';
        color = Colors.blue;
        break;
      case FileStatus.completed:
        text = 'Completed';
        color = Colors.green;
        break;
      case FileStatus.failed:
        text = 'Failed';
        color = Colors.red;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
