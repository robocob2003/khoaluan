// lib/screens/tabs/home_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/websocket_provider.dart';
import '../group_detail_screen.dart';
// ---- THÊM IMPORT MỚI ----
import '../../providers/navigation_provider.dart';
import '../create_or_join_group_screen.dart'; // Để mở "Nhóm của tôi"
// -------------------------

class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  String _formatTimestamp(DateTime timestamp) {
    // (Giữ nguyên)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (date == today) {
      return DateFormat.Hm().format(timestamp); // "14:30"
    } else if (date == yesterday) {
      return "Hôm qua";
    } else {
      return DateFormat.yMd().format(timestamp); // "25/10/2025"
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final wsProvider = context.watch<WebSocketProvider>();
    // (Logic lấy data giữ nguyên)
    final activeGroups = groupProvider.groups.take(2).toList();
    final List<Message> privateMessages = wsProvider.messages;
    final List<Message> groupMessages = [];
    for (var group in groupProvider.groups) {
      groupMessages.addAll(groupProvider.getMessagesForGroup(group.id));
    }
    final List<Message> allActivities = [...privateMessages, ...groupMessages];
    allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentActivities = allActivities.take(5).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF2FBF6), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment(0.0, 0.75),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearch(),
              const SizedBox(height: 12),
              // ---- SỬA: TRUYỀN CONTEXT ----
              _buildQuickGrid(context),
              // ----------------------------
              const SizedBox(height: 12),
              _buildSectionTitle(
                  title: "Nhóm đang hoạt động", count: activeGroups.length),
              _buildActiveGroups(context, activeGroups),
              const SizedBox(height: 14),
              _buildSectionTitle(
                  title: "Hoạt động gần đây", count: recentActivities.length),
              _buildActivityList(
                  context, recentActivities, authProvider, groupProvider),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    // (Giữ nguyên)
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 12.0,
      title: Row(
        children: [
          Icon(Icons.circle_outlined,
              color: AppColors.greenText), // Placeholder
          const SizedBox(width: 8),
          const Text(
            "Linkshare",
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              // ---- SỬA: ĐIỀU HƯỚNG TỚI TAB NHÓM ----
              context.read<NavigationProvider>().changeTab(1);
              // ------------------------------------
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Nhóm mới"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 12.0),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.greenLightBorder),
              ),
              child: const Icon(Icons.more_horiz,
                  color: AppColors.greenText, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    // (Giữ nguyên)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.greenText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Tìm tệp, nhóm, thành viên…",
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          const Icon(Icons.sort, color: AppColors.greenText, size: 20),
        ],
      ),
    );
  }

  // "Dịch" từ class="qgrid"
  // ---- HÀM ĐÃ SỬA ----
  Widget _buildQuickGrid(BuildContext context) {
    // Lấy provider (listen: false vì đang ở trong hàm)
    final navProvider = context.read<NavigationProvider>();

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildQuickItem(
            icon: Icons.upload,
            label: "Tải lên",
            onTap: () {
              // Mở màn hình Tạo nhóm (nơi có thể tạo nhóm rồi tải lên)
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const CreateOrJoinGroupScreen(),
              ));
            }),
        _buildQuickItem(
            icon: Icons.folder_open,
            label: "Nhóm của tôi",
            onTap: () => navProvider.changeTab(1) // Chuyển đến Tab 1 (Nhóm)
            ),
        _buildQuickItem(
            icon: Icons.chat_bubble,
            label: "Trò chuyện",
            onTap: () => navProvider.changeTab(2) // Chuyển đến Tab 2 (Chat)
            ),
        _buildQuickItem(
            icon: Icons.person,
            label: "Hồ sơ",
            onTap: () => navProvider.changeTab(3) // Chuyển đến Tab 3 (Hồ sơ)
            ),
      ],
    );
  }
  // --------------------

  // "Dịch" từ class="qitem"
  // ---- HÀM ĐÃ SỬA ----
  Widget _buildQuickItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap, // Thêm hành động
  }) {
    return InkWell(
      // Bọc trong InkWell
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greenLightBorder),
              ),
              child: Icon(icon, color: AppColors.greenText, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --------------------

  // (Các hàm còn lại: _buildSectionTitle, _buildActiveGroups, _buildGroupCard,
  // _buildChip, _buildActivityList, _buildActivityItem giữ nguyên y hệt
  // như file tôi gửi bạn ở Bước (làm trang chủ) trước đó)

  Widget _buildSectionTitle({required String title, required int count}) {
    // ... (Giữ nguyên)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Spacer(),
          Text(
            "$count",
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGroups(BuildContext context, List<Group> groups) {
    // ... (Giữ nguyên)
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          "Chưa có nhóm nào. \nHãy tạo nhóm đầu tiên của bạn!",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: groups.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(context, group);
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, Group group) {
    // ... (Giữ nguyên)
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(group: group),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(group.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const Spacer(),
            Text("${group.members.length} thành viên",
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildChip("Tệp", icon: Icons.description),
                const SizedBox(width: 8),
                _buildChip("Chat", icon: Icons.chat_bubble),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {required IconData icon}) {
    // ... (Giữ nguyên)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.greenText, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.greenText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActivityList(
    BuildContext context,
    List<Message> activities,
    AuthProvider authProvider,
    GroupProvider groupProvider,
  ) {
    // ... (Giữ nguyên)
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          "Chưa có hoạt động nào.",
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      itemCount: activities.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final message = activities[index];

        IconData icon = Icons.comment;
        String title = message.content;
        String subtitle = "";
        String time = _formatTimestamp(message.timestamp);
        bool isNew =
            DateTime.now().difference(message.timestamp).inMinutes < 15;

        if (message.type == MessageType.file) {
          icon = Icons.description;
          title = message.fileName ?? "Tệp tin";
        }

        if (message.groupId != null) {
          final group = groupProvider.groups.firstWhere(
              (g) => g.id == message.groupId,
              orElse: () => Group(
                  id: 0, name: "Nhóm", ownerId: 0, createdAt: DateTime.now()));
          subtitle = "${message.senderUsername} đã gửi trong ${group.name}";
        } else {
          subtitle = "Tin nhắn từ ${message.senderUsername}";
        }

        return _buildActivityItem(
          icon: icon,
          title: title,
          subtitle: subtitle,
          isNew: isNew,
          time: time,
        );
      },
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isNew = false,
    String? time,
  }) {
    // ... (Giữ nguyên)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.greenLightBorder),
            ),
            child: Icon(icon, color: AppColors.greenText, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text("Mới",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            )
          else if (time != null)
            Text(
              time,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
