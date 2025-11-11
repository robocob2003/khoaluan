// demo/lib/models/group.dart

class Group {
  // --- THAY ĐỔI: int -> String ---
  final String id;
  final String ownerId;
  // --- KẾT THÚC THAY ĐỔI ---
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<GroupMember> members;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    this.members = const [],
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
      // --- THAY ĐỔI: Chuyển đổi an toàn sang String ---
      id: map['id']?.toString() ?? '',
      ownerId: map['ownerId']?.toString() ?? '',
      // --- KẾT THÚC THAY ĐỔI ---
      name: map['name'] ?? '',
      description: map['description'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    DateTime? createdAt,
    List<GroupMember>? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
    );
  }
}

class GroupMember {
  // --- THAY ĐỔI: int -> String ---
  final String id;
  // --- KẾT THÚC THAY ĐỔI ---
  final String username;
  final String? publicKey;
  final String role;

  GroupMember({
    required this.id,
    required this.username,
    this.publicKey,
    required this.role,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      // --- THAY ĐỔI: Chuyển đổi an toàn sang String ---
      id: map['id']?.toString() ?? '',
      // --- KẾT THÚC THAY ĐỔI ---
      username: map['username'] ?? '',
      publicKey: map['publicKey'],
      role: map['role'] ?? 'member',
    );
  }
}
