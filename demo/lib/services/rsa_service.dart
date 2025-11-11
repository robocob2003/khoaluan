// lib/services/rsa_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/api.dart' as pointy;
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:basic_utils/basic_utils.dart';

class RSAService {
  static final Map<String, RSAPublicKey> _publicKeyCache = {};

  /// Generate RSA key pair (2048-bit)
  static Future<AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>>
      generateRsaKeyPair() async {
    final secureRandom = FortunaRandom();
    final seed = Uint8List.fromList(
        List.generate(32, (_) => DateTime.now().millisecondsSinceEpoch % 256));
    secureRandom.seed(pointy.KeyParameter(seed));

    final keyGen = RSAKeyGenerator()
      ..init(pointy.ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  /// Encode public key to PEM format
  static String encodePublicKeyToPem(RSAPublicKey publicKey) {
    return CryptoUtils.encodeRSAPublicKeyToPem(publicKey);
  }

  /// Encode private key to PEM format
  static String encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    return CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);
  }

  /// Parse PEM string to RSAPublicKey
  static RSAPublicKey? parsePublicKey(String pemString) {
    try {
      return CryptoUtils.rsaPublicKeyFromPem(pemString);
    } catch (e) {
      print('Error parsing public key: $e');
      return null;
    }
  }

  /// Parse PEM string to RSAPrivateKey
  static RSAPrivateKey? parsePrivateKey(String pemString) {
    try {
      return CryptoUtils.rsaPrivateKeyFromPem(pemString);
    } catch (e) {
      print('Error parsing private key: $e');
      return null;
    }
  }

  // ---- HÀM encryptData ĐƯỢC GIỮ NGUYÊN ----
  /// Encrypt binary data
  static Uint8List? encryptData(Uint8List data, String username) {
    try {
      final publicKey = _publicKeyCache[username];
      if (publicKey == null) return null;

      final cipher = RSAEngine()
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      return cipher.process(data);
    } catch (e) {
      print('Error encrypting data: $e');
      return null;
    }
  }

  // ---- HÀM encryptMessage (TỪ TỆP CŨ) ĐÃ ĐƯỢC THAY THẾ BẰNG HÀM NÀY ----
  /// Encrypt a string message using a cached public key
  static String? encrypt(String plainText, String username) {
    final publicKey = _publicKeyCache[username];
    if (publicKey == null) {
      print('Error encrypting: Public key for $username not found.');
      return null;
    }
    try {
      final cipher = RSAEngine()
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final inputBytes = Uint8List.fromList(utf8.encode(plainText));
      final outputBytes = cipher.process(inputBytes);

      return base64Encode(outputBytes);
    } catch (e) {
      print('Error encrypting message for $username: $e');
      return null;
    }
  }

  // ---- HÀM MỚI ĐÃ THÊM ----
  /// Decrypt a base64 encoded string using a private key
  static String? decrypt(String base64Encrypted, RSAPrivateKey privateKey) {
    try {
      final cipher = RSAEngine()
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      final inputBytes = base64Decode(base64Encrypted);
      final outputBytes = cipher.process(inputBytes);

      return utf8.decode(outputBytes);
    } catch (e) {
      print('Error decrypting message: $e');
      return null;
    }
  }
  // -------------------------

  /// Sign data using private key
  static String signData(Uint8List data, RSAPrivateKey privateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final signature = signer.generateSignature(data) as RSASignature;
    return base64Encode(signature.bytes);
  }

  /// Verify signature using cached public key
  static bool verifySignature({
    required Uint8List data,
    required String base64Signature,
    required String username,
  }) {
    final publicKey = _publicKeyCache[username];
    if (publicKey == null) {
      print(
          'Verification failed: Public key for $username not found in cache.');
      return false;
    }

    try {
      final signatureBytes = base64Decode(base64Signature);

      final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
      signer.init(false, PublicKeyParameter<RSAPublicKey>(publicKey));

      return signer.verifySignature(data, RSASignature(signatureBytes));
    } catch (e) {
      print('Error verifying signature: $e');
      return false;
    }
  }

  /// Cache a public key for a username
  static void cachePublicKey(String username, String pemPublicKey) {
    final publicKey = parsePublicKey(pemPublicKey);
    if (publicKey != null) {
      _publicKeyCache[username] = publicKey;
    }
  }

  /// Clear the cache
  static void clearCache() {
    _publicKeyCache.clear();
  }

  /// Check if public key exists in cache
  static bool hasPublicKey(String username) {
    return _publicKeyCache.containsKey(username);
  }
}
