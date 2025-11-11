// lib/screens/tabs/profile_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/websocket_provider.dart';
import '../../models/user.dart';
import '../edit_profile_screen.dart'; // <-- ĐÃ THÊM

class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  void _handleLogout(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    wsProvider.disconnect();
    await authProvider.logout();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

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
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          children: [
            _buildProfileCard(context, user), // <-- Truyền context
            _buildDidCard(),
            _buildSectionTitle("Tài khoản"),
            _buildLinkRow(
                icon: Icons.person,
                title: "Thông tin hồ sơ",
                subtitle: "Tên, ảnh đại diện"),
            _buildLinkRow(
                icon: Icons.notifications,
                title: "Thông báo",
                subtitle: "Nhắc việc, hoạt động nhóm"),
            _buildLinkRow(
                icon: Icons.security,
                title: "Bảo mật",
                subtitle: "Đăng nhập, thiết bị"),
            _buildLinkRow(
                icon: Icons.privacy_tip,
                title: "Quyền riêng tư",
                subtitle: "Chia sẻ, hiển thị"),
            const SizedBox(height: 10),
            _buildSectionTitle("Dữ liệu & bộ nhớ"),
            _buildLinkRow(
                icon: Icons.storage,
                title: "Bộ nhớ",
                subtitle: "Đã dùng 2.4 GB · Xóa cache"),
            _buildLinkRow(
                icon: Icons.download_for_offline,
                title: "Tải xuống",
                subtitle: "Vị trí & lịch sử"),
            const SizedBox(height: 10),
            _buildSectionTitle("Hỗ trợ"),
            _buildLinkRow(
                icon: Icons.help_center,
                title: "Trung tâm trợ giúp",
                subtitle: "Bài viết & FAQs"),
            _buildLinkRow(
                icon: Icons.send,
                title: "Liên hệ hỗ trợ",
                subtitle: "Gửi phản hồi"),
            InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(14),
              child: _buildLinkRow(
                icon: Icons.logout,
                title: "Đăng xuất",
                subtitle: "Ngắt kết nối thiết bị",
                isDanger: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12.0,
      title: const Text(
        "Hồ sơ",
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
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

  Widget _buildProfileCard(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9EFE6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Image.network(
                  "https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=240",
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.username ?? "Đang tải...",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(user?.email ?? "...",
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSmallButton(
                  label: "Chia sẻ ID",
                  icon: Icons.add,
                  isSoft: true,
                  onPressed: () {}, // (Vẫn là demo)
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSmallButton(
                  label: "Chỉnh sửa",
                  icon: Icons.edit,
                  isSoft: false,
                  onPressed: () {
                    // <-- HÀNH ĐỘNG ĐÃ THÊM
                    if (user != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => EditProfileScreen(user: user),
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem("12", "Nhóm"),
              _buildStatItem("34", "Tệp"),
              _buildStatItem("7", "Được ghim"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(
      {required String label,
      required IconData icon,
      required VoidCallback onPressed, // <-- ĐÃ THÊM
      bool isSoft = true}) {
    return TextButton.icon(
      onPressed: onPressed, // <-- ĐÃ GẮN
      icon:
          Icon(icon, size: 18, color: isSoft ? AppColors.text : AppColors.text),
      label: Text(label,
          style: TextStyle(
              color: isSoft ? AppColors.text : AppColors.text,
              fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        backgroundColor: isSoft ? AppColors.greenLight : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
              color: isSoft ? AppColors.greenLightBorder : AppColors.line),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDidCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9FBF1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7F0DC), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.greenLightBorder),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppColors.greenText, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Danh tính phi tập trung",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "Khóa công khai đang hoạt động • Nhấn để quản lý khóa",
                  style: TextStyle(color: Color(0xFF065F46), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  Widget _buildLinkRow({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDanger = false,
  }) {
    Color iconColor = isDanger ? const Color(0xFFB91C1C) : AppColors.greenText;
    Color iconBg = isDanger ? const Color(0xFFFEE2E2) : AppColors.greenLight;
    Color iconBorder =
        isDanger ? const Color(0xFFFECACA) : AppColors.greenLightBorder;
    Color titleColor = isDanger ? const Color(0xFFB91C1C) : AppColors.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDanger ? const Color(0xFFFFF7F7) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDanger ? const Color(0xFFFECACA) : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorder),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: titleColor)),
                Text(subtitle,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: iconColor, size: 22),
        ],
      ),
    );
  }
}
