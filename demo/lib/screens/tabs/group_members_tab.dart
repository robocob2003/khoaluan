// demo/lib/screens/tabs/group_members_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/providers/group_provider.dart';
import 'package:demo/config/app_colors.dart';
// import 'package:demo/screens/scan_qr_screen.dart'; // Cần để mời

class GroupMembersTab extends StatelessWidget {
  final String groupId; // Nhận groupId (String) từ GroupDetailScreen

  const GroupMembersTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();

    // Tải chi tiết thành viên nếu chưa có
    if (groupProvider.getMembers(groupId).isEmpty) {
      // Dùng addPostFrameCallback để tránh lỗi 'setState during build'
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Kiểm tra lại lần nữa để tránh gọi vô hạn
        if (groupProvider.getMembers(groupId).isEmpty) {
          context.read<GroupProvider>().loadGroupDetails(groupId);
        }
      });
    }

    final members = groupProvider.getMembers(groupId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: groupProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryFaded,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(
                    member.username.isNotEmpty
                        ? member.username
                        : 'Peer...${member.id.substring(member.id.length - 6)}',
                  ),
                  subtitle: Text(
                    member.role,
                    style: const TextStyle(color: Colors.green),
                  ),
                  trailing: member.role == 'admin'
                      ? const Icon(Icons.star, color: Colors.amber)
                      : null,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // TODO: Mở màn hình quét QR để lấy peerId
          // final peerId = await Navigator.push<String>(
          //   context,
          //   MaterialPageRoute(builder: (context) => const ScanQRScreen()),
          // );
          // if (peerId != null && context.mounted) {
          //   context.read<GroupProvider>().inviteUserToGroup(groupId, peerId);
          // }
          print("P2P: Mời thành viên (chưa implement)");
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
