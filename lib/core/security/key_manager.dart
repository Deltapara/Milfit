import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  final _storage = const FlutterSecureStorage();
  final String _keyAlias = 'master_encryption_key';

  Future<String> getOrCreateMasterKey() async {
    String? key = await _storage.read(key: _keyAlias);
    if (key == null) {
      final values = List<int>.generate(32, (i) => Random.secure().nextInt(256));
      key = base64Url.encode(values);
      await _storage.write(key: _keyAlias, value: key);
    }
    return key;
  }

  Future<void> emergencyWipe() async {
    // 1. On supprime la clé maîtresse du Keystore
    await _storage.deleteAll();

    // 2. Sans la clé, la base SQLCipher devient un bloc de données aléatoires
    // totalement impossible à déchiffrer (Brute-force inutile).
    print("ALERTE : Clés détruites. Données verrouillées à jamais.");
  }

}