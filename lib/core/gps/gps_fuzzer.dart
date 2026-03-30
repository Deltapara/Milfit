import 'dart:math';

/// Brouille les points de départ et d'arrivée d'une trace GPS
/// pour masquer l'emplacement exact des installations militaires.
class GpsFuzzer {

  /// Applique un bruit gaussien d'environ [radiusMeters] mètres
  /// autour du point d'origine.
  static (double lat, double lon) fuzz(
      double lat,
      double lon, {
        double radiusMeters = 500.0,
      }) {
    final random = Random.secure();

    // Bruit gaussien via Box-Muller (Distribution normale)
    final u1 = random.nextDouble();
    final u2 = random.nextDouble();
    final gaussX = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    final gaussY = sqrt(-2 * log(u1)) * sin(2 * pi * u2);

    // --- CONVERSION PRÉCISE MÈTRES -> DEGRÉS ---
    // 1 degré de latitude est constant (~111.32 km)
    const double latDegPerMeter = 1.0 / 111320.0;
    // 1 degré de longitude dépend de la latitude (se rétrécit vers les pôles)
    final double lonDegPerMeter = 1.0 / (111320.0 * cos(lat * pi / 180));

    final deltaLat = gaussX * radiusMeters * latDegPerMeter;
    final deltaLon = gaussY * radiusMeters * lonDegPerMeter;

    return (lat + deltaLat, lon + deltaLon);
  }

  /// Brouille uniquement les N premiers et N derniers points d'une trace.
  /// Les points intermédiaires restent précis pour les stats de performance.
  static List<(double, double)> fuzzTrace(
      List<(double, double)> points, {
        int protectedPoints = 15, // Augmenté légèrement pour plus de sécurité
        double radiusMeters = 500.0,
      }) {
    if (points.length <= protectedPoints * 2) {
      // Trace trop courte (ex: test statique) : on brouille tout uniformément
      return points.map((p) => fuzz(p.$1, p.$2, radiusMeters: radiusMeters)).toList();
    }

    final fuzzed = List<(double, double)>.from(points);

    // Brouiller le début (Fondu sortant : du plus flou au plus précis)
    for (int i = 0; i < protectedPoints; i++) {
      final fade = (protectedPoints - i) / protectedPoints;
      fuzzed[i] = fuzz(points[i].$1, points[i].$2,
          radiusMeters: radiusMeters * fade);
    }

    // Brouiller la fin (Fondu entrant : du précis au plus flou)
    for (int i = points.length - protectedPoints; i < points.length; i++) {
      final fade = (i - (points.length - protectedPoints)) / protectedPoints;
      fuzzed[i] = fuzz(points[i].$1, points[i].$2,
          radiusMeters: radiusMeters * fade);
    }

    return fuzzed;
  }
}