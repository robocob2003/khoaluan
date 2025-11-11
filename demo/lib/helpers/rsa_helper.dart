import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:basic_utils/basic_utils.dart';

class RsaHelper {
  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeyPair() {
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          _secureRandom()));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
      pair.publicKey as RSAPublicKey,
      pair.privateKey as RSAPrivateKey,
    );
  }

  static FortunaRandom _secureRandom() {
    final random = FortunaRandom();
    random.seed(KeyParameter(Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(255)))));
    return random;
  }

  static String encodePublicKeyToPem(RSAPublicKey key) =>
      CryptoUtils.encodeRSAPublicKeyToPemPkcs1(key);

  static String encodePrivateKeyToPem(RSAPrivateKey key) =>
      CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(key);

  static RSAPublicKey decodePublicKeyFromPem(String pem) =>
      CryptoUtils.rsaPublicKeyFromPem(pem);

  static RSAPrivateKey decodePrivateKeyFromPem(String pem) =>
      CryptoUtils.rsaPrivateKeyFromPem(pem);

  static String encrypt(String text, RSAPublicKey key) =>
      enc.Encrypter(enc.RSA(publicKey: key, encoding: enc.RSAEncoding.PKCS1))
          .encrypt(text)
          .base64;

  static String decrypt(String text, RSAPrivateKey key) =>
      enc.Encrypter(enc.RSA(privateKey: key, encoding: enc.RSAEncoding.PKCS1))
          .decrypt(enc.Encrypted.fromBase64(text));
}
