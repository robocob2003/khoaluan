// lib/widgets/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/file_transfer.dart';
import '../providers/file_transfer_provider.dart';
import '../config/app_colors.dart';
import '../utils/helpers.dart'; // Import helpers để format file size

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? userAvatarUrl; // Demo avatar
  final String? userName;
  final VoidCallback? onDownloadPressed;
  final VoidCallback? onOpenPressed;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.userAvatarUrl,
    this.userName,
    this.onDownloadPressed,
    this.onOpenPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (Chỉ hiển thị cho người khác)
          if (!isMe)
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.greenLight,
              backgroundImage:
                  userAvatarUrl != null ? NetworkImage(userAvatarUrl!) : null,
              child: userAvatarUrl == null
                  ? Text(
                      userName?.isNotEmpty == true
                          ? userName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: AppColors.greenText,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),

          if (!isMe) const SizedBox(width: 10),

          // Nội dung bong bóng chat
          _buildBubbleContent(context),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    // "Dịch" từ class="bubble"
    final bubbleDecoration = BoxDecoration(
      color: AppColors.card,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        )
      ],
    );

    // "Dịch" từ class="me" (bong bóng của tôi)
    final meBubbleDecoration = BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 18,
          offset: const Offset(0, 6),
        )
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.of(context).size.width * 0.75, // Giới hạn chiều rộng
      ),
      decoration: isMe ? meBubbleDecoration : bubbleDecoration,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Tên người gửi (chỉ hiển thị nếu không phải tôi)
          if (!isMe && userName != null)
            Text(
              userName!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                fontSize: 13,
              ),
            ),

          if (!isMe && userName != null) const SizedBox(height: 4),

          // Nội dung tin nhắn (Văn bản hoặc Tệp)
          if (message.type == MessageType.file)
            _buildFileContent(context)
          else
            _buildTextContent(context),

          const SizedBox(height: 4),

          // Thời gian
          Text(
            DateFormat.Hm().format(message.timestamp), // Định dạng "10:02"
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.8) : AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(BuildContext context) {
    return Text(
      message.content,
      style: TextStyle(
        color: isMe ? Colors.white : AppColors.text,
        fontSize: 15,
      ),
    );
  }

  // --- HÀM NÀY ĐÃ ĐƯỢC NÂNG CẤP ---
  // "Dịch" file chip và logic tải file
  Widget _buildFileContent(BuildContext context) {
    Color textColor = isMe ? Colors.white : AppColors.text;
    Color iconColor = isMe ? Colors.white : AppColors.greenText;
    Color buttonBg =
        isMe ? Colors.white.withOpacity(0.2) : AppColors.greenLight;
    Color buttonFg = isMe ? Colors.white : AppColors.greenText;

    // Lấy trạng thái và tiến trình real-time từ provider
    final provider = context.watch<FileTransferProvider>();
    final status = provider.fileStatuses[message.fileId] ??
        message.fileStatus ??
        FileStatus.pending;
    final progress = provider.downloadProgress[message.fileId] ?? 0.0;

    return Container(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Dịch" từ class="filechip"
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.black.withOpacity(0.1)
                  : AppColors.greenLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border:
                  isMe ? null : Border.all(color: AppColors.greenLightBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file, color: iconColor, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileName ?? 'Unknown File',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (message.fileSize != null)
                        Text(
                          Helpers.formatFileSize(message.fileSize!),
                          style: TextStyle(
                              color: textColor.withOpacity(0.8), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Logic hiển thị nút/thanh tiến trình động
          if (status == FileStatus.completed)
            _buildFileButton(
              onPressed: onOpenPressed,
              icon: Icons.open_in_new,
              label: "Mở Tệp",
              bgColor: buttonBg,
              fgColor: buttonFg,
            )
          else if (status == FileStatus.transferring)
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: Colors.white24,
              color: isMe ? AppColors.card : AppColors.primary,
            )
          else if (status == FileStatus.failed)
            _buildFileButton(
              onPressed: onDownloadPressed,
              icon: Icons.refresh,
              label: "Thử lại",
              bgColor: buttonBg,
              fgColor: buttonFg,
            )
          else // Pending (chưa tải)
            _buildFileButton(
              onPressed: onDownloadPressed,
              icon: Icons.download,
              label: "Tải xuống",
              bgColor: buttonBg,
              fgColor: buttonFg,
            ),
        ],
      ),
    );
  }

  Widget _buildFileButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
