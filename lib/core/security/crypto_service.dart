// lib/core/security/crypto_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:sodium_libs/sodium_libs.dart';

/// Service de chiffrement symétrique AES-256-GCM via libsodium.
/// Les traces GPS sont chiffrées AVANT tout stockage ou envoi réseau.
class CryptoService {
  late final Sodium _sodium;

  Future<void> init() async {
    _sodium = await SodiumInit.init();
  }

  /// Chiffre un message avec une clé symétrique.
  /// Retourne : nonce (24 bytes) + ciphertext, encodé en base64.
  String encrypt(String plaintext, Uint8List key) {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);
    final messageBytes = utf8.encode(plaintext);

    final ciphertext = _sodium.crypto.secretBox.easy(
      message: Uint8List.fromList(messageBytes),
      nonce: nonce,
      key: SecureKey.fromList(_sodium, key),
    );

    // Préfixer le nonce au ciphertext pour le déchiffrement
    final combined = Uint8List(nonce.length + ciphertext.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + ciphertext.length, ciphertext);

    return base64.encode(combined);
  }

  /// Déchiffre un message chiffré par [encrypt].
  String decrypt(String encoded, Uint8List key) {
    final combined = base64.decode(encoded);
    final nonceLength = _sodium.crypto.secretBox.nonceBytes;

    final nonce = combined.sublist(0, nonceLength);
    final ciphertext = combined.sublist(nonceLength);

    // Correction finale : cipherText avec un T majuscule
    final plaintext = _sodium.crypto.secretBox.openEasy(
      cipherText: ciphertext,
      nonce: nonce,
      key: SecureKey.fromList(_sodium, key),
    );

    return utf8.decode(plaintext);
  }
}
