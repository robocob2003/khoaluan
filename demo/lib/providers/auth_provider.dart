// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import '../models/user.dart';
import '../services/db_service.dart';
import '../services/api_service.dart';
import '../services/error_handler.dart';
import '../services/rsa_service.dart';
import 'dart:async';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  UserModel? get user => _user;

  RSAPrivateKey? _privateKey;
  RSAPrivateKey? get privateKey => _privateKey;

  List<UserModel> _availableUsers = [];
  List<UserModel> get availableUsers => _availableUsers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  final ApiService _apiService = ApiService();
  final _secureStorage = const FlutterSecureStorage();

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() async {
    await _checkServerConnection();
    await fetchUsers();
  }

  Future<void> _checkServerConnection() async {
    _isOnline = await _apiService.checkConnection();
    Future.microtask(() => notifyListeners());
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    BuildContext context,
  ) async {
    if (username.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      ErrorHandler.showError(context, "Please fill all fields");
      return false;
    }

    setLoading(true);

    try {
      final existingUser = await DBService.getUserByUsername(username);
      if (existingUser != null) {
        ErrorHandler.showError(context, "Username already exists");
        return false;
      }

      print("Generating RSA key pair on the client...");
      final keyPair = await RSAService.generateRsaKeyPair();
      final publicKeyPem = RSAService.encodePublicKeyToPem(keyPair.publicKey);
      final privateKeyPem =
          RSAService.encodePrivateKeyToPem(keyPair.privateKey);

      final hashedPassword = _hashPassword(password);
      UserModel user = UserModel(
        username: username.trim(),
        email: email.trim(),
        password: hashedPassword,
        publicKey: publicKeyPem,
      );

      if (_isOnline) {
        try {
          final success = await _apiService.register(
              username, email, password, publicKeyPem);
          if (!success) {
            ErrorHandler.showError(
                context, "Server registration failed. Please try again.");
            return false;
          }
        } catch (e) {
          print('Server registration failed: $e');
        }
      }

      // ---- SỬA: Chúng ta cần lấy ID từ server sau khi đăng ký ----
      // Tạm thời, chúng ta sẽ fetchUsers để lấy ID đúng
      await fetchUsers();
      final serverUser = await DBService.getUserByUsername(username);

      if (serverUser != null) {
        _user = serverUser;
      } else {
        // Fallback (ít xảy ra)
        final userId = await DBService.insertUser(user);
        _user = user.copyWith(id: userId);
      }

      await _secureStorage.write(
          key: 'private_key_${_user!.username}', value: privateKeyPem);
      print("Private key securely stored for user ${_user!.username}.");

      _privateKey = keyPair.privateKey;

      await fetchUsers(); // Tải lại để đảm bảo
      return true;
    } catch (e) {
      ErrorHandler.showError(context, "Registration failed: $e");
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> login(
    String username,
    String password,
    BuildContext context,
  ) async {
    if (username.trim().isEmpty || password.isEmpty) {
      ErrorHandler.showError(context, "Please fill all fields");
      return false;
    }

    setLoading(true);
    _user = null;

    try {
      final hashedPassword = _hashPassword(password);
      UserModel? loggedInUser;

      if (_isOnline) {
        try {
          // ---- SỬA: Đồng bộ hóa hoàn toàn khi đăng nhập ----
          // 1. Tải tất cả user từ server
          await fetchUsers();

          // 2. Lấy user local (bây giờ đã được đồng bộ)
          final localUser = await DBService.getUserByUsername(username.trim());

          // 3. Gọi API login chỉ để xác thực mật khẩu
          final serverResponse = await _apiService.login(username, password);

          if (serverResponse != null && localUser != null) {
            // Xác thực thành công
            loggedInUser = localUser;
          }
          // ------------------------------------------
        } catch (e) {
          print('Server login failed, falling back to local: $e');
        }
      }

      if (loggedInUser == null) {
        final localUser = await DBService.getUserByUsername(username.trim());
        if (localUser != null && localUser.password == hashedPassword) {
          loggedInUser = localUser;
        }
      }

      if (loggedInUser != null) {
        _user = loggedInUser;
        await _loadPrivateKey();
        await fetchUsers(); // Tải lại danh sách availableUsers

        Future.microtask(() => notifyListeners());

        return true;
      }

      ErrorHandler.showError(context, "Invalid username or password");
      return false;
    } catch (e) {
      ErrorHandler.showError(context, "Login failed: $e");
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> _loadPrivateKey() async {
    if (_user == null) return;
    try {
      final pem =
          await _secureStorage.read(key: 'private_key_${_user!.username}');
      if (pem != null) {
        _privateKey = RSAService.parsePrivateKey(pem);
        if (_privateKey != null) {
          print('Private key loaded successfully for ${_user!.username}.');
        } else {
          print('Failed to parse stored private key.');
        }
      } else {
        print('No private key found in secure storage for this user.');
      }
    } catch (e) {
      print('Error loading private key: $e');
    }
  }

  void _cacheUserPublicKeys() {
    for (final user in _availableUsers) {
      if (user.publicKey != null && user.publicKey!.isNotEmpty) {
        RSAService.cachePublicKey(user.username, user.publicKey!);
      }
    }
    print(
        'Cached ${_availableUsers.where((u) => u.publicKey != null).length} RSA public keys');
  }

  // ---- HÀM ĐÃ ĐƯỢC CẬP NHẬT ----
  Future<void> fetchUsers() async {
    try {
      List<UserModel> serverUsers = [];
      if (_isOnline) {
        try {
          serverUsers = await _apiService.getUsers();
        } catch (e) {
          print('Failed to fetch users from server: $e');
        }
      }
      if (serverUsers.isEmpty) {
        print("Server không trả về user nào. Giữ CSDL local.");
        // Tải danh sách local
        _availableUsers = (await DBService.getAllUsers())
            .where((user) => user.username != _user?.username)
            .toList();
        _availableUsers.sort((a, b) => a.username.compareTo(b.username));
        _cacheUserPublicKeys();
        Future.microtask(() => notifyListeners());
        return;
      }

      // Có user từ server, tiến hành đồng bộ
      final localUsers = await DBService.getAllUsers();
      final Map<int, UserModel> localUserMapById = {
        for (var u in localUsers) u.id!: u
      };

      // 1. Dùng Map<String, UserModel> cho server
      final Map<String, UserModel> serverUserMapByUsername = {
        for (var u in serverUsers) u.username: u
      };

      // 2. Xóa user local nếu không còn trên server
      for (final localUser in localUsers) {
        if (!serverUserMapByUsername.containsKey(localUser.username)) {
          print(
              "Đang xóa user local không tồn tại trên server: ${localUser.username}");
          await DBService.deleteUser(localUser.id!);
        }
      }

      // 3. Chèn hoặc Cập nhật user từ server
      for (final serverUser in serverUsers) {
        // Chúng ta dùng ConflictAlgorithm.replace, nên cứ insert
        await DBService.insertUser(serverUser);
      }

      // 4. Tải lại danh sách cuối cùng
      _availableUsers = (await DBService.getAllUsers())
          .where((user) => user.username != _user?.username)
          .toList();
      _availableUsers.sort((a, b) => a.username.compareTo(b.username));

      _cacheUserPublicKeys();
      Future.microtask(() => notifyListeners());
    } catch (e) {
      print('Error fetching users: $e');
    }
  }
  // --------------------------------

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> logout() async {
    _user = null;
    _privateKey = null;
    _availableUsers.clear();
    RSAService.clearCache();
    notifyListeners();
  }

  Future<void> refreshConnection() async {
    await _checkServerConnection();
    if (_isOnline) {
      await fetchUsers();
    }
  }

  bool canEncryptTo(String username) {
    return RSAService.hasPublicKey(username);
  }

  Future<bool> updateProfile(String newEmail, BuildContext context) async {
    if (_user == null) {
      ErrorHandler.showError(context, "Bạn chưa đăng nhập");
      return false;
    }

    setLoading(true);
    try {
      bool success = false;
      if (_isOnline) {
        success = await _apiService.updateProfile(_user!.username, newEmail);
        if (!success) {
          ErrorHandler.showError(context, "Cập nhật server thất bại");
          return false;
        }
      }

      final updatedUser = _user!.copyWith(email: newEmail);
      await DBService.updateUser(updatedUser);

      _user = updatedUser;

      ErrorHandler.showSuccess(context, "Cập nhật email thành công");
      return true;
    } catch (e) {
      ErrorHandler.showError(context, "Lỗi: $e");
      return false;
    } finally {
      setLoading(false);
    }
  }
}
