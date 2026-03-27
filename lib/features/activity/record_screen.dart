import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// On garde l'import, mais on va simplifier le TileLayer dessous
import 'package:flutter_map_cache/flutter_map_cache.dart';

import '../../core/gps/gps_fuzzer.dart';
import '../../core/security/crypto_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false;
  List<(double, double)> _rawPoints = [];
  final _crypto = CryptoService();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _crypto.init();
    _determineInitialPosition();
  }

  Future<void> _determineInitialPosition() async {
    try {
      // 1. Vérifier si les services de localisation sont activés
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("GPS: Services désactivés.");
        return;
      }

      // 2. Vérifier et demander les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("GPS: Permission refusée.");
          return;
        }
      }

      // 3. Obtenir la position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation!, 15.0);

      // 4. Lancer l'écoute automatique dès qu'on a la position initiale
      _startGpsStream();
    } catch (e) {
      debugPrint("Erreur position initiale: $e");
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      final fuzzedPoints = GpsFuzzer.fuzzTrace(_rawPoints);
      _saveActivity(fuzzedPoints);
      setState(() => _isRecording = false);
    } else {
      _rawPoints.clear();
      setState(() => _isRecording = true);
      _startGpsStream();
    }
  }

  void _startGpsStream() {
    Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3)
    ).listen((position) {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newPoint;
        if (_isRecording) {
          _rawPoints.add((position.latitude, position.longitude));
        }
      });
      if (_isRecording) {
        _mapController.move(newPoint, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _saveActivity(List<(double, double)> points) async {
    debugPrint("LOG SÉCURITÉ : Trace de ${points.length} points sauvegardée.");
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Session en cours"),
        content: const Text("Voulez-vous vraiment abandonner ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NON")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            child: const Text("OUI", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SESSION TACTIQUE"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isRecording) {
              _showExitConfirmation(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(48.8566, 2.3522),
              initialZoom: 15.0,
            ),
            children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.defense.milfit',
              tileProvider: CachedTileProvider(
                store: FileCacheStore(
                  FileCacheOptions(
                      cacheDirectory: await getApplicationCacheDirectory(),
                  ),
                ),
              ),
            ),
                PolylineLayer(
                polylines: [
                  Polyline(
                    points: _rawPoints.map((p) => LatLng(p.$1, p.$2)).toList(),
                    color: Colors.blue,
                    strokeWidth: 4,
                  ),
                ],
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 25,
                      height: 25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'btn_gps',
              onPressed: () {
                if (_currentLocation != null) _mapController.move(_currentLocation!, 15.0);
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF1B3A2D)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: FloatingActionButton.large(
                heroTag: 'btn_main',
                onPressed: _toggleRecording,
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                child: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}