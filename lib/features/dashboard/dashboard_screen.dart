import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/activity_repository.dart';
import '../../shared/models/sport_type.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ActivityRepository();
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  // --- CALCULS ---
  double _calculateWeeklyTotal() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities.where((a) {
      final ts = a['timestamp'];
      if (ts == null) return false;
      return DateTime.parse(ts as String).isAfter(weekAgo);
    }).fold(0.0, (sum, a) => sum + ((a['distance_km'] as num?) ?? 0.0));
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final data = await _repo.loadActivities();
    if (!mounted) return;
    setState(() {
      _activities = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12), // Fond sombre tactique
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        centerTitle: true,
        title: const Text('MILFIT COMMAND',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white70),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white70),
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() => _loading = true);
              _loadActivities();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
        onRefresh: _loadActivities,
        child: CustomScrollView(
          slivers: [
            // --- HEADER MODE GHOST ---
            SliverToBoxAdapter(child: _buildStatusHeader()),

            // --- CARTES DE STATS RAPIDES ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _statMiniCard("TOTAL 7J", "${_calculateWeeklyTotal().toStringAsFixed(1)} KM", Colors.orange),
                    const SizedBox(width: 10),
                    _statMiniCard("MISSIONS", "${_activities.length}", Colors.white),
                  ],
                ),
              ),
            ),

            // --- LISTE DES ACTIVITÉS (STYLE STRAVA DARK) ---
            _activities.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                  child: Text('AUCUNE MISSION ENREGISTRÉE',
                      style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold))),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildActivityCard(context, _activities[index]),
                childCount: _activities.length,
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/record'),
        label: const Text('NOUVELLE MISSION',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.white)),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        backgroundColor: const Color(0xFFFF4500),
        elevation: 6,
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _statMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: const Color(0xFF1B3A2D),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]),
      child: const Row(
        children: [
          Icon(Icons.shield, color: Colors.greenAccent, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MODE GHOST ACTIF',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
                SizedBox(height: 2),
                Text('Chiffrement AES-256 opérationnel',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, Map<String, dynamic> activity) {
    final ts = DateTime.parse(activity['timestamp'] as String);
    final sport = activity['sport'] as String? ?? 'run';
    final distance = (activity['distance_km'] as num?)?.toDouble() ?? 0.0;
    final duration = (activity['duration_seconds'] as num?)?.toInt() ?? 0;
    final pace = activity['pace'] as String? ?? '';

    final sportType = SportType.values.firstWhere(
          (s) => s.name == sport,
      orElse: () => SportType.running,
    );

    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    final durationStr = h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min${s.toString().padLeft(2, '0')}s';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/activity', extra: activity),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(sportType.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(sportType.label.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 1)),
                  const Spacer(),
                  const Icon(Icons.lock, color: Colors.greenAccent, size: 14),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${ts.day}/${ts.month}/${ts.year} · ${ts.hour}h${ts.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DashStat(label: 'Distance', value: '${distance.toStringAsFixed(2)} km'),
                  _DashStat(label: 'Durée', value: durationStr),
                  if (pace.isNotEmpty) _DashStat(label: 'Allure', value: '$pace/km'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TON NOUVEAU WIDGET DE STATS ---
class _DashStat extends StatelessWidget {
  final String label;
  final String value;
  const _DashStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}