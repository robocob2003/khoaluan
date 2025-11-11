// lib/models/user.dart

class UserModel {
  final int? id;
  final String username;
  final String email;
  final String password; // Mật khẩu đã được băm
  final String? publicKey; // Khóa công khai RSA từ server
  final String? privateKey; // Thường không lưu ở client, chỉ để tham khảo

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    this.publicKey,
    this.privateKey,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'publicKey': publicKey,
      'privateKey': privateKey,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      publicKey: map['publicKey'],
      privateKey: map['privateKey'],
    );
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? password,
    String? publicKey,
    String? privateKey,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
    );
  }

  @override
  String toString() {
    return 'UserModel{id: $id, username: $username, email: $email, hasPublicKey: ${publicKey != null}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username;

  @override
  int get hashCode => id.hashCode ^ username.hashCode;
}
