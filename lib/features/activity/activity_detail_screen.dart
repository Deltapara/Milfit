import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/activity_repository.dart';
import '../../shared/models/sport_type.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Map<String, dynamic> activity;
  final _repo = ActivityRepository();

  ActivityDetailScreen({super.key, required this.activity});

  // --- LOGIQUE DE CALCUL ---
  List<LatLng> _parsePoints() {
    final raw = activity['points'] as List<dynamic>? ?? [];
    return raw.map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}min';
    }
    return '${m}min ${s.toString().padLeft(2, '0')}s';
  }

  double _estimateDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    const Distance distance = Distance();
    for (int i = 0; i < points.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total / 1000; // Retourne en km
  }

  // --- INTERFACE ---
  @override
  Widget build(BuildContext context) {
    final points = _parsePoints();
    final ts = DateTime.parse(activity['timestamp'] as String? ?? DateTime.now().toIso8601String());
    final sportName = activity['sport'] ?? 'running';

    final sportType = SportType.values.firstWhere(
          (s) => s.name == sportName,
      orElse: () => SportType.running,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12), // Fond sombre pour cohérence
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          sportType.label.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirm(context, activity['timestamp'] ?? ""),
          ),
        ],
      ),
      body: Column(
        children: [
          // CARTE (Haut)
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.isNotEmpty ? points[points.length ~/ 2] : const LatLng(48.8566, 2.3522),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xFFFF4500),
                    strokeWidth: 4,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ]),
              ],
            ),
          ),

          // STATISTIQUES (Bas)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Ligne sport + date
                  Row(
                    children: [
                      Text(sportType.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sportType.label,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '${ts.day}/${ts.month}/${ts.year} · ${ts.hour.toString().padLeft(2, '0')}h${ts.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Grille de stats
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _StatCard(
                        icon: Icons.straighten,
                        label: 'Distance',
                        value: '${((activity['distance'] as num?) ?? 0).toStringAsFixed(2)} km',
                      ),
                      _StatCard(
                        icon: Icons.timer,
                        label: 'Durée',
                        value: _formatDuration((activity['duration_seconds'] as int?) ?? 0),
                      ),
                      if ((activity['pace'] as String? ?? '').isNotEmpty)
                        _StatCard(
                          icon: Icons.speed,
                          label: 'Allure',
                          value: '${activity['pace']}/km',
                        ),
                      _StatCard(
                        icon: Icons.location_on,
                        label: 'Points GPS',
                        value: '${(activity['points'] as List?)?.length ?? 0}',
                      ),
                      _StatCard(
                        icon: Icons.map,
                        label: 'Distance calculée',
                        value: '${_estimateDistance(points).toStringAsFixed(2)} km',
                      ),
                      _StatCard(
                        icon: Icons.lock,
                        label: 'Sécurité',
                        value: 'AES-256 · Brouillé',
                        color: Colors.greenAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String ts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text("Supprimer l'activité ?", style: TextStyle(color: Colors.white)),
        content: const Text("Cette action est irréversible.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULER")),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.deleteActivity(ts);
              if (context.mounted) context.go('/dashboard');
            },
            child: const Text("SUPPRIMER", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.orangeAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.white,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}