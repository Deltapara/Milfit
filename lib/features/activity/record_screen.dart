import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

import '../../core/storage/activity_repository.dart';
import '../../core/gps/gps_fuzzer.dart';
import '../../core/security/crypto_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // --- LOGIQUE DE DONNÉES ---
  bool _isRecording = false;
  String _selectedSport = 'run';
  final List<(double, double)> _rawPoints = [];
  double _totalDistance = 0.0;
  double _totalAscent = 0.0;
  double? _lastAltitude;
  double _currentAccuracy = 0.0; // Précision GPS en mètres

  // --- CHRONO ---
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _timeDisplay = "00:00:00";
  String _speedDisplay = "0:00";

  final _crypto = CryptoService();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  final CacheStore _cacheStore = MemCacheStore();
  final _repo = ActivityRepository();

  @override
  void initState() {
    super.initState();
    _crypto.init();
    _determineInitialPosition();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        _updateTime();
        _calculateLiveSpeed();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --- CALCULS STATS ---

  void _updateTime() {
    final duration = _stopwatch.elapsed;
    setState(() {
      _timeDisplay = "${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
    });
  }

  void _calculateLiveSpeed() {
    if (_totalDistance <= 0 || _stopwatch.elapsed.inSeconds <= 5) return;

    double distanceKm = _totalDistance / 1000;
    double totalHours = _stopwatch.elapsed.inSeconds / 3600;

    setState(() {
      if (_selectedSport == 'bike') {
        _speedDisplay = (distanceKm / totalHours).toStringAsFixed(1);
      } else {
        double minutesPerKm = (_stopwatch.elapsed.inSeconds / 60) / distanceKm;
        int mins = minutesPerKm.floor();
        int secs = ((minutesPerKm - mins) * 60).round();
        if (mins > 99) mins = 99;
        _speedDisplay = "$mins:${secs.toString().padLeft(2, '0')}";
      }
    });
  }

  // --- LOGIQUE GPS ---

  Future<void> _determineInitialPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentAccuracy = position.accuracy;
      });
      _mapController.move(_currentLocation!, 15.0);
      _startGpsStream();
    } catch (e) {
      debugPrint('Erreur GPS Initial: $e');
    }
  }

  void _startGpsStream() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((position) {
      if (!mounted) return;

      setState(() => _currentAccuracy = position.accuracy);

      // Filtre de précision : on ignore les points > 20m d'erreur
      if (position.accuracy > 20) return;

      final point = LatLng(position.latitude, position.longitude);

      setState(() {
        if (_isRecording && _currentLocation != null) {
          _totalDistance += Geolocator.distanceBetween(
              _currentLocation!.latitude, _currentLocation!.longitude,
              position.latitude, position.longitude
          );

          if (_lastAltitude != null && position.altitude > _lastAltitude!) {
            _totalAscent += (position.altitude - _lastAltitude!);
          }
          _lastAltitude = position.altitude;
          _rawPoints.add((position.latitude, position.longitude));
        }
        _currentLocation = point;
      });

      if (_isRecording) _mapController.move(point, _mapController.camera.zoom);
    });
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _rawPoints.clear();
        _totalDistance = 0.0;
        _totalAscent = 0.0;
        _lastAltitude = null;
        _stopwatch.reset();
        _stopwatch.start();
      } else {
        _stopwatch.stop();
        _saveActivity();
      }
    });
  }

  Future<void> _saveActivity() async {
    if (_rawPoints.isEmpty) return;

    // On brouille la trace uniquement pour le stockage/affichage carte
    final fuzzed = GpsFuzzer.fuzzTrace(_rawPoints);

    await _repo.saveActivity(
      points: fuzzed,
      timestamp: DateTime.now(),
      durationSeconds: _stopwatch.elapsed.inSeconds,
      ascent: _totalAscent,
      sportType: _selectedSport,
      // On envoie la distance réelle calculée (non impactée par le fuzzing)
      realDistance: _totalDistance / 1000,
    );

    if (!mounted) return;
    context.go('/dashboard');
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png?api_key=cbd82e40-e047-4707-8946-b2e3f6b635ae',

                userAgentPackageName: 'com.example.milfit',

                retinaMode: RetinaMode.isHighDensity(context),

                maxZoom: 20,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _rawPoints.map((p) => LatLng(p.$1, p.$2)).toList(),
                    color: const Color(0xFFFF4500),
                    strokeWidth: 5,
                  ),
                ],
              ),

              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 5)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // BANDEAU TACTIQUE
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGpsBadge(),
                  const SizedBox(height: 10),
                  if (!_isRecording) _buildSportToggle(),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _liveStat("DISTANCE", "${(_totalDistance / 1000).toStringAsFixed(2)}", "KM"),
                      _liveStat(_selectedSport == 'run' ? "ALLURE" : "VITESSE", _speedDisplay, _selectedSport == 'run' ? "/KM" : "KM/H"),
                      _liveStat("CHRONO", _timeDisplay, ""),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // BOUTON RETOUR
          Positioned(
            top: 55, left: 15,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => _isRecording ? _showExitConfirmation() : context.go('/dashboard'),
            ),
          ),

          // BOUTON ACTION
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: FloatingActionButton.large(
                onPressed: _toggleRecording,
                backgroundColor: _isRecording ? Colors.red : const Color(0xFFFF4500),
                child: Icon(_isRecording ? Icons.stop : Icons.play_arrow, size: 40, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsBadge() {
    Color color = Colors.red;
    String label = "SIGNAL FAIBLE";
    if (_currentAccuracy > 0 && _currentAccuracy <= 12) {
      color = Colors.greenAccent;
      label = "GPS OPTIMAL";
    } else if (_currentAccuracy <= 25) {
      color = Colors.orangeAccent;
      label = "GPS MOYEN";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }

  Widget _buildSportToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _sportButton("RUN", 'run', Icons.directions_run),
        const SizedBox(width: 10),
        _sportButton("BIKE", 'bike', Icons.directions_bike),
      ],
    );
  }

  Widget _sportButton(String label, String type, IconData icon) {
    bool isSel = _selectedSport == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedSport = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFFF4500) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSel ? Colors.white : Colors.white54),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _liveStat(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _showExitConfirmation() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Abandonner la mission ?', style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('NON')),
        TextButton(onPressed: () { Navigator.pop(context); context.go('/dashboard'); }, child: const Text('OUI', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}