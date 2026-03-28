import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';

import '../../core/gps/gps_fuzzer.dart';
import '../../core/security/crypto_service.dart';
import '../../core/storage/activity_repository.dart';
import '../../shared/models/sport_type.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false;
  final List<(double, double)> _rawPoints = [];
  final _crypto = CryptoService();
  final _repo = ActivityRepository();
  final MapController _mapController = MapController();
  final CacheStore _cacheStore = MemCacheStore();
  final _stopwatch = StopWatchTimer(mode: StopWatchMode.countUp);

  LatLng? _currentLocation;
  SportType _selectedSport = SportType.running;
  double _distanceKm = 0;

  @override
  void initState() {
    super.initState();
    _crypto.init();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _stopwatch.dispose();
    super.dispose();
  }

  Future<void> _determineInitialPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation!, 15.0);
      _startGpsStream();
    } catch (e) {
      debugPrint('Erreur position initiale: $e');
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopwatch.onStopTimer();
      final elapsed = _stopwatch.rawTime.value ~/ 1000;
      final fuzzed = GpsFuzzer.fuzzTrace(_rawPoints);
      _saveActivity(fuzzed, elapsed);
      setState(() => _isRecording = false);
    } else {
      // Afficher le sélecteur de sport avant de démarrer
      _showSportPicker().then((_) {
        if (!mounted) return;
        _rawPoints.clear();
        _distanceKm = 0;
        _stopwatch.onResetTimer();
        _stopwatch.onStartTimer();
        setState(() => _isRecording = true);
        _startGpsStream();
      });
    }
  }

  Future<void> _showSportPicker() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type d\'activité',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 16),
            ...SportType.values.map((sport) => ListTile(
              leading: Text(sport.emoji,
                  style: const TextStyle(fontSize: 28)),
              title: Text(sport.label,
                  style: const TextStyle(color: Colors.white)),
              trailing: _selectedSport == sport
                  ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                  : null,
              onTap: () {
                setState(() => _selectedSport = sport);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _startGpsStream() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((position) {
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        if (_isRecording && _currentLocation != null) {
          const dist = Distance();
          _distanceKm +=
              dist(_currentLocation!, point) / 1000;
        }
        _currentLocation = point;
        if (_isRecording) {
          _rawPoints.add((position.latitude, position.longitude));
        }
      });
      if (_isRecording) {
        _mapController.move(point, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _saveActivity(
      List<(double, double)> points, int durationSeconds) async {
    if (points.isEmpty) return;
    try {
      await _repo.saveActivity(
        points: points,
        timestamp: DateTime.now(),
        sport: _selectedSport.name,
        durationSeconds: durationSeconds,
        distanceKm: _distanceKm,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${_selectedSport.emoji} ${points.length} points chiffrés et sauvegardés'),
        backgroundColor: Colors.green.shade800,
      ));
    } catch (e) {
      debugPrint('Erreur sauvegarde : $e');
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session en cours'),
        content: const Text('Abandonner cette activité ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('NON')),
          TextButton(
            onPressed: () {
              _stopwatch.onStopTimer();
              Navigator.pop(context);
              context.go('/dashboard');
            },
            child: const Text('OUI', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    final s = ms ~/ 1000;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRecording
            ? '${_selectedSport.emoji} EN COURS'
            : 'NOUVELLE MISSION'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:
          _isRecording ? _showExitConfirmation : () => context.go('/dashboard'),
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
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.defense.milfit',
                tileProvider: CachedTileProvider(store: _cacheStore),
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _rawPoints
                        .map((p) => LatLng(p.$1, p.$2))
                        .toList(),
                    color: const Color(0xFF00E676),
                    strokeWidth: 4,
                  ),
                ],
              ),
              if (_currentLocation != null)
                MarkerLayer(markers: [
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
                ]),
            ],
          ),

          // HUD stats en temps réel
          if (_isRecording)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: StreamBuilder<int>(
                stream: _stopwatch.rawTime,
                builder: (ctx, snap) {
                  final ms = snap.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _HudStat(
                            label: 'Durée',
                            value: _formatDuration(ms)),
                        _HudStat(
                            label: 'Distance',
                            value:
                            '${_distanceKm.toStringAsFixed(2)} km'),
                        _HudStat(
                            label: 'Points',
                            value: '${_rawPoints.length}'),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Bouton centrer
          Positioned(
            top: _isRecording ? 90 : 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'btn_gps',
              onPressed: () {
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 15.0);
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location,
                  color: Color(0xFF1B3A2D)),
            ),
          ),

          // Bouton principal
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: FloatingActionButton.large(
                heroTag: 'btn_main',
                onPressed: _toggleRecording,
                backgroundColor:
                _isRecording ? Colors.red : const Color(0xFF4CAF50),
                child: Icon(
                    _isRecording ? Icons.stop : Icons.play_arrow,
                    size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  final String label;
  final String value;
  const _HudStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF00E676),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}