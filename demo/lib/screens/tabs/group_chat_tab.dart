// demo/lib/screens/tabs/groups_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/providers/group_provider.dart';
import 'package:demo/config/app_colors.dart';
// import 'package:demo/screens/create_or_join_group_screen.dart'; // File này cũng cần refactor
// import 'package:demo/screens/group_chat_screen.dart'; // File này bạn cần tạo/refactor

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy GroupProvider (đã được refactor)
    final groupProvider = context.watch<GroupProvider>();
    final groups = groupProvider.groups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhóm P2P'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            tooltip: 'Tạo nhóm mới',
            onPressed: () {
              // TODO: Mở màn hình tạo nhóm (đã được refactor)
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(builder: (context) => const CreateOrJoinGroupScreen()),
              // );
            },
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Bạn chưa tham gia nhóm P2P nào. Hãy tạo một nhóm mới.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryFaded,
                    child: Icon(Icons.group, color: AppColors.primary),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    group.description ?? 'ID: ${group.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    // TODO: Mở màn hình chat nhóm
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => GroupChatScreen(groupId: group.id),
                    //   ),
                    // );
                  },
                );
              },
            ),
    );
  }
}
