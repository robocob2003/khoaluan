// demo/lib/screens/tabs/group_comments_tab.dart
import 'package:flutter/material.dart';
import 'package:demo/config/app_colors.dart';

class GroupCommentsTab extends StatelessWidget {
  final String groupId; // Nhận groupId (String) từ GroupDetailScreen

  const GroupCommentsTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    // File này là một placeholder trong dự án gốc.
    // Logic bình luận được xử lý theo từng file (trong group_files_tab)
    // chứ không phải theo toàn bộ nhóm.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Tính năng bình luận theo nhóm chưa được hỗ trợ. Bạn có thể bình luận trên từng file cụ thể trong tab "Files".',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      ),
    );
  }
}
