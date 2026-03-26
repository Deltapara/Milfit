import 'package:latlong2/latlong.dart';

class SecurityConstants {
  // Zones d'interdiction de tracking (exemples : Bases Navales)
  static final List<LatLng> noTrackZones = [
    LatLng(43.1167, 5.9167), // Toulon
    LatLng(48.3903, -4.4861), // Brest
    LatLng(44.8333, -0.5667), // Bordeaux (Région Militaire)
  ];

  static const double safetyRadiusMeters = 2000.0; // 2km de zone tampon
}