// demo/lib/screens/tabs/friends_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart'; // THÊM
import 'package:demo/screens/scan_qr_screen.dart'; // THÊM
import 'package:demo/screens/chat_screen_p2p.dart'; // THÊM (Sẽ tạo ở bước 7)

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách các cuộc hội thoại đã bắt đầu
    final p2pService = context.watch<P2PService>();
    final connectedPeerIds = p2pService.chatHistory.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè & Peers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Quét Peer mới',
            onPressed: () async {
              // Mở màn hình quét QR
              final targetPeerId = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const ScanQRScreen()),
              );

              if (targetPeerId != null && targetPeerId.isNotEmpty) {
                // Bắt đầu kết nối
                await context.read<P2PService>().connectToPeer(targetPeerId);

                // Mở màn hình chat
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreenP2P(peerId: targetPeerId),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: connectedPeerIds.length,
        itemBuilder: (context, index) {
          final peerId = connectedPeerIds[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('Peer: ${peerId.substring(0, 15)}...'),
            subtitle: const Text('Đã kết nối'),
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
      ),
    );
  }
}
