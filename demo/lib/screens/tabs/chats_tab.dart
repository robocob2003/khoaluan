// demo/lib/screens/tabs/chats_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart';
import 'package:demo/services/identity_service.dart';
import 'package:demo/screens/chat_screen_p2p.dart';
import 'package:demo/config/app_colors.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu từ các provider P2P
    final p2pService = context.watch<P2PService>();
    final myPeerId = context.watch<IdentityService>().myPeerId;

    // Lấy danh sách P2P chats (là các key trong chatHistory)
    final p2pChats = (p2pService.chatHistory ?? {}).keys.toList();

    if (p2pChats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Chưa có cuộc trò chuyện 1-1 nào. Hãy qua tab "Bạn bè" để kết nối với peer mới.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: p2pChats.length,
      itemBuilder: (context, index) {
        final peerId = p2pChats[index];
        final chatMessages = p2pService.chatHistory[peerId] ?? [];
        final lastMessage = chatMessages.isNotEmpty ? chatMessages.last : null;

        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppColors.primaryFaded,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          title: Text(
            'Peer: ${peerId.substring(26, 40)}...', // Tên tạm
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
    );
  }
}
