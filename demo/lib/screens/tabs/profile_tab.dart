// demo/lib/screens/tabs/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/identity_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:demo/config/app_colors.dart'; // Giữ màu của bạn

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy ID (là public key PEM) của chính mình từ IdentityService
    final myPeerId = context.watch<IdentityService>().myPeerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          // Nút này dùng để test
          // Nhấn vào sẽ xóa định danh và quay về màn hình "Tạo Định danh"
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            tooltip: 'Xóa định danh (TEST)',
            onPressed: () {
              // Ngắt kết nối websocket trước khi xóa
              // (Bạn có thể thêm logic này vào WebSocketService nếu muốn)
              context.read<IdentityService>().clearIdentity();
            },
          ),
        ],
      ),
      // --- 💡 SỬA LỖI Ở ĐÂY ---
      // Bọc toàn bộ body bằng SingleChildScrollView
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryFaded,
                  child: Icon(Icons.person, size: 50, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tên của bạn', // Tương lai bạn có thể cho người dùng tự đặt tên
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Mã kết nối P2P của bạn',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textFaded,
                  ),
                ),
                const SizedBox(height: 16),

                // Hiển thị mã QR
                if (myPeerId != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: myPeerId,
                      version: QrVersions.auto,
                      size: 250.0,
                    ),
                  )
                else
                  // Hiển thị loading nếu chưa kịp tải ID
                  const CircularProgressIndicator(),

                const SizedBox(height: 16),

                // Hiển thị 1 phần ID
                if (myPeerId != null)
                  Text(
                    'ID: ${myPeerId.substring(26, 40)}...${myPeerId.substring(myPeerId.length - 40, myPeerId.length - 25)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textFaded,
                    ),
                  )
                else
                  const SizedBox.shrink(),

                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.security, color: AppColors.primary),
                  title: const Text('Bảo mật'),
                  subtitle: const Text('Quản lý khóa & định danh'),
                  onTap: () {
                    // Tương lai: Tới màn hình quản lý khóa
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storage, color: AppColors.primary),
                  title: const Text('Lưu trữ'),
                  subtitle: const Text('Quản lý file đã tải'),
                  onTap: () {
                    // Tương lai: Tới màn hình FileManagerScreen
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      // --- KẾT THÚC SỬA LỖI ---
    );
  }
}
