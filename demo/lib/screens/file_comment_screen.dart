// lib/screens/file_comment_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/comment.dart';
import '../models/file_transfer.dart';
import '../models/user.dart';
import '../models/message.dart'; // <-- THÊM IMPORT NÀY
import '../providers/auth_provider.dart';
import '../providers/comment_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/chat_bubble.dart';

class FileCommentScreen extends StatefulWidget {
  final FileMetadata file;
  final int groupId;

  const FileCommentScreen({
    Key? key,
    required this.file,
    required this.groupId,
  }) : super(key: key);

  @override
  State<FileCommentScreen> createState() => _FileCommentScreenState();
}

class _FileCommentScreenState extends State<FileCommentScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await context.read<CommentProvider>().loadCommentsForFile(widget.file.id);
    } catch (e) {
      print("Error loading comments: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendComment() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final commentProvider = context.read<CommentProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    final savedComment =
        await commentProvider.createComment(widget.file.id, content);

    if (savedComment != null) {
      wsProvider.webSocketService.sendFileComment(savedComment, widget.groupId);
    }

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final commentProvider = context.watch<CommentProvider>();
    final authProvider = context.watch<AuthProvider>();

    final List<Comment> comments =
        commentProvider.getCommentsForFile(widget.file.id);
    final UserModel? currentUser = authProvider.user;

    _scrollToBottom();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.screenGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context, widget.file.fileName),
        body: Column(
          children: [
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 10.0),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isMe = comment.senderId == currentUser?.id;

                    // ---- DÒNG ĐÃ SỬA ----
                    // Chuyển Comment thành Message (dùng named param)
                    final message = Message(
                        content: comment.content,
                        senderId: comment.senderId,
                        timestamp: comment.timestamp,
                        senderUsername: comment.senderUsername);
                    // ---------------------

                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      userName: isMe ? null : comment.senderUsername,
                      userAvatarUrl: isMe
                          ? null
                          : "https://i.pravatar.cc/150?u=${comment.senderUsername}",
                      onDownloadPressed: null,
                      onOpenPressed: null,
                    );
                  },
                ),
              ),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.greenLightBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.greenText, size: 16),
          ),
        ),
      ),
      leadingWidth: 90,
      title: Text(
        "Bình luận: $title",
        style: const TextStyle(
            color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
    );
  }

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
                    hintText: 'Viết bình luận...',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _sendComment,
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
