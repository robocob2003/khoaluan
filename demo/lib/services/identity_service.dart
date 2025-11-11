// demo/lib/services/identity_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import '../helpers/rsa_helper.dart';

class IdentityService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  RSAPublicKey? _publicKey;
  RSAPrivateKey? _privateKey;
  String? _myPeerId;
  bool _isInitialized = false;

  RSAPublicKey? get publicKey => _publicKey;
  RSAPrivateKey? get privateKey => _privateKey;
  String? get myPeerId => _myPeerId; // Đây là "ID" public của bạn
  bool get isInitialized => _isInitialized;

  // Hàm này được gọi khi app khởi động
  Future<void> initializeIdentity() async {
    try {
      final privateKeyPem = await _storage.read(key: 'privateKey');
      final publicKeyPem = await _storage.read(key: 'publicKey');

      if (privateKeyPem == null || publicKeyPem == null) {
        print('Đang tạo định danh mới...');
        final keyPair = RsaHelper.generateKeyPair();
        _publicKey = keyPair.publicKey;
        _privateKey = keyPair.privateKey;

        final newPublicKeyPem = RsaHelper.encodePublicKeyToPem(_publicKey!);
        final newPrivateKeyPem = RsaHelper.encodePrivateKeyToPem(_privateKey!);

        await _storage.write(key: 'privateKey', value: newPrivateKeyPem);
        await _storage.write(key: 'publicKey', value: newPublicKeyPem);
        _myPeerId = newPublicKeyPem; // Dùng PEM làm ID
      } else {
        print('Đang tải định danh từ bộ nhớ...');
        _publicKey = RsaHelper.decodePublicKeyFromPem(publicKeyPem);
        _privateKey = RsaHelper.decodePrivateKeyFromPem(privateKeyPem);
        _myPeerId = publicKeyPem;
      }

      _isInitialized = true;
      print('Định danh sẵn sàng!');
      notifyListeners();
    } catch (e) {
      print('Lỗi nghiêm trọng khi khởi tạo định danh: $e');
      // Có thể xóa key bị hỏng
      await _storage.deleteAll();
      _isInitialized = false;
      notifyListeners();
    }
  }

  // Xóa định danh (để test)
  Future<void> clearIdentity() async {
    await _storage.deleteAll();
    _publicKey = null;
    _privateKey = null;
    _myPeerId = null;
    _isInitialized = false;
    print('Đã xóa định danh.');
    notifyListeners();
  }
}
