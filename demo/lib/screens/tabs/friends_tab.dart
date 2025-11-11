// demo/lib/screens/tabs/friends_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart';
import 'package:demo/screens/scan_qr_screen.dart'; // Màn hình này bạn đã tạo
import 'package:demo/screens/chat_screen_p2p.dart'; // Màn hình này bạn đã tạo
import 'package:demo/config/app_colors.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // <--- Đảm bảo đã import

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách các cuộc hội thoại 1-1 đã bắt đầu
    final p2pService = context.watch<P2PService>();
    final connectedPeerIds = (p2pService.chatHistory ?? {}).keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè & Peers'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Quét Peer mới',
            onPressed: () async {
              // Mở màn hình quét QR
              final targetPeerId = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const ScanQRScreen()),
              );

              if (targetPeerId != null && targetPeerId.isNotEmpty) {
                // Bắt đầu kết nối P2P
                await context.read<P2PService>().connectToPeer(targetPeerId);
                
                // Mở màn hình chat ngay lập tức
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
      body: connectedPeerIds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Chưa có bạn bè P2P nào. Hãy nhấn nút 📷 để quét mã QR và kết nối.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              itemCount: connectedPeerIds.length,
              itemBuilder: (context, index) {
                final peerId = connectedPeerIds[index];
                
                // --- 💡 SỬA LỖI Ở ĐÂY ---
                // Đổi `DataChannelOpen` (viết hoa) thành `dataChannelOpen` (viết thường)
                bool isConnected = (p2pService.dataChannels ?? {}).containsKey(peerId) &&
                                   p2pService.dataChannels[peerId]?.state == RTCDataChannelState.dataChannelOpen;
                // --- KẾT THÚC SỬA ---

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
                    isConnected ? 'Đã kết nối P2P' : 'Đang chờ...',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
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
            ),
    );
  }
}// demo/lib/screens/tabs/friends_tab.dart
import 'package.flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart';
import 'package:demo/screens/scan_qr_screen.dart'; // Màn hình này bạn đã tạo
import 'package:demo/screens/chat_screen_p2p.dart'; // Màn hình này bạn đã tạo
import 'package:demo/config/app_colors.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'; // <--- Đảm bảo đã import

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách các cuộc hội thoại 1-1 đã bắt đầu
    final p2pService = context.watch<P2PService>();
    final connectedPeerIds = (p2pService.chatHistory ?? {}).keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè & Peers'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Quét Peer mới',
            onPressed: () async {
              // Mở màn hình quét QR
              final targetPeerId = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (context) => const ScanQRScreen()),
              );

              if (targetPeerId != null && targetPeerId.isNotEmpty) {
                // Bắt đầu kết nối P2P
                await context.read<P2PService>().connectToPeer(targetPeerId);
                
                // Mở màn hình chat ngay lập tức
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
      body: connectedPeerIds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Chưa có bạn bè P2P nào. Hãy nhấn nút 📷 để quét mã QR và kết nối.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              itemCount: connectedPeerIds.length,
              itemBuilder: (context, index) {
                final peerId = connectedPeerIds[index];
                
                // --- 💡 SỬA LỖI Ở ĐÂY ---
                // Đổi `DataChannelOpen` (viết hoa) thành `dataChannelOpen` (viết thường)
                bool isConnected = (p2pService.dataChannels ?? {}).containsKey(peerId) &&
                                   p2pService.dataChannels[peerId]?.state == RTCDataChannelState.dataChannelOpen;
                // --- KẾT THÚC SỬA ---

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
                    isConnected ? 'Đã kết nối P2P' : 'Đang chờ...',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
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
            ),
    );
  }
}