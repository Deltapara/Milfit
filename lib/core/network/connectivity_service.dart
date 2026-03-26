// lib/core/network/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, sensitiveZone }

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    if (results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  });
});

/// Vérifie si l'app doit bloquer toute émission réseau.
/// En zone sensible (configurable par l'admin), forcer le mode hors-ligne
/// même si le réseau est disponible.
class ConnectivityService {
  static bool isTransmissionAllowed(NetworkStatus status) {
    return status == NetworkStatus.online;
  }
}
