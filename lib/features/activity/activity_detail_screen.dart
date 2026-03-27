import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/activity_repository.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Map<String, dynamic> activity;
  final _repo = ActivityRepository();

  ActivityDetailScreen({super.key, required this.activity});

  // --- LOGIQUE DE CALCUL ---
  List<LatLng> _parsePoints() {
    final raw = activity['points'] as List<dynamic>;
    return raw.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    return "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    final points = _parsePoints();
    final sport = activity['sport_type'] ?? 'run';
    final distance = (activity['distance'] ?? 0.0) as double;
    final duration = (activity['duration'] ?? 0) as int;
    final ascent = (activity['ascent'] ?? 0.0) as double;
    final timestamp = activity['timestamp'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard'); // Sécurité si le pop échoue
            }
          },
        ),
        title: Text(
          sport == 'run' ? "SESSION COURSE" : "SESSION VÉLO",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        actions: [
          // BOUTON SUPPRIMER
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirm(context, timestamp),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // GRILLE DE STATS (Contraste Max)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem("DISTANCE", distance.toStringAsFixed(2), "KM"),
                      _statItem(
                          sport == 'run' ? "ALLURE" : "VITESSE",
                          _calculateSpeed(distance, duration, sport),
                          sport == 'run' ? "/KM" : "KM/H"
                      ),
                      _statItem("TEMPS", _formatDuration(duration), ""),
                    ],
                  ),
                  const Divider(height: 40, indent: 30, endIndent: 30, color: Color(0xFFF2F2F7)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statItem("DÉNIVELÉ", ascent.toStringAsFixed(0), "M D+"),
                      _statItem("POINTS", points.length.toString(), "GPS"),
                      _statItem("SÉCURITÉ", "AES", "256"),
                    ],
                  ),
                ],
              ),
            ),

            // CARTE
            SizedBox(
              height: 400,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.isNotEmpty ? points[points.length ~/ 2] : const LatLng(48.8566, 2.3522),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  PolylineLayer(polylines: [
                    Polyline(points: points, color: const Color(0xFFFF4500), strokeWidth: 5),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ],
    );
  }

  String _calculateSpeed(double dist, int sec, String type) {
    if (dist <= 0 || sec <= 0) return "0.0";
    if (type == 'bike') {
      return (dist / (sec / 3600)).toStringAsFixed(1);
    } else {
      double minPerKm = (sec / 60) / dist;
      return "${minPerKm.floor()}:${((minPerKm - minPerKm.floor()) * 60).round().toString().padLeft(2, '0')}";
    }
  }

  void _showDeleteConfirm(BuildContext context, String ts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer l'activité ?"),
        content: const Text("Cette action est irréversible et les données chiffrées seront détruites."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.deleteActivity(ts);
              if (context.mounted) {
                context.go('/dashboard');
              }
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}