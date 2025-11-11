// lib/screens/tabs/group_comments_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/comment.dart';
import '../../models/file_transfer.dart';
import '../../providers/comment_provider.dart';
import '../../services/db_service.dart';
import '../file_comment_screen.dart'; // Import để có thể nhấn vào xem

// ---- SỬA: Chuyển thành StatefulWidget ----
class GroupCommentsTab extends StatefulWidget {
  final int groupId;
  const GroupCommentsTab({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupCommentsTab> createState() => _GroupCommentsTabState();
}

class _GroupCommentsTabState extends State<GroupCommentsTab> {
  // ---- THÊM: State để quản lý việc tải dữ liệu ----
  late Future<List<Comment>> _commentsFuture;
  final Map<String, FileMetadata> _fileMetadataMap = {};

  @override
  void initState() {
    super.initState();
    _commentsFuture = _loadCommentsAndFiles();
  }

  // ---- THÊM: Hàm tải tất cả bình luận của nhóm ----
  Future<List<Comment>> _loadCommentsAndFiles() async {
    // 1. Lấy tất cả tệp trong nhóm
    final files = await DBService.getFilesForGroup(widget.groupId);

    // 2. Tạo một Map để tra cứu tên tệp từ fileId
    _fileMetadataMap.clear();
    for (var f in files) {
      _fileMetadataMap[f.id] = f;
    }

    // 3. Lấy provider
    final commentProvider = context.read<CommentProvider>();

    // 4. Lấy tất cả bình luận cho từng tệp
    List<Comment> allComments = [];
    for (var file in files) {
      // Tải bình luận (đảm bảo chúng có trong provider)
      await commentProvider.loadCommentsForFile(file.id);
      // Lấy bình luận từ provider
      final comments = commentProvider.getCommentsForFile(file.id);
      allComments.addAll(comments);
    }

    // 5. Sắp xếp tất cả bình luận (mới nhất lên đầu)
    allComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return allComments;
  }

  // ---- THÊM: Hàm helper định dạng thời gian ----
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} phút trước";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} giờ trước";
    } else {
      return DateFormat.yMd().format(timestamp); // "25/10/2025"
    }
  }

  // ---- THÊM: Hàm điều hướng ----
  void _navigateToComment(Comment comment) {
    final file = _fileMetadataMap[comment.fileId];
    if (file != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => FileCommentScreen(
          file: file,
          groupId: widget.groupId,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dùng ListView vì danh sách bình luận có thể dài
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      children: [
        _buildFilterChips(),
        const SizedBox(height: 10),

        // ---- SỬA: Dùng FutureBuilder để hiển thị dữ liệu động ----
        FutureBuilder<List<Comment>>(
          future: _commentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                  child: Text("Lỗi tải bình luận: ${snapshot.error}"));
            }

            final comments = snapshot.data;
            if (comments == null || comments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Chưa có bình luận nào trong nhóm."),
                ),
              );
            }

            // Nếu có dữ liệu, hiển thị tiêu đề và danh sách
            return Column(
              children: [
                _buildSectionTitle(
                    title: "Chuỗi bình luận", count: comments.length),
                const SizedBox(height: 10),
                ...comments.map((comment) {
                  // Tra cứu tên tệp
                  final fileName = _fileMetadataMap[comment.fileId]?.fileName ??
                      "Tệp không rõ";

                  return _buildCommentThread(
                    comment: comment, // <-- Truyền cả object
                    imageUrl:
                        "https://i.pravatar.cc/150?u=${comment.senderUsername}", // Avatar demo
                    name: comment.senderUsername,
                    time: _formatTimestamp(comment.timestamp),
                    fileName: fileName,
                    message: comment.content,
                  );
                }).toList(),
              ],
            );
          },
        ),
        // ----------------------------------------------------

        const SizedBox(height: 10),
        // (Ô soạn thảo bên dưới vẫn là demo, vì logic "bình luận chung"
        // chưa rõ ràng bằng "bình luận vào 1 tệp cụ thể")
        // _buildComposer(context),
      ],
    );
  }

  // (Hàm _buildFilterChips và _buildChip giữ nguyên)
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        children: [
          _buildChip("Tất cả", isActive: true),
          _buildChip("@ Nhắc đến", isActive: false),
          _buildChip("Bình luận của tôi", isActive: false),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.greenLight : const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isActive
                ? AppColors.greenLightBorder
                : const Color(0xFFDFEEE7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.greenText,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  // (Hàm _buildSectionTitle giữ nguyên)
  Widget _buildSectionTitle({required String title, required int count}) {
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

  // ---- SỬA: Hàm này để nhận Comment object ----
  Widget _buildCommentThread({
    required Comment comment,
    required String imageUrl,
    required String name,
    required String time,
    required String fileName,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Image.network(
              imageUrl,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              // <-- Bọc trong InkWell
              onTap: () => _navigateToComment(comment), // <-- Thêm hành động
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FCFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7F2EE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: AppColors.greenText,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text("· $time",
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: AppColors.greenLightBorder),
                          ),
                          child: Text(
                            fileName,
                            style: const TextStyle(
                                color: AppColors.greenText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(message,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildCommentAction(
                            icon: Icons.reply,
                            label: "Xem chi tiết"), // Đổi chữ
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (Hàm _buildCommentAction giữ nguyên)
  Widget _buildCommentAction({required IconData icon, required String label}) {
    return InkWell(
      onTap: null, // Tắt nhấn ở đây, vì đã bọc cả bubble
      child: Row(
        children: [
          Icon(icon, color: AppColors.greenText.withOpacity(0.9), size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.greenText,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // (Hàm _buildComposer đã bị ẩn đi, bạn có thể xóa nó hoặc giữ lại nếu muốn phát triển sau)
}
