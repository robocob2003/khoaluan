// lib/config/app_config.dart

class AppConfig {
  // --- HƯỚNG DẪN CẤU HÌNH KẾT NỐI ---
  // Vui lòng chọn MỘT trong ba tùy chọn dưới đây bằng cách bỏ comment (xóa dấu //)
  // cho dòng bạn cần, và comment lại (thêm dấu //) cho các dòng còn lại.

  // Tùy chọn 1: Dùng cho Android Emulator
  // '10.0.2.2' là địa chỉ đặc biệt để emulator kết nối đến localhost của máy tính.
  // static const String _host = '10.0.2.2';

  // Tùy chọn 2: Dùng cho thiết bị điện thoại thật
  // LƯU Ý: Thay '192.168.1.5' bằng địa chỉ IP mạng LAN của máy tính bạn.
  // static const String _host = '192.168.1.5';

  // Tùy chọn 3: Dùng khi chạy ứng dụng Flutter trên Desktop (Windows, macOS, Linux)
  //static const String _host = '192.168.1.27';
  // static const String _host = '10.51.199.36';
  //static const String _host = '192.168.110.69';
  static const String _host = '192.168.1.2';
  // --- ĐỊA CHỈ SERVER ---s
  // Các URL này sẽ tự động cập nhật dựa vào giá trị _host bạn đã chọn ở trên.
  // Tạm thời dùng http và ws để test với server local không có SSL.
  // Khi triển khai ứng dụng thực tế, hãy đổi lại thành https và wss.
  static const String apiBaseUrl = 'http://$_host:3000';
  static const String webSocketUrl = 'ws://$_host:3000';
}
