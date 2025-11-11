// lib/screens/main_layout.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/websocket_provider.dart';
import '../config/app_colors.dart';
import '../services/db_service.dart';
import '../providers/navigation_provider.dart';

// Import các tab
import 'tabs/home_tab.dart';
import 'tabs/groups_tab.dart';
import 'tabs/chats_tab.dart';
// ---- THÊM IMPORT MỚI ----
import 'tabs/friends_tab.dart';
// -------------------------
import 'tabs/profile_tab.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConnection();
      _loadAllMessages();
    });
  }

  void _initializeConnection() async {
    // (Giữ nguyên)
    final authProvider = context.read<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    if (authProvider.user != null && !wsProvider.isConnected) {
      print("MainLayout: Connecting to WebSocket...");
      await wsProvider.connect(authProvider.user!);
    }
  }

  Future<void> _loadAllMessages() async {
    // (Giữ nguyên)
    print("MainLayout: Loading all messages from DB...");
    try {
      final messages = await DBService.getRecentMessages(500);
      if (mounted) {
        context.read<WebSocketProvider>().loadMessages(messages);
        print("MainLayout: Loaded ${messages.length} messages into providers.");
      }
    } catch (e) {
      print('Error loading all messages in MainLayout: $e');
    }
  }

  // ---- SỬA: Thêm FriendsTab vào danh sách ----
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const GroupsTab(),
    const ChatsTab(),
    const FriendsTab(), // <-- THÊM MỚI
    const ProfileTab(),
  ];
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Lắng nghe provider
    final navProvider = context.watch<NavigationProvider>();
    final int currentIndex = navProvider.currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex, // <-- Dùng index từ provider
        children: _widgetOptions,
      ),
      bottomNavigationBar:
          _buildBottomNavBar(navProvider, currentIndex), // <-- Truyền vào
    );
  }

  // ---- SỬA: Thêm BottomNavigationBarItem mới ----
  Widget _buildBottomNavBar(NavigationProvider navProvider, int currentIndex) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE1EFE9), width: 1.0),
        ),
      ),
      child: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          _buildNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Trang chủ',
            index: 0,
            currentIndex: currentIndex,
          ),
          _buildNavItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder,
            label: 'Nhóm',
            index: 1,
            currentIndex: currentIndex,
          ),
          _buildNavItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            label: 'Trò chuyện',
            index: 2,
            currentIndex: currentIndex,
          ),
          // ---- THÊM MỤC MỚI ----
          _buildNavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: 'Bạn bè',
            index: 3,
            currentIndex: currentIndex,
          ),
          // -----------------------
          _buildNavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Hồ sơ',
            index: 4, // <-- SỬA INDEX THÀNH 4
            currentIndex: currentIndex,
          ),
        ],
        currentIndex: currentIndex,
        onTap: (index) => navProvider.changeTab(index), // <-- Gọi provider
        backgroundColor: AppColors.greenLight,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.greenText,
      ),
    );
  }
  // ---------------------------------------------

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
  }) {
    bool isActive = currentIndex == index;

    Widget iconWidget = Container(
      width: 44,
      height: 36,
      decoration: BoxDecoration(
        gradient: isActive ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Icon(
        isActive ? activeIcon : icon,
        color: isActive ? Colors.white : AppColors.greenText,
        size: 22,
      ),
    );

    return BottomNavigationBarItem(
      icon: iconWidget,
      label: label,
    );
  }
}
