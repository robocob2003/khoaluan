// demo/lib/services/db_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/message.dart';
import '../models/file_transfer.dart';
import '../models/group.dart';
import '../models/comment.dart';

// (Tạm thời chúng ta sẽ định nghĩa enum ở đây, sau sẽ chuyển đi)
enum FriendshipStatus { pending, accepted, rejected }

class DBService {
  static Database? _database;
  // --- TĂNG PHIÊN BẢN DB ĐỂ BUỘC NÂNG CẤP ---
  static const String _dbName = 'flutter_chat_P2P_V1.db'; // Đổi tên DB mới
  static const int _dbVersion = 1; // Bắt đầu lại từ V1
  // --- KẾT THÚC ---

  static Future<void> initialize() async {
    await database;
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate, // Sẽ chạy _onCreate vì tên DB mới
      // onUpgrade: _onUpgrade, // Không cần onUpgrade nếu tạo DB mới
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // --- HÀM NÀY BỊ LOẠI BỎ VÌ CHÚNG TA TẠO DB MỚI ---
  // static Future<void> _onUpgrade(
  //     Database db, int oldVersion, int newVersion) async { ... }
  // --- KẾT THÚC ---

  static Future<void> _onCreate(Database db, int version) async {
    print("--- 💡 TẠO DATABASE P2P MỚI (V1) ---");
    // --- THAY ĐỔI: id INTEGER -> id TEXT ---
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY, 
        username TEXT UNIQUE NOT NULL,
        email TEXT,
        password TEXT,
        publicKey TEXT,
        privateKey TEXT
      )
    ''');

    // --- THAY ĐỔI: ...Id INTEGER -> ...Id TEXT ---
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT,
        groupId TEXT, 
        timestamp TEXT NOT NULL,
        type TEXT NOT NULL,
        senderUsername TEXT,
        fileId TEXT,
        fileName TEXT,
        fileSize INTEGER,
        fileStatus TEXT 
      )
    ''');

    // --- THAY ĐỔI: ...Id INTEGER -> ...Id TEXT ---
    await db.execute('''
      CREATE TABLE file_transfers (
        id TEXT PRIMARY KEY,
        fileName TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        totalChunks INTEGER NOT NULL,
        senderId TEXT NOT NULL,
        receiverId TEXT, 
        groupId TEXT, 
        timestamp TEXT NOT NULL,
        filePath TEXT,
        status TEXT NOT NULL,
        mimeType TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE file_chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileId TEXT NOT NULL,
        chunkIndex INTEGER NOT NULL,
        chunkSize INTEGER NOT NULL,
        chunkPath TEXT,
        isEncrypted INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        checksum TEXT,
        FOREIGN KEY (fileId) REFERENCES file_transfers (id) ON DELETE CASCADE,
        UNIQUE(fileId, chunkIndex)
      )
    ''');

    await _createGroupTables(db);
    await _createCommentTable(db);
    await _createTagTable(db);
    await _createFriendshipTable(db);
  }

  static Future<void> _createCommentTable(Database db) async {
    // --- THAY ĐỔI: senderId INTEGER -> senderId TEXT ---
    await db.execute('''
      CREATE TABLE file_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileId TEXT NOT NULL,
        senderId TEXT NOT NULL, 
        senderUsername TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (fileId) REFERENCES file_transfers (id) ON DELETE CASCADE,
        FOREIGN KEY (senderId) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');
  }

  static Future<void> _createTagTable(Database db) async {
    await db.execute('''
      CREATE TABLE file_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileId TEXT NOT NULL,
        tag TEXT NOT NULL,
        FOREIGN KEY (fileId) REFERENCES file_transfers (id) ON DELETE CASCADE,
        UNIQUE(fileId, tag)
      )
    ''');
  }

  static Future<void> _createGroupTables(Database db) async {
    // --- THAY ĐỔI: id INTEGER -> id TEXT, ownerId INTEGER -> ownerId TEXT ---
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY, 
        name TEXT NOT NULL,
        description TEXT,
        ownerId TEXT NOT NULL, 
        createdAt TEXT NOT NULL,
        FOREIGN KEY (ownerId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // --- THAY ĐỔI: groupId INTEGER -> groupId TEXT, userId INTEGER -> userId TEXT ---
    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        groupId TEXT NOT NULL, 
        userId TEXT NOT NULL, 
        role TEXT NOT NULL DEFAULT 'member',
        joinedAt TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(groupId, userId)
      )
    ''');
  }

  static Future<void> _createFriendshipTable(Database db) async {
    // --- THAY ĐỔI: ...Id INTEGER -> ...Id TEXT ---
    await db.execute('''
      CREATE TABLE friendships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_one_id TEXT NOT NULL, 
        user_two_id TEXT NOT NULL, 
        status TEXT NOT NULL, -- 'pending', 'accepted', 'rejected'
        action_user_id TEXT NOT NULL, 
        FOREIGN KEY (user_one_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (user_two_id) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(user_one_id, user_two_id)
      )
    ''');
  }

  // --- User Operations ---
  static Future<int> insertUser(UserModel user) async {
    final db = await database;
    // `user.toMap()` đã bao gồm ID (String),
    // `ConflictAlgorithm.replace` sẽ ghi đè
    return await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  // --- THAY ĐỔI: int id -> String id ---
  static Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  static Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query('users',
        where: 'LOWER(username) = LOWER(?)', whereArgs: [username], limit: 1);
    if (maps.isNotEmpty) return UserModel.fromMap(maps.first);
    return null;
  }

  static Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users');
    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int id -> String id ---
  static Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // --- Message Operations ---
  static Future<int> insertMessage(Message message) async {
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  static Future<List<Message>> getRecentMessages(int limit) async {
    final db = await database;
    final maps =
        await db.query('messages', orderBy: 'timestamp DESC', limit: limit);
    return List.generate(maps.length, (i) => Message.fromMap(maps[i]))
        .reversed
        .toList();
  }

  // --- File Transfer Operations ---
  static Future<void> insertFileTransfer(FileMetadata metadata) async {
    final db = await database;
    await db.insert('file_transfers', metadata.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> saveNewFileTransfer(
      FileMetadata metadata, List<FileChunkData> chunks) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('file_transfers', metadata.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final chunk in chunks) {
        await txn.insert('file_chunks', chunk.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> saveIncomingFileTransferAndMessage(
      FileMetadata metadata, Message message) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('file_transfers', metadata.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.insert('messages', message.toMap());
    });
  }

  static Future<void> updateFileTransferStatus(
      String id, FileStatus status) async {
    final db = await database;
    await db.update('file_transfers', {'status': status.toString()},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateFileTransferPath(String id, String path) async {
    final db = await database;
    await db.update(
      'file_transfers',
      {'filePath': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<FileMetadata?> getFileTransfer(String id) async {
    final db = await database;
    final maps = await db.query('file_transfers',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isNotEmpty) return FileMetadata.fromMap(maps.first);
    return null;
  }

  // --- THAY ĐỔI: int userId -> String userId ---
  static Future<List<FileMetadata>> getSentFiles(String userId) async {
    final db = await database;
    final maps = await db.query('file_transfers',
        where: 'senderId = ?', whereArgs: [userId], orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => FileMetadata.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int userId -> String userId ---
  static Future<List<FileMetadata>> getReceivedFiles(String userId) async {
    final db = await database;
    final maps = await db.query('file_transfers',
        where: 'receiverId = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => FileMetadata.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int groupId -> String groupId ---
  static Future<List<FileMetadata>> getFilesForGroup(String groupId) async {
    final db = await database;
    final maps = await db.query('file_transfers',
        where: 'groupId = ?', whereArgs: [groupId], orderBy: 'timestamp DESC');
    return List.generate(maps.length, (i) => FileMetadata.fromMap(maps[i]));
  }

  static Future<void> deleteFileTransfer(String fileId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('file_chunks', where: 'fileId = ?', whereArgs: [fileId]);
      await txn.delete('file_transfers', where: 'id = ?', whereArgs: [fileId]);
    });
  }

  static Future<int> insertFileChunk(FileChunkData chunk) async {
    final db = await database;
    return await db.insert('file_chunks', chunk.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> updateFileChunkStatus(
      String fileId, int chunkIndex, ChunkStatus status) async {
    final db = await database;
    await db.update('file_chunks', {'status': status.toString()},
        where: 'fileId = ? AND chunkIndex = ?',
        whereArgs: [fileId, chunkIndex]);
  }

  static Future<List<FileChunkData>> getFileChunks(String fileId) async {
    final db = await database;
    final maps = await db.query('file_chunks',
        where: 'fileId = ?', whereArgs: [fileId], orderBy: 'chunkIndex ASC');
    return List.generate(maps.length, (i) => FileChunkData.fromMap(maps[i]));
  }

  static Future<FileChunkData?> getSingleFileChunk(
      String fileId, int chunkIndex) async {
    final db = await database;
    final maps = await db.query('file_chunks',
        where: 'fileId = ? AND chunkIndex = ?',
        whereArgs: [fileId, chunkIndex],
        limit: 1);
    if (maps.isNotEmpty) return FileChunkData.fromMap(maps.first);
    return null;
  }

  static Future<int> getCompletedChunksCount(String fileId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) FROM file_chunks WHERE fileId = ? AND status = ?',
        [fileId, ChunkStatus.transferred.toString()]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // --- Group Operations ---
  // --- THAY ĐỔI: int ownerId -> String ownerId ---
  static Future<Group?> createGroup(
      String name, String description, String ownerId) async {
    final db = await database;
    Group? newGroup;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      // ID của nhóm sẽ là UUID hoặc hash, do P2P tạo ra
      final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
      await txn.insert(
        'groups',
        {
          'id': groupId,
          'name': name,
          'description': description,
          'ownerId': ownerId,
          'createdAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'group_members',
        {
          'groupId': groupId,
          'userId': ownerId,
          'role': 'admin',
          'joinedAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final maps =
          await txn.query('groups', where: 'id = ?', whereArgs: [groupId]);
      newGroup = Group.fromMap(maps.first);
    });
    return newGroup;
  }

  static Future<void> insertGroup(Group group) async {
    final db = await database;
    await db.insert(
      'groups',
      group.toMap(), // Model 'group' đã phải được cập nhật
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- THAY ĐỔI: int -> String ---
  static Future<void> addUserToGroup(
      String groupId, String userId, String role) async {
    final db = await database;
    await db.insert(
      'group_members',
      {
        'groupId': groupId,
        'userId': userId,
        'role': role,
        'joinedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- THAY ĐỔI: int -> String ---
  static Future<void> removeUserFromGroup(String groupId, String userId) async {
    final db = await database;
    await db.delete(
      'group_members',
      where: 'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );
  }

  // --- THAY ĐỔI: int userId -> String userId ---
  static Future<List<Group>> getGroupsForUser(String userId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT g.* FROM groups g
      INNER JOIN group_members gm ON g.id = gm.groupId
      WHERE gm.userId = ?
      ORDER BY g.createdAt DESC
    ''', [userId]);

    return List.generate(maps.length, (i) => Group.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int groupId -> String groupId ---
  static Future<List<GroupMember>> getMembersInGroup(String groupId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT u.id, u.username, u.publicKey, gm.role
      FROM users u
      INNER JOIN group_members gm ON u.id = gm.userId
      WHERE gm.groupId = ?
      ORDER BY u.username ASC
    ''', [groupId]);

    return List.generate(maps.length, (i) => GroupMember.fromMap(maps[i]));
  }

  // --- Comment Operations ---
  static Future<int> addFileComment(Comment comment) async {
    final db = await database;
    return await db.insert('file_comments', comment.toMap());
  }

  static Future<List<Comment>> getCommentsForFile(String fileId) async {
    final db = await database;
    final maps = await db.query(
      'file_comments',
      where: 'fileId = ?',
      whereArgs: [fileId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => Comment.fromMap(maps[i]));
  }

  // --- Tag Operations ---
  static Future<void> addFileTags(String fileId, List<String> tags) async {
    final db = await database;
    final batch = db.batch();
    for (final tag in tags) {
      batch.insert(
        'file_tags',
        {'fileId': fileId, 'tag': tag.toLowerCase()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<String>> getTagsForFile(String fileId) async {
    final db = await database;
    final maps = await db.query(
      'file_tags',
      columns: ['tag'],
      where: 'fileId = ?',
      whereArgs: [fileId],
    );
    return List.generate(maps.length, (i) => maps[i]['tag'] as String);
  }

  // --- Friendship Operations ---
  // --- THAY ĐỔI: int -> String ---
  static Future<void> addFriendRequest(
      String myId, String otherId, String actionUserId) async {
    final db = await database;
    // So sánh chuỗi
    final userOneId = myId.compareTo(otherId) < 0 ? myId : otherId;
    final userTwoId = myId.compareTo(otherId) < 0 ? otherId : myId;

    await db.insert(
      'friendships',
      {
        'user_one_id': userOneId,
        'user_two_id': userTwoId,
        'status': FriendshipStatus.pending.toString(),
        'action_user_id': actionUserId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- THAY ĐỔI: int -> String ---
  static Future<void> updateFriendshipStatus(
      String myId, String otherId, FriendshipStatus status) async {
    final db = await database;
    final userOneId = myId.compareTo(otherId) < 0 ? myId : otherId;
    final userTwoId = myId.compareTo(otherId) < 0 ? otherId : myId;

    await db.update(
      'friendships',
      {'status': status.toString()},
      where: 'user_one_id = ? AND user_two_id = ?',
      whereArgs: [userOneId, userTwoId],
    );
  }

  // --- THAY ĐỔI: int myId -> String myId ---
  static Future<List<UserModel>> getFriends(String myId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT u.* FROM users u
      INNER JOIN friendships f ON u.id = f.user_one_id OR u.id = f.user_two_id
      WHERE (f.user_one_id = ? OR f.user_two_id = ?)
      AND f.status = ?
      AND u.id != ?
    ''', [myId, myId, FriendshipStatus.accepted.toString(), myId]);

    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int myId -> String myId ---
  static Future<List<UserModel>> getPendingRequests(String myId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT u.* FROM users u
      INNER JOIN friendships f ON u.id = f.action_user_id
      WHERE (f.user_one_id = ? OR f.user_two_id = ?)
      AND f.status = ?
      AND f.action_user_id != ?
    ''', [myId, myId, FriendshipStatus.pending.toString(), myId]);

    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int myId -> String myId ---
  static Future<List<UserModel>> getSentRequests(String myId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT u.* FROM users u
      INNER JOIN friendships f ON (u.id = f.user_one_id OR u.id = f.user_two_id)
      WHERE f.status = ?
      AND f.action_user_id = ?
      AND u.id != ?
    ''', [FriendshipStatus.pending.toString(), myId, myId]);

    return List.generate(maps.length, (i) => UserModel.fromMap(maps[i]));
  }

  // --- THAY ĐỔI: int -> String ---
  static Future<Map<String, dynamic>?> getFriendshipStatus(
      String myId, String otherId) async {
    final db = await database;
    final userOneId = myId.compareTo(otherId) < 0 ? myId : otherId;
    final userTwoId = myId.compareTo(otherId) < 0 ? otherId : myId;

    final maps = await db.query(
      'friendships',
      where: 'user_one_id = ? AND user_two_id = ?',
      whereArgs: [userOneId, userTwoId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
