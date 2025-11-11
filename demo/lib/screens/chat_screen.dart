// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/file_transfer.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/file_transfer_provider.dart';
import '../widgets/typing_indicator.dart';
import '../services/error_handler.dart';
import '../config/app_colors.dart'; // Import bảng màu
import '../services/file_service.dart'; // Import FileService
import 'video_player_screen.dart'; // Import màn hình video

// ---- THAY ĐỔI IMPORT ----
import '../widgets/chat_bubble.dart'; // Dùng bubble mới
// -------------------------

class ChatScreen extends StatefulWidget {
  // ---- THÊM THUỘC TÍNH MỚI ----
  final String? initialRecipientUsername;

  const ChatScreen({Key? key, this.initialRecipientUsername}) : super(key: key);
  // --------------------------

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();

  String? _selectedRecipientUsername;

  @override
  void initState() {
    super.initState();
    _selectedRecipientUsername = widget.initialRecipientUsername;
    // ---- ĐÃ XÓA LOGIC _loadLocalMessages() ----
    // Chỉ cần cuộn xuống (nếu có tin nhắn đã được nạp)
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // ---- HÀM _loadLocalMessages() ĐÃ BỊ XÓA ----
  // (Vì logic này đã được chuyển ra main_layout.dart)
  // ------------------------------------------

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients &&
        _scrollController.position.hasContentDimensions) {
      final position = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(position);
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _selectedRecipientUsername == null) return;

    final authProvider = context.read<AuthProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    if (authProvider.user?.id == null) {
      ErrorHandler.showError(
          context, "Could not send message: User data is invalid.");
      return;
    }

    final recipient = authProvider.availableUsers.firstWhere(
      (u) =>
          u.username.toLowerCase() == _selectedRecipientUsername?.toLowerCase(),
      orElse: () => UserModel(id: -1, username: '', email: '', password: ''),
    );
    if (recipient.id == -1) {
      ErrorHandler.showError(context, "Recipient not found");
      return;
    }

    final message = Message(
      content: content,
      senderId: authProvider.user!.id!,
      receiverId: recipient.id,
      timestamp: DateTime.now(),
      senderUsername: authProvider.user!.username,
    );

    try {
      await DBService.insertMessage(message);
    } catch (e) {
      print("!!! DATABASE INSERT FAILED !!!");
      print(e.toString());
      ErrorHandler.showError(
          context, "DATABASE ERROR: Could not save message. Check console.");
      return;
    }

    wsProvider.sendMessage(content, _selectedRecipientUsername!);
    wsProvider.sendTypingIndicator(false, _selectedRecipientUsername!);
    wsProvider.addLocalMessage(message);

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onTypingChanged(String text) {
    final wsProvider = context.read<WebSocketProvider>();
    if (_selectedRecipientUsername != null && wsProvider.isConnected) {
      wsProvider.sendTypingIndicator(
          text.isNotEmpty, _selectedRecipientUsername!);
    }
  }

  void _pickFile(List<String>? allowedExtensions) async {
    Navigator.pop(context); // Close the modal bottom sheet
    try {
      final result = await FilePicker.platform.pickFiles(
          type: allowedExtensions != null ? FileType.custom : FileType.any,
          allowedExtensions: allowedExtensions);
      if (result != null && result.files.single.path != null) {
        _sendFile(result.files.single.path!);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Failed to pick file: $e');
    }
  }

  Future<void> _sendFile(String filePath) async {
    if (_selectedRecipientUsername == null) {
      ErrorHandler.showError(context, 'No recipient selected');
      return;
    }
    final authProvider = context.read<AuthProvider>();
    final fileProvider = context.read<FileTransferProvider>();
    final wsProvider = context.read<WebSocketProvider>();

    if (authProvider.user?.id == null) {
      ErrorHandler.showError(context, 'User not authenticated');
      return;
    }

    try {
      final recipient = authProvider.availableUsers.firstWhere((u) =>
          u.username.toLowerCase() ==
          _selectedRecipientUsername?.toLowerCase());

      final metadata = await fileProvider.sendFile(
          filePath,
          _selectedRecipientUsername!,
          authProvider.user!.id!,
          recipient.id ?? 0);

      if (metadata != null) {
        final fileMessage = Message(
          content: 'Đã gửi tệp: ${metadata.fileName}',
          senderId: authProvider.user!.id!,
          receiverId: recipient.id,
          timestamp: metadata.timestamp,
          type: MessageType.file,
          fileId: metadata.id,
          fileName: metadata.fileName,
          fileSize: metadata.fileSize,
          fileStatus: metadata.status,
          senderUsername: authProvider.user!.username,
        );
        await DBService.insertMessage(fileMessage);
        wsProvider.addLocalMessage(fileMessage);

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else if (mounted && fileProvider.error != null) {
        ErrorHandler.showError(context, fileProvider.error!);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Could not find recipient user data.');
      }
    }
  }

  void _downloadFile(String? fileId) {
    if (fileId == null) {
      ErrorHandler.showError(context, "File ID is invalid.");
      return;
    }
    context.read<FileTransferProvider>().requestDownload(fileId);
  }

  void _openFile(String? fileId) async {
    // Thêm async
    if (fileId == null) {
      ErrorHandler.showError(context, "File ID is invalid.");
      return;
    }

    // Kiểm tra xem có phải file video không
    final metadata = await DBService.getFileTransfer(fileId);
    if (metadata != null && FileService.isVideoFile(metadata.fileName)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(fileMetadata: metadata),
        ),
      );
    } else {
      // Nếu không, dùng logic mở file cũ
      context.read<FileTransferProvider>().openFile(fileId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // "Dịch" nền gradient
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.screenGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context), // "Dịch" AppBar
        body: Column(
          children: [
            // ---- CHỈ HIỂN THỊ NẾU KHÔNG TRUYỀN USERNAME VÀO ----
            if (widget.initialRecipientUsername == null)
              _buildRecipientSelector(), // Giữ lại dropdown chọn người chat
            // --------------------------------------------------
            if (widget.initialRecipientUsername ==
                null) // Thêm divider nếu dropdown hiển thị
              const Divider(color: AppColors.line, height: 1),
            Expanded(child: _buildMessagesList()),
            _buildComposer(), // "Dịch" ô nhập liệu
          ],
        ),
      ),
    );
  }

  // ---- APPBAR MỚI (Dịch từ messeger-group.html và chat.html) ----
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(), // Quay lại
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
        _selectedRecipientUsername ?? 'Trò chuyện',
        style:
            const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: InkWell(
            onTap: () {
              // Mở màn hình File Manager
              Navigator.of(context).pushNamed('/file-manager');
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.greenLightBorder),
              ),
              // Đổi icon thành icon file
              child: const Icon(Icons.folder_copy_outlined,
                  color: AppColors.greenText, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // Widget này vẫn giữ nguyên, nhưng giao diện bên trong đã được "tân trang"
  Widget _buildRecipientSelector() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: _selectedRecipientUsername,
            hint: const Text('Chọn người nhận...'),
            isExpanded: true,
            items: auth.availableUsers.map((user) {
              return DropdownMenuItem(
                value: user.username,
                child: Text(user.username),
              );
            }).toList(),
            // ---- LOGIC SỬA ĐỔI ----
            onChanged: widget.initialRecipientUsername != null
                ? null
                : (value) {
                    setState(() {
                      _selectedRecipientUsername = value;
                    });
                  },
            // ------------------------
            decoration: InputDecoration(
              filled: true,
              // ---- LOGIC SỬA ĐỔI ----
              fillColor: widget.initialRecipientUsername != null
                  ? AppColors.greenLight.withOpacity(0.5)
                  : AppColors.card,
              // ------------------------
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              // Thêm style cho lúc bị vô hiệu hóa
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.greenLightBorder),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesList() {
    return Consumer2<WebSocketProvider, AuthProvider>(
      builder: (context, ws, auth, child) {
        // ... (Logic tìm currentUser, recipientUser, filteredMessages... giữ nguyên)
        final currentUser = auth.user;
        if (currentUser == null) return const Center(child: Text("..."));
        if (_selectedRecipientUsername == null) {
          // Sửa lại: Nếu không có ai được chọn (và không phải đang vào từ link)
          // thì hiển thị hướng dẫn
          if (widget.initialRecipientUsername == null) {
            return const Center(
                child: Text('Vui lòng chọn người để trò chuyện.'));
          }
          // Nếu đang vào từ link mà lỗi
          return const Center(child: CircularProgressIndicator());
        }
        UserModel? recipientUser;
        try {
          recipientUser = auth.availableUsers.firstWhere(
            (user) =>
                user.username.toLowerCase() ==
                _selectedRecipientUsername?.toLowerCase(),
          );
        } catch (e) {
          return Center(
              child: Text(
                  "Không tìm thấy người nhận '$_selectedRecipientUsername'."));
        }
        final currentUserId = currentUser.id!;
        final recipientId = recipientUser.id!;
        // ---- SỬA LOGIC LỌC TIN NHẮN ----
        // Lấy từ WebSocketProvider (chỉ chứa tin 1-1)
        final filteredMessages = ws.messages.where((msg) {
          return (msg.senderId == currentUserId &&
                  msg.receiverId == recipientId) ||
              (msg.senderId == recipientId && msg.receiverId == currentUserId);
        }).toList();
        // ---------------------------------
        final isRecipientTyping =
            ws.typingUsers.containsKey(_selectedRecipientUsername);

        if (filteredMessages.isEmpty && !isRecipientTyping) {
          return Center(
              child: Text("Chưa có tin nhắn với $_selectedRecipientUsername."));
        }
        // ------------------------------------------------------------------

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          itemCount: filteredMessages.length + (isRecipientTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == filteredMessages.length) {
              return TypingIndicator(users: [_selectedRecipientUsername!]);
            }
            final message = filteredMessages[index];
            final isMe = message.senderId == currentUserId;

            // ---- SỬ DỤNG BONG BÓNG CHAT MỚI ----
            return ChatBubble(
              message: message,
              isMe: isMe,
              userName: isMe ? null : recipientUser?.username,
              // Demo avatar, bạn có thể thay bằng avatar thật nếu có
              userAvatarUrl: isMe
                  ? null
                  : "https://i.pravatar.cc/150?u=${recipientUser?.username}",

              // Truyền các hàm xử lý file
              onDownloadPressed: message.type == MessageType.file && !isMe
                  ? () => _downloadFile(message.fileId)
                  : null,
              onOpenPressed: message.type == MessageType.file
                  ? () => _openFile(message.fileId)
                  : null,
            );
            // ---------------------------------
          },
        );
      },
    );
  }

  // ---- Ô NHẬP LIỆU MỚI (Dịch từ .composer trong messeger-group.html) ----
  Widget _buildComposer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: const Border(top: BorderSide(color: AppColors.line)),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -4),
              blurRadius: 10,
              color: Colors.black.withOpacity(0.03),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Nút đính kèm
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppColors.muted),
              onPressed: _selectedRecipientUsername != null
                  ? _showAttachmentOptions
                  : null,
              tooltip: 'Attach File',
            ),
            // Ô nhập liệu
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
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Viết tin nhắn…',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onChanged: _onTypingChanged,
                  onSubmitted: (_) => _sendMessage(),
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Nút gửi
            ElevatedButton(
              onPressed:
                  _selectedRecipientUsername != null ? _sendMessage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, // Sẽ dùng gradient
                padding: EdgeInsets.zero, // Tự custom padding
                shape: const CircleBorder(),
                elevation: 0, // Tắt shadow mặc định
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

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo, color: AppColors.greenText),
                  title: const Text('Images & Photos',
                      style: TextStyle(color: AppColors.text)),
                  onTap: () => _pickFile(['jpg', 'jpeg', 'png', 'gif'])),
              ListTile(
                  leading:
                      const Icon(Icons.videocam, color: AppColors.greenText),
                  title: const Text('Videos',
                      style: TextStyle(color: AppColors.text)),
                  onTap: () => _pickFile(['mp4', 'mov', 'avi', 'mkv'])),
              ListTile(
                  leading:
                      const Icon(Icons.description, color: AppColors.greenText),
                  title: const Text('Documents',
                      style: TextStyle(color: AppColors.text)),
                  onTap: () =>
                      _pickFile(['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'])),
              ListTile(
                  leading:
                      const Icon(Icons.folder_open, color: AppColors.greenText),
                  title: const Text('Browse All Files',
                      style: TextStyle(color: AppColors.text)),
                  onTap: () => _pickFile(null)),
            ],
          ),
        );
      },
    );
  }
}
