// demo/lib/screens/main_layout.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:demo/config/app_colors.dart';
import 'package:demo/providers/navigation_provider.dart'; // Giữ lại
import 'package:demo/screens/tabs/home_tab.dart'; // Giữ lại
import 'package:demo/screens/tabs/friends_tab.dart'; // Đã sửa
import 'package:demo/screens/tabs/groups_tab.dart'; // Giữ lại
import 'package:demo/screens/tabs/profile_tab.dart'; // Đã sửa
import 'package:demo/screens/file_manager_screen.dart'; // Giữ lại
import 'package:demo/screens/upload_file_screen.dart'; // Giữ lại

// --- CÁC IMPORT MỚI ---
import 'package:demo/services/identity_service.dart';
import 'package:demo/services/websocket_service.dart';
// --- KẾT THÚC IMPORT MỚI ---

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late PageController _pageController;
  int _currentIndex = 0;

  // Danh sách các tab
  final List<Widget> _tabs = [
    const HomeTab(),
    const FriendsTab(), // Tab này đã được sửa
    const GroupsTab(),
    const ProfileTab(), // Tab này đã được sửa
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // --- CODE MỚI: KẾT NỐI ĐẾN SIGNALING SERVER ---
    // Chúng ta dùng addPostFrameCallback để đảm bảo context đã sẵn sàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final identityService = context.read<IdentityService>();
      final wsService = context.read<WebSocketService>();

      // Chỉ kết nối khi đã có định danh và chưa kết nối
      if (identityService.myPeerId != null && !wsService.isConnected) {
        // ⚠️ THAY 'YOUR_IP' BẰNG ĐỊA CHỈ IP MẠNG LAN CỦA MÁY CHẠY SERVER
        // Ví dụ: 'ws://192.168.1.10:8080'
        const signalingUrl = 'ws://YOUR_IP:8080';

        print('Đang kết nối đến Signaling Server tại $signalingUrl');
        wsService.connect(
          signalingUrl,
          identityService.myPeerId!,
        );
      }
    });
    // --- KẾT THÚC CODE MỚI ---
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Tùy chọn: ngắt kết nối WebSocket khi layout bị hủy
    // context.read<WebSocketService>().disconnect();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.background,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textFaded,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Bạn bè',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_work),
            label: 'Nhóm',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadFileScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }
}
