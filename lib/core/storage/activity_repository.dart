import 'dart:convert';
import 'dart:typed_data';
import '../security/crypto_service.dart';
import '../security/key_manager.dart';
import 'local_db.dart';
import 'package:flutter/foundation.dart';

class ActivityRepository {
  final _crypto = CryptoService();
  final _keyManager = KeyManager();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _crypto.init();
    _initialized = true;
  }

  Future<Uint8List> _getMasterKey() async {
    final keyB64 = await _keyManager.getOrCreateMasterKey();
    return base64Url.decode(keyB64);
  }

  /// Sauvegarde une trace GPS chiffrée dans SQLCipher.
  Future<void> saveActivity({
    required List<(double, double)> points,
    required DateTime timestamp,
  }) async {
    await _ensureInit();
    final key = await _getMasterKey();

    // Sérialiser la trace en JSON
    final payload = jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'points': points.map((p) => [p.$1, p.$2]).toList(),
      'count': points.length,
    });

    // Chiffrer avant stockage
    final encrypted = _crypto.encrypt(payload, key);

    final db = await LocalDb().database;
    await db.insert('encrypted_traces', {
      'timestamp': timestamp.toIso8601String(),
      'encrypted_payload': encrypted,
    });
  }

  /// Récupère et déchiffre toutes les activités.
  Future<List<Map<String, dynamic>>> loadActivities() async {
    await _ensureInit();
    final key = await _getMasterKey();

    final db = await LocalDb().database;
    final rows = await db.query(
      'encrypted_traces',
      orderBy: 'timestamp DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final decrypted = _crypto.decrypt(
          row['encrypted_payload'] as String,
          key,
        );
        final data = jsonDecode(decrypted) as Map<String, dynamic>;
        result.add(data);
      } catch (e) {
        // Trace corrompue ou clé incorrecte — on ignore silencieusement
        debugPrint('Trace illisible : $e');
      }
    }
    return result;
  }

  /// Nombre total d'activités stockées.
  Future<int> countActivities() async {
    final db = await LocalDb().database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM encrypted_traces',
    );
    return (result.first['count'] as int?) ?? 0;
  }
}