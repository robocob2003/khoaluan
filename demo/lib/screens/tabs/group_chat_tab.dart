// lib/screens/tabs/group_chat_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/websocket_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/typing_indicator.dart';

// <-- SỬA: Chuyển thành StatefulWidget
class GroupChatTab extends StatefulWidget {
  final int groupId;
  const GroupChatTab({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

// <-- SỬA: Thêm class _State
class _GroupChatTabState extends State<GroupChatTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // <-- THÊM: Biến để lưu trữ future tải thành viên
  late Future<List<GroupMember>> _membersFuture;
  // <-- THÊM: Map để tra cứu thành viên (sẽ được cập nhật trong Future)
  final Map<int, GroupMember> _membersMap = {};

  // <-- THÊM: initState để tải dữ liệu khi mở tab
  @override
  void initState() {
    super.initState();
    // Yêu cầu GroupProvider tải thành viên khi widget được xây dựng lần đầu
    // Dùng context.read vì chúng ta chỉ cần gọi 1 lần, không cần "watch"
    _membersFuture =
        context.read<GroupProvider>().getGroupMembers(widget.groupId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        // <-- Thêm kiểm tra hasContentDimensions
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendGroupMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<WebSocketProvider>().sendGroupMessage(content, widget.groupId);

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    // Lấy provider (listen: true để xem tin nhắn)
    final groupProvider = context.watch<GroupProvider>();
    final authProvider = context.watch<AuthProvider>();

    final List<Message> messages =
        groupProvider.getMessagesForGroup(widget.groupId);
    final UserModel? currentUser = authProvider.user;

    _scrollToBottom();

    // <-- THÊM: Dùng FutureBuilder để đảm bảo có dữ liệu thành viên trước
    return FutureBuilder<List<GroupMember>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        // Trạng thái đang tải
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Trạng thái lỗi
        if (snapshot.hasError) {
          return Center(child: Text("Lỗi tải thành viên: ${snapshot.error}"));
        }

        // Trạng thái thành công
        if (snapshot.hasData) {
          // <-- CẬP NHẬT: Điền dữ liệu vào _membersMap
          _membersMap.clear();
          for (var member in snapshot.data!) {
            _membersMap[member.id] = member;
          }
        }

        // <-- DI CHUYỂN: Toàn bộ UI của tab chat vào đây
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 10.0),
                itemCount: messages.length, // TODO: + typing indicator
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == currentUser?.id;

                  // <-- SỬA: Lấy tên người gửi từ Map đã tải
                  // 1. Tìm thành viên trong Map
                  final sender = _membersMap[message.senderId];
                  // 2. Lấy username (ưu tiên từ Map, dự phòng từ Message)
                  final senderUsername =
                      sender?.username ?? message.senderUsername ?? "User";
                  // ------------------------------------------

                  return ChatBubble(
                    message: message,
                    isMe: isMe,
                    userName: isMe ? null : senderUsername,
                    userAvatarUrl: isMe
                        ? null
                        : "https://i.pravatar.cc/150?u=$senderUsername",
                    onDownloadPressed: null, // (Tạm thời tắt cho nhóm)
                    onOpenPressed: null, // (Tạm thời tắt cho nhóm)
                  );
                },
              ),
            ),
            _buildComposer(context),
          ],
        );
      },
    );
  }

  // (Hàm _buildComposer giữ nguyên, không thay đổi)
  Widget _buildComposer(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppColors.muted),
              onPressed: () {
                // TODO: Gửi file trong nhóm
              },
            ),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FBF9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line, width: 1.4),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Viết bình luận nhóm...',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendGroupMessage(),
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sendGroupMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
