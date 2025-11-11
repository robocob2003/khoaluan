// lib/utils/helpers.dart
import 'dart:math';

/// Định dạng bytes thành KB, MB, GB
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  final i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

/// Lấy chữ cái đầu (viết hoa) từ tên
String getInitials(String username) {
  if (username.isEmpty) return '?';
  // Lấy ký tự đầu tiên, có thể là chữ cái hoặc không
  return username.trim().substring(0, 1).toUpperCase();
}

// --- 💡 ĐÃ SỬA: Dùng String PeerID thay vì int UserID ---
/// Tạo ID cuộc trò chuyện 1-1 duy nhất từ hai PeerID
String getConversationId(String peerId1, String peerId2) {
  // So sánh chuỗi để đảm bảo thứ tự luôn cố định
  // (ví dụ: 'peerA_peerB' luôn là 'peerA_peerB', không bao giờ là 'peerB_peerA')
  if (peerId1.compareTo(peerId2) < 0) {
    return '${peerId1}_${peerId2}';
  } else {
    return '${peerId2}_${peerId1}';
  }
}
// --- KẾT THÚC SỬA ---
