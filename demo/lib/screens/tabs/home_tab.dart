// demo/lib/screens/tabs/home_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart';
import 'package:demo/services/identity_service.dart';
import 'package:demo/providers/group_provider.dart';
import 'package:demo/screens/chat_screen_p2p.dart';
// import 'package:demo/screens/group_chat_screen.dart'; // Bạn sẽ cần tạo file này
import 'package:demo/config/app_colors.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu từ các provider P2P
    final p2pService = context.watch<P2PService>();
    final groupProvider = context.watch<GroupProvider>();
    final myPeerId = context.watch<IdentityService>().myPeerId;

    // Lấy danh sách P2P chats (là các key trong chatHistory)
    final p2pChats = p2pService.chatHistory.keys.toList();

    // Lấy danh sách group chats
    final groupChats = groupProvider.groups;

    // (Logic để gộp và sắp xếp 2 danh sách này sẽ phức tạp,
    // hiện tại chúng ta chỉ hiển thị 2 danh sách nối tiếp nhau)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đoạn chat P2P'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // --- Danh sách Chat 1-1 (P2P) ---
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final peerId = p2pChats[index];
                final lastMessage =
                    (p2pService.chatHistory[peerId] ?? []).isNotEmpty
                        ? (p2pService.chatHistory[peerId]!).last
                        : null;

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryFaded,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(
                    'Peer: ${peerId.substring(26, 40)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    lastMessage != null
                        ? (lastMessage.senderId == myPeerId ? 'Bạn: ' : '') +
                            lastMessage.text
                        : 'Bắt đầu trò chuyện',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreenP2P(peerId: peerId),
                      ),
                    );
                  },
                );
              },
              childCount: p2pChats.length,
            ),
          ),

          // --- Dải phân cách (ví dụ) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'NHÓM',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // --- Danh sách Chat Nhóm ---
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final group = groupChats[index];
                // TODO: Lấy tin nhắn cuối cùng từ GroupProvider
                // final lastMessage = groupProvider.getMessages(group.id).lastOrNull;

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
                    group.description ?? 'Chưa có tin nhắn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    // TODO: Mở màn hình chat nhóm (bạn cần tạo file này)
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => GroupChatScreen(groupId: group.id),
                    //   ),
                    // );
                  },
                );
              },
              childCount: groupChats.length,
            ),
          ),
        ],
      ),
    );
  }
}
