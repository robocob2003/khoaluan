// demo/lib/models/user.dart
class UserModel {
  // --- THAY ĐỔI: int? -> String? ---
  final String? id;
  // --- KẾT THÚC THAY ĐỔI ---
  final String username;
  final String? email;
  final String? password;
  final String? publicKey;
  final String? privateKey; // Chỉ lưu ở local

  UserModel({
    this.id,
    required this.username,
    this.email,
    this.password,
    this.publicKey,
    this.privateKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Đã là String
      'username': username,
      'email': email,
      'password': password,
      'publicKey': publicKey,
      'privateKey': privateKey,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      // --- THAY ĐỔI: Chuyển đổi an toàn sang String ---
      id: map['id']?.toString(),
      // --- KẾT THÚC THAY ĐỔI ---
      username: map['username'] ?? '',
      email: map['email'],
      password: map['password'],
      publicKey: map['publicKey'],
      privateKey: map['privateKey'],
    );
  }
}
