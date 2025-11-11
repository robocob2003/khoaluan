// lib/screens/tabs/group_files_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/file_transfer.dart';
import '../../services/db_service.dart';
import '../../utils/helpers.dart';
import '../../providers/file_transfer_provider.dart';
import '../file_comment_screen.dart';

class GroupFilesTab extends StatefulWidget {
  final int groupId;
  const GroupFilesTab({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupFilesTab> createState() => _GroupFilesTabState();
}

class _GroupFilesTabState extends State<GroupFilesTab> {
  // ---- SỬA: DÙNG KIỂU MỚI ----
  // Giờ chúng ta cần tải FileMetadata VÀ tags của nó
  late Future<List<FileMetadata>> _filesFuture;
  // -------------------------

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  // ---- CẬP NHẬT HÀM NÀY ----
  void _fetchFiles() {
    final fileProvider = context.read<FileTransferProvider>();

    // Tạo một future mới để tải file và tags
    _filesFuture = () async {
      // 1. Lấy metadata
      final files = await DBService.getFilesForGroup(widget.groupId);

      // 2. Lấy tags cho từng file
      List<FileMetadata> filesWithTags = [];
      for (var file in files) {
        final tags = await DBService.getTagsForFile(file.id);
        // 3. Cập nhật state trong provider (để UI khác cũng thấy)
        fileProvider.handleIncomingFileTags(file.id, tags);
        // 4. Tạo bản copy của file với tags đã được thêm
        filesWithTags.add(file.copyWith(tags: tags));
      }
      return filesWithTags;
    }(); // Chạy future

    if (mounted) {
      setState(() {});
    }
  }
  // -------------------------

  void _downloadFile(BuildContext context, String fileId) {
    context.read<FileTransferProvider>().requestDownload(fileId);
  }

  void _openFile(BuildContext context, String fileId) {
    context.read<FileTransferProvider>().openFile(fileId);
  }

  void _openComments(BuildContext context, FileMetadata file) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FileCommentScreen(
        file: file,
        groupId: widget.groupId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileTransferProvider>();

    return FutureBuilder<List<FileMetadata>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Lỗi tải tệp: ${snapshot.error}"));
        }
        final files = snapshot.data;
        if (files == null || files.isEmpty) {
          return const Center(child: Text("Chưa có tệp nào trong nhóm."));
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          children: [
            _buildSectionTitle(title: "Tệp đã chia sẻ", count: files.length),
            const SizedBox(height: 10),
            ...files.map((file) {
              final status = fileProvider.fileStatuses[file.id] ?? file.status;
              final progress = fileProvider.downloadProgress[file.id] ?? 0.0;
              // ---- LẤY TAGS THẬT TỪ OBJECT (hoặc provider) ----
              final tags = file.tags.isNotEmpty
                  ? file.tags
                  : fileProvider.getTagsForFile(file.id);
              // ---------------------------------

              return _buildFileCard(
                context: context,
                file: file,
                status: status,
                progress: progress,
                icon: Icons.description,
                title: file.fileName,
                subtitle: "Tải lên bởi User ${file.senderId}", // Demo
                tags: tags, // <-- DÙNG TAGS THẬT
                size: Helpers.formatFileSize(file.fileSize),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle({required String title, required int count}) {
    // (Giữ nguyên)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.greenText),
          ),
          const Spacer(),
          Text(
            "$count",
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard({
    required BuildContext context,
    required FileMetadata file,
    required FileStatus status,
    required double progress,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> tags,
    required String size,
  }) {
    bool isDownloading = status == FileStatus.transferring;
    bool isCompleted = status == FileStatus.completed;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // (Phần header của card giữ nguyên)
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.greenLightBorder),
                ),
                child: Icon(icon, color: AppColors.greenText, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.greenLightBorder),
                ),
                child: Text(
                  size,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenText),
                ),
              ),
            ],
          ),

          // ---- HIỂN THỊ TAGS THẬT ----
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 46.0, top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2FAF6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFDEF1EA)),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                                color: AppColors.greenText,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ))
                    .toList(),
              ),
            ),
          // --------------------------

          if (isDownloading)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor: Colors.grey.shade300,
              ),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openComments(context, file),
                  icon: const Icon(Icons.comment_outlined, size: 18),
                  label: const Text("Bình luận"),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.greenLight,
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.greenLightBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isDownloading
                      ? null
                      : () {
                          if (isCompleted) {
                            _openFile(context, file.id);
                          } else {
                            _downloadFile(context, file.id);
                          }
                        },
                  icon: Icon(isCompleted ? Icons.open_in_new : Icons.download,
                      size: 18),
                  label: Text(isCompleted ? "Mở tệp" : "Tải xuống"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
