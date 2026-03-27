import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailScreen({super.key, required this.activity});

  List<LatLng> _parsePoints() {
    final raw = activity['points'] as List<dynamic>;
    return raw
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final points = _parsePoints();
    final ts = DateTime.parse(activity['timestamp'] as String);
    final count = activity['count'] as int;

    // Centre de la carte = milieu de la trace
    final center = points.isNotEmpty
        ? points[points.length ~/ 2]
        : const LatLng(48.8566, 2.3522);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${ts.day}/${ts.month}/${ts.year} '
              '${ts.hour.toString().padLeft(2, '0')}:'
              '${ts.minute.toString().padLeft(2, '0')}',
        ),
      ),
      body: Column(
        children: [
          // Carte avec la trace
          Expanded(
            flex: 3,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'fr.defense.milfit',
                  tileProvider: CachedTileProvider(
                    store: MemCacheStore(),
                  ),
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (points.isNotEmpty) ...[
                  // Marqueur départ (vert)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 16),
                        ),
                      ),
                      // Marqueur arrivée (rouge)
                      Marker(
                        point: points.last,
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.stop,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Statistiques
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                    icon: Icons.location_on,
                    label: 'Points GPS',
                    value: '$count',
                  ),
                  _StatRow(
                    icon: Icons.straighten,
                    label: 'Distance estimée',
                    value: '${_estimateDistance(points).toStringAsFixed(2)} km',
                  ),
                  _StatRow(
                    icon: Icons.lock,
                    label: 'Stockage',
                    value: 'Chiffré AES-256 · Trace brouillée',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Calcule la distance totale de la trace en kilomètres.
  double _estimateDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    const Distance distance = Distance();
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distance(points[i], points[i + 1]);
    }
    return total / 1000;
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label : ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}