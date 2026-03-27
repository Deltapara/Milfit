import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart'; // Ajouté pour le calcul de distance
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
    required int durationSeconds,
    required double ascent,
    required String sportType, // 'run' ou 'bike'
    required double realDistance,
  }) async {
    await _ensureInit();
    final key = await _getMasterKey();

    // 1. Calcul de la distance totale en KM (backend-side)
    double totalDistance = 0;
    const Distance distanceCalc = Distance();
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += distanceCalc(
        LatLng(points[i].$1, points[i].$2),
        LatLng(points[i + 1].$1, points[i + 1].$2),
      );
    }
    final distanceKm = totalDistance / 1000;

    // 2. Création du Payload enrichi
    final payload = jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'points': points.map((p) => [p.$1, p.$2]).toList(),
      'count': points.length,
      'distance': realDistance,
      'duration': durationSeconds,
      'ascent': ascent,
      'sport_type': sportType,
    });

    // 3. Chiffrement AES-256
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