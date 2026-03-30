import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../security/crypto_service.dart';
import '../security/key_manager.dart';
import 'local_db.dart';


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

  /// Supprime une activité de la base de données.
  Future<void> deleteActivity(String timestamp) async {
    final db = await LocalDb().database;
    await db.delete(
      'encrypted_traces',
      where: 'timestamp = ?',
      whereArgs: [timestamp],
    );
  }

  /// Sauvegarde une trace GPS chiffrée avec métriques avancées.
  Future<void> saveActivity({
    required List<(double, double)> points,
    required DateTime timestamp,
    required String sport,
    required int durationSeconds,
    required double distanceKm,
  }) async {
    await _ensureInit();
    final key = await _getMasterKey();

    // Calcul allure (min/km) — uniquement pour course/marche/vélo
    String pace = '';
    if (distanceKm > 0 && durationSeconds > 0) {
      final secPerKm = durationSeconds / distanceKm;
      final min = (secPerKm / 60).floor();
      final sec = (secPerKm % 60).round();
      pace = "$min'${sec.toString().padLeft(2, '0')}\"";
    }

    final payload = jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'points': points.map((p) => [p.$1, p.$2]).toList(),
      'count': points.length,
      'sport': sport,
      'duration_seconds': durationSeconds,
      'distance_km': distanceKm,
      'pace': pace,
    });

    final encrypted = _crypto.encrypt(payload, key);
    final db = await LocalDb().database;
    await db.insert('encrypted_traces', {
      'timestamp': timestamp.toIso8601String(),
      'encrypted_payload': encrypted,
    });
  }

  Future<List<Map<String, dynamic>>> loadActivities() async {
    await _ensureInit();
    final key = await _getMasterKey();

    final db = await LocalDb().database;
    final rows = await db.query('encrypted_traces', orderBy: 'timestamp DESC');

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final decrypted = _crypto.decrypt(row['encrypted_payload'] as String, key);
        final data = jsonDecode(decrypted) as Map<String, dynamic>;
        result.add(data);
      } catch (e) {
        debugPrint('Trace illisible : $e');
      }
    }
    return result;
  }

  Future<int> countActivities() async {
    final db = await LocalDb().database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM encrypted_traces');
    return (result.first['count'] as int?) ?? 0;
  }
}