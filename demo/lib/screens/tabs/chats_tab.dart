// lib/screens/tabs/chats_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <-- THÊM
import 'package:provider/provider.dart'; // <-- THÊM
import '../../config/app_colors.dart';
import '../../models/message.dart'; // <-- THÊM
import '../../models/user.dart'; // <-- THÊM
import '../../providers/auth_provider.dart'; // <-- THÊM
import '../../providers/websocket_provider.dart'; // <-- THÊM

class ChatsTab extends StatelessWidget {
  const ChatsTab({Key? key}) : super(key: key);

  // ---- HÀM HELPER MỚI ĐỂ HIỂN THỊ THỜI GIAN ----
  String _formatTimestamp(DateTime timestamp) {
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
  // -------------------------------------------

  @override
  Widget build(BuildContext context) {
    // ---- LẤY PROVIDER THẬT ----
    final authProvider = context.watch<AuthProvider>();
    final wsProvider = context.watch<WebSocketProvider>();
    final currentUser = authProvider.user;
    // -------------------------

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
            _buildFilterChips(),
            const SizedBox(height: 8),
            _buildSearch(),
            const SizedBox(height: 12),
            _buildSectionTitle(title: "Gần đây", subtitle: "Đang hoạt động"),
            // ---- SỬ DỤNG LOGIC MỚI ----
            _buildChatList(context, currentUser, authProvider, wsProvider),
            // --------------------------
          ],
        ),
      ),
    );
  }

  // "Dịch" từ class="top"
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12.0,
      title: const Text("Trò chuyện",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
      actions: [
        // "Dịch" class="dots"
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

  // "Dịch" từ class="chips"
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        children: [
          _buildChip("Tất cả", isActive: true),
          _buildChip("Nhóm", isActive: false),
          _buildChip("Trực tiếp", isActive: false),
        ],
      ),
    );
  }

  // "Dịch" từ class="chip"
  Widget _buildChip(String label, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? null : AppColors.chipBg,
        gradient: isActive ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(999),
        border: isActive ? null : Border.all(color: AppColors.chipBorder),
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive ? Colors.white : AppColors.greenText,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // "Dịch" từ class="search"
  Widget _buildSearch() {
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
                hintText: "Tìm cuộc trò chuyện…",
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Dịch" từ class="section"
  Widget _buildSectionTitle({required String title, required String subtitle}) {
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
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // "Dịch" từ class="list"
  // ---- ĐÂY LÀ HÀM QUAN TRỌNG NHẤT ----
  Widget _buildChatList(
    BuildContext context,
    UserModel? currentUser,
    AuthProvider authProvider,
    WebSocketProvider wsProvider,
  ) {
    if (currentUser == null) {
      return const Center(child: Text("Đang tải người dùng..."));
    }

    final allMessages = wsProvider.messages;
    final currentUserId = currentUser.id!;

    // Logic nhóm tin nhắn:
    // 1. Tạo một Map để lưu tin nhắn cuối cùng của mỗi cuộc trò chuyện.
    //    Key: ID của người kia, Value: Tin nhắn (Message)
    final Map<int, Message> lastMessages = {};

    for (final msg in allMessages) {
      int? otherUserId;

      // Xác định "người kia"
      if (msg.senderId == currentUserId) {
        otherUserId = msg.receiverId;
      } else if (msg.receiverId == currentUserId) {
        otherUserId = msg.senderId;
      }

      if (otherUserId != null) {
        // Kiểm tra xem đã có tin nhắn nào cho người này chưa
        if (!lastMessages.containsKey(otherUserId) ||
            msg.timestamp.isAfter(lastMessages[otherUserId]!.timestamp)) {
          // Nếu chưa có, hoặc tin nhắn này mới hơn -> lưu nó lại
          lastMessages[otherUserId] = msg;
        }
      }
    }

    // 2. Chuyển Map thành List và sắp xếp (mới nhất lên đầu)
    final sortedConversations = lastMessages.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (sortedConversations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "Chưa có cuộc trò chuyện nào. \nHãy vào màn hình Chat và chọn một người để bắt đầu.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    // 3. Dùng ListView.builder để hiển thị
    return ListView.builder(
      shrinkWrap: true, // Quan trọng khi lồng ListView trong ListView
      physics: const NeverScrollableScrollPhysics(), // Tắt cuộn của list con
      itemCount: sortedConversations.length,
      itemBuilder: (context, index) {
        final lastMessage = sortedConversations[index];

        // Tìm lại ID và thông tin của "người kia"
        final bool isMe = lastMessage.senderId == currentUserId;
        final int otherUserId =
            (isMe ? lastMessage.receiverId : lastMessage.senderId) ?? 0;

        final otherUser = authProvider.availableUsers.firstWhere(
          (u) => u.id == otherUserId,
          orElse: () =>
              UserModel(id: 0, username: "Đã xóa", email: "", password: ""),
        );

        // Chuẩn bị nội dung hiển thị
        String title = otherUser.username;
        String subtitle = lastMessage.content;
        IconData? subtitleIcon;

        if (lastMessage.type == MessageType.file) {
          subtitle = lastMessage.fileName ?? "Tệp tin";
          subtitleIcon = Icons.description; // Icon cho tệp
        }

        if (isMe) {
          subtitle = "Bạn: $subtitle"; // Thêm "Bạn:"
        }

        return _buildChatItem(
          context: context,
          imageUrl:
              "https://i.pravatar.cc/150?u=${otherUser.username}", // Avatar demo
          title: title,
          subtitle: subtitle,
          subtitleIcon: subtitleIcon,
          time: _formatTimestamp(lastMessage.timestamp),
          // Thêm hành động onTap
          onTap: () {
            Navigator.of(context).pushNamed(
              '/chat',
              arguments: {'username': otherUser.username},
            );
          },
        );
      },
    );
  }

  // "Dịch" từ class="item"
  Widget _buildChatItem({
    required BuildContext context,
    required String imageUrl,
    required String title,
    required String subtitle,
    IconData? subtitleIcon,
    required String time,
    int unreadCount = 0,
    bool isGroup = false, // Vẫn giữ logic demo này
    bool isPinned = false,
    VoidCallback? onTap, // <-- Thêm onTap
  }) {
    return InkWell(
      onTap: onTap, // <-- Gán onTap
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            // "Dịch" class="ava"
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
            // "Dịch" class="meta"
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // "Dịch" class="badge"
                      if (isGroup)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: AppColors.greenLightBorder),
                          ),
                          child: const Text("Nhóm",
                              style: TextStyle(
                                  color: Color(0xFF065F46),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // "Dịch" class="preview"
                  Row(
                    children: [
                      if (subtitleIcon != null)
                        Icon(subtitleIcon,
                            color: AppColors.greenText.withOpacity(0.8),
                            size: 16),
                      if (subtitleIcon != null) const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.9),
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // "Dịch" class="right"
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                // "Dịch" class="unread" hoặc "pin"
                if (unreadCount > 0)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$unreadCount",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                else if (isPinned)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1FBF6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD6EFE4)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.push_pin,
                        color: AppColors.greenText, size: 14),
                  )
                else
                  const SizedBox(height: 22), // Giữ chỗ
              ],
            ),
          ],
        ),
      ),
    );
  }
}
