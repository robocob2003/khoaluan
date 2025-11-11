// lib/models/group.dart

import 'package:flutter/foundation.dart'; // <-- DÒNG ĐÃ SỬA TỪ 'packagef'
import '../models/user.dart'; // <-- Sửa đường dẫn tương đối

// Đại diện cho bảng 'groups'
class Group {
  final int id;
  final String name;
  final String? description;
  final int ownerId;
  final DateTime createdAt;
  // Dùng cho UI, không có trong DB
  final List<GroupMember> members;
  final int unreadCount;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    this.members = const [],
    this.unreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      ownerId: map['ownerId'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Group copyWith({
    int? id,
    String? name,
    String? description,
    int? ownerId,
    DateTime? createdAt,
    List<GroupMember>? members,
    int? unreadCount,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Đại diện cho một thành viên (kết quả join từ 'users' và 'group_members')
class GroupMember {
  final int id; // User ID
  final String username;
  final String? publicKey;
  final String role; // 'admin' hoặc 'member'

  GroupMember({
    required this.id,
    required this.username,
    this.publicKey,
    required this.role,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'],
      username: map['username'] ?? '',
      publicKey: map['publicKey'],
      role: map['role'] ?? 'member',
    );
  }

  // Chuyển đổi một UserModel thành GroupMember (dùng khi tạo nhóm)
  factory GroupMember.fromUser(UserModel user, String role) {
    return GroupMember(
      id: user.id!,
      username: user.username,
      publicKey: user.publicKey,
      role: role,
    );
  }
}
