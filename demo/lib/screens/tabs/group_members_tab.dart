// lib/screens/tabs/group_members_tab.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/group.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/websocket_provider.dart';

class GroupMembersTab extends StatefulWidget {
  final int groupId;
  const GroupMembersTab({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupMembersTab> createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab> {
  late Future<List<GroupMember>> _membersFuture;
  UserModel? _currentUser;
  GroupMember? _myMembership;
  List<GroupMember> _currentMembers = [];

  @override
  void initState() {
    super.initState();
    _currentUser = context.read<AuthProvider>().user;
    _fetchMembers();
  }

  void _fetchMembers() {
    // Buộc AuthProvider tải lại danh sách user TỔNG từ server
    context.read<AuthProvider>().refreshConnection();

    final provider = context.read<GroupProvider>();
    _membersFuture = provider.getGroupMembers(widget.groupId);

    _membersFuture.then((members) {
      if (mounted) {
        setState(() {
          _currentMembers = members;
          _myMembership = members.firstWhereOrNull(
            (m) => m.id == _currentUser?.id,
          );
        });
      }
    });
  }

  void _showInviteDialog(BuildContext context) {
    // (Hàm này giữ nguyên, không thay đổi)
    final authProvider = context.read<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();
    final group = context
        .read<GroupProvider>()
        .groups
        .firstWhereOrNull((g) => g.id == widget.groupId);

    if (group == null) return;

    final memberIds = _currentMembers.map((m) => m.id).toSet();
    final allUsers = authProvider.availableUsers
        .where((u) => !memberIds.contains(u.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mời thành viên mới",
                    style: Theme.of(context).textTheme.titleLarge),
                Text("Chọn người dùng để gửi lời mời 1-1:"),
                const SizedBox(height: 16),
                Expanded(
                  child: allUsers.isEmpty
                      ? Center(
                          child: Text("Không tìm thấy người dùng nào để mời."))
                      : ListView.builder(
                          itemCount: allUsers.length,
                          itemBuilder: (context, index) {
                            final user = allUsers[index];
                            return ListTile(
                              title: Text(user.username),
                              leading: Icon(Icons.person_add_outlined,
                                  color: AppColors.greenText),
                              onTap: () {
                                wsProvider.webSocketService
                                    .sendGroupInvite(group, user.username);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Đã gửi lời mời đến ${user.username}"),
                                  backgroundColor: AppColors.primary,
                                ));
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool iAmAdmin = _myMembership?.role == 'admin';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      children: [
        _buildFilterChips(),
        const SizedBox(height: 10),
        if (iAmAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ElevatedButton.icon(
              onPressed: () => _showInviteDialog(context),
              icon: Icon(Icons.person_add, size: 18),
              label: Text("Mời thành viên mới"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        FutureBuilder<List<GroupMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text("Lỗi tải thành viên: ${snapshot.error}"));
            }
            final members = snapshot.data;
            if (members == null || members.isEmpty) {
              return const Center(child: Text("Không có thành viên nào."));
            }

            return Column(
              children: [
                _buildSectionTitle(title: "Thành viên", count: members.length),
                const SizedBox(height: 10),
                ...members.map((member) {
                  bool isMe = member.id == _currentUser?.id;

                  return _buildMemberCard(
                    context: context,
                    member: member,
                    imageUrl: "https://i.pravatar.cc/150?u=${member.username}",
                    name: member.username + (isMe ? " (Bạn)" : ""),
                    subtitle: "Vai trò: ${member.role}",
                    isOwner: member.role == 'admin',
                    role: member.role,
                    // ---- SỬA LOGIC Ở ĐÂY ----
                    showAdminActions:
                        iAmAdmin && !isMe, // (Dành cho nút Gỡ/Sửa)
                    showChatAction: !isMe, // (Dành cho nút Nhắn)
                    // --------------------------
                  );
                }).toList(),
              ],
            );
          },
        ),
      ],
    );
  }

  // (Các hàm _buildFilterChips, _buildChip, _buildSectionTitle giữ nguyên)
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        children: [
          _buildChip("Tất cả", isActive: true),
          _buildChip("Admin", isActive: false),
          _buildChip("Biên tập", isActive: false),
          _buildChip("Xem", isActive: false),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.greenLight : const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isActive
                ? AppColors.greenLightBorder
                : const Color(0xFFDFEEE7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.greenText,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.greenText),
          ),
          const SizedBox(width: 8),
          Text(
            "$count người",
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            "Sắp xếp: Mới nhất",
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---- HÀM ĐÃ SỬA ĐỊNH NGHĨA ----
  Widget _buildMemberCard({
    required BuildContext context,
    required GroupMember member,
    required String imageUrl,
    required String name,
    required String subtitle,
    bool isOwner = false,
    String? role,
    bool showAdminActions = false, // <-- SỬA TÊN
    bool showChatAction = false, // <-- THÊM MỚI
  }) {
    // ---------------------------------
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            // (Phần UI (Avatar, Tên, Role) giữ nguyên)
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Image.network(
                  imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              if (isOwner)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Text("Owner",
                      style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                )
              else if (role != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.chipBorder),
                  ),
                  child: Text(role,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.greenText)),
                ),
            ],
          ),

          // ---- SỬA LOGIC HIỂN THỊ NÚT ----

          // KHỐI 1: NÚT NHẮN (Luôn hiển thị nếu không phải là bạn)
          if (showChatAction)
            Padding(
              padding: const EdgeInsets.only(left: 54.0, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSmallButton(
                      label: "💬 Nhắn",
                      isSoft: true,
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/chat',
                          arguments: {'username': member.username},
                        );
                      }),
                ],
              ),
            ),

          // KHỐI 2: CÁC NÚT ADMIN (Chỉ admin mới thấy)
          if (showAdminActions)
            Padding(
              // Cập nhật padding để nó không bị đè lên nút "Nhắn"
              padding:
                  EdgeInsets.only(left: 54.0, top: showChatAction ? 8 : 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSmallButton(
                      label: "Đổi vai trò", isSoft: false, onPressed: () {}),
                  if (role != "admin")
                    _buildSmallButton(
                        label: "Gỡ",
                        isSoft: false,
                        isDanger: true,
                        onPressed: () {}),
                ],
              ),
            ),
          // ---------------------------------
        ],
      ),
    );
  }

  // (Hàm _buildSmallButton giữ nguyên)
  Widget _buildSmallButton(
      {required String label,
      required VoidCallback onPressed,
      bool isSoft = true,
      bool isDanger = false}) {
    Color bgColor = isSoft ? AppColors.greenLight : AppColors.card;
    Color fgColor = isDanger ? Colors.red.shade700 : AppColors.text;
    Color borderColor = isSoft ? AppColors.greenLightBorder : AppColors.line;
    if (isDanger && !isSoft) borderColor = Colors.red.shade200;
    if (isDanger && isSoft) bgColor = Colors.red.shade50;

    return TextButton(
      onPressed: onPressed,
      child: Text(label,
          style: TextStyle(
              color: fgColor, fontWeight: FontWeight.w700, fontSize: 13)),
      style: TextButton.styleFrom(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
