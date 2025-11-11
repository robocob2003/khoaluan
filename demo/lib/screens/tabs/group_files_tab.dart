// demo/lib/screens/tabs/group_files_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/models/file_transfer.dart';
import 'package:demo/services/db_service.dart';
import 'package:demo/providers/file_transfer_provider.dart';
import 'package:demo/config/app_colors.dart';
import 'package:demo/utils/helpers.dart'; // Giả sử bạn có file này để format bytes

class GroupFilesTab extends StatelessWidget {
  final String groupId; // Nhận groupId (String) từ GroupDetailScreen

  const GroupFilesTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final fileProvider = Provider.of<FileTransferProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<List<FileMetadata>>(
        // Chúng ta gọi DBService trực tiếp (hoặc lý tưởng nhất là thêm hàm này vào FileTransferProvider)
        future: DBService.getFilesForGroup(groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải file: ${snapshot.error}'));
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(
              child: Text(
                'Chưa có file nào trong nhóm này.',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final status = fileProvider.fileStatuses[file.id] ?? file.status;

              return ListTile(
                leading: const Icon(Icons.insert_drive_file,
                    color: AppColors.primary, size: 40),
                title: Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${formatBytes(file.fileSize)} - ${status.toString()}',
                  style: TextStyle(
                    color: status == FileStatus.completed
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: status == FileStatus.completed
                      ? () => fileProvider.openFile(file.id)
                      : () {
                          // TODO: Cần logic P2P để tải file nhóm
                          // fileProvider.requestGroupFileDownload(file.id);
                          print("P2P: Yêu cầu tải file nhóm (chưa implement)");
                        },
                ),
                onTap: () {
                  // TODO: Mở màn hình chi tiết file / bình luận file
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => FileCommentScreen(fileMetadata: file),
                  //   ),
                  // );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Mở màn hình chọn file và gửi
          // Cần gọi fileProvider.sendFileToGroup(filePath: ..., groupId: groupId);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }
}
