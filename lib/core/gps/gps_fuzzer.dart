// lib/core/gps/gps_fuzzer.dart
import 'dart:math';

/// Brouille les points de départ et d'arrivée d'une trace GPS
/// pour masquer l'emplacement exact des installations militaires.
class GpsFuzzer {
  static const double _earthRadiusMeters = 6371000.0;

  /// Applique un bruit gaussien d'environ [radiusMeters] mètres
  /// autour du point d'origine.
  static (double lat, double lon) fuzz(
    double lat,
    double lon, {
    double radiusMeters = 500.0,
  }) {
    final random = Random.secure();

    // Bruit gaussien via Box-Muller
    final u1 = random.nextDouble();
    final u2 = random.nextDouble();
    final gaussX = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    final gaussY = sqrt(-2 * log(u1)) * sin(2 * pi * u2);

    // Convertir les mètres en degrés
    final deltaLat = (gaussX * radiusMeters) / _earthRadiusMeters * (180 / pi);
    final deltaLon = (gaussY * radiusMeters) /
        (_earthRadiusMeters * cos(lat * pi / 180)) *
        (180 / pi);

    return (lat + deltaLat, lon + deltaLon);
  }

  /// Brouille uniquement les N premiers et N derniers points d'une trace.
  /// Les points intermédiaires restent précis pour les stats de performance.
  static List<(double, double)> fuzzTrace(
    List<(double, double)> points, {
    int protectedPoints = 10, // ~300m à vitesse de course
    double radiusMeters = 500.0,
  }) {
    if (points.length <= protectedPoints * 2) {
      // Trace trop courte : tout brouiller
      return points.map((p) => fuzz(p.$1, p.$2, radiusMeters: radiusMeters)).toList();
    }

    final fuzzed = List<(double, double)>.from(points);

    // Brouiller le début
    for (int i = 0; i < protectedPoints; i++) {
      final fade = (protectedPoints - i) / protectedPoints;
      fuzzed[i] = fuzz(points[i].$1, points[i].$2,
          radiusMeters: radiusMeters * fade);
    }

    // Brouiller la fin
    for (int i = points.length - protectedPoints; i < points.length; i++) {
      final fade = (i - (points.length - protectedPoints)) / protectedPoints;
      fuzzed[i] = fuzz(points[i].$1, points[i].$2,
          radiusMeters: radiusMeters * fade);
    }

    return fuzzed;
  }
}
