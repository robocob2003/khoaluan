// demo/lib/screens/chat_screen_p2p.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/p2p_service.dart';
import 'package:demo/services/identity_service.dart';
import 'package:demo/widgets/chat_bubble.dart';

class ChatScreenP2P extends StatefulWidget {
  final String peerId;
  const ChatScreenP2P({super.key, required this.peerId});

  @override
  State<ChatScreenP2P> createState() => _ChatScreenP2PState();
}

class _ChatScreenP2PState extends State<ChatScreenP2P> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Thêm controller

  @override
  void initState() {
    super.initState();
    // Lắng nghe P2PService để tự động cuộn
    final p2pService = context.read<P2PService>();
    p2pService.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    // Hủy lắng nghe để tránh rò rỉ bộ nhớ
    context.read<P2PService>().removeListener(_scrollToBottom);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Thêm một chút delay để đợi UI cập nhật
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent, // Cuộn xuống dưới cùng
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    context.read<P2PService>().sendMessage(
          widget.peerId,
          _messageController.text.trim(),
        );

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myPeerId = context.read<IdentityService>().myPeerId;

    // Lắng nghe lịch sử chat của peer này
    final messages =
        context.watch<P2PService>().chatHistory[widget.peerId] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat với ${widget.peerId.substring(0, 10)}...'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Gán controller
              reverse: true, // Hiển thị tin nhắn mới nhất ở dưới
              padding: const EdgeInsets.all(8.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg =
                    messages[messages.length - 1 - index]; // Sắp xếp ngược
                final bool isMe = msg.senderId == myPeerId;

                // Tái sử dụng ChatBubble
                return ChatBubble(
                  message: msg.text,
                  isMe: isMe,
                  timestamp: msg.timestamp,
                  senderName: isMe ? 'Bạn' : 'Peer',
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () {
                // TODO: Gọi hàm p2pService.sendFile()
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
