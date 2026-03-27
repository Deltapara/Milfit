import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/activity_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ActivityRepository();
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;

  double _calculateWeeklyTotal() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities
        .where((a) => DateTime.parse(a['timestamp']).isAfter(weekAgo))
        .fold(0.0, (sum, a) => sum + (a['distance'] ?? 0.0));
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
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
            'MILFIT COMMAND',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 16
            )
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.black),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              setState(() => _loading = true);
              _loadActivities();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B3A2D)))
          : RefreshIndicator(
        onRefresh: _loadActivities,
        child: CustomScrollView(
          slivers: [
            // --- SECTION STATUT SÉCURITÉ ---
            SliverToBoxAdapter(child: _buildStatusHeader()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _statMiniCard("TOTAL 7J", "${_calculateWeeklyTotal().toStringAsFixed(1)} KM", Colors.orange[900]!),
                    const SizedBox(width: 10),
                    _statMiniCard("MISSIONS", "${_activities.length}", Colors.black),
                  ],
                ),
              ),
            ),

            // --- LISTE DES ACTIVITÉS ---
            _activities.isEmpty
                ? const SliverFillRemaining(
              child: Center(
                  child: Text(
                      'AUCUNE MISSION ENREGISTRÉE',
                      style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)
                  )
              ),
            )
                : SliverList(
              delegate: SliverChildBuilderDelegate(
                // CORRECTION ICI : Ajout du context dans l'appel
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
        label: const Text(
            'NOUVELLE MISSION',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)
        ),
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        backgroundColor: const Color(0xFFFF4500),
        elevation: 6,
      ),
    );
  }

  Widget _statMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
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
          color: const Color(0xFF1B3A2D), // Vert militaire profond
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.greenAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                    'MODE GHOST ACTIF',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
                ),
                SizedBox(height: 2),
                Text(
                    'Chiffrement AES-256 & Fuzzing GPS opérationnels',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, Map<String, dynamic> activity) {
    final sport = activity['sport_type'] ?? 'run';
    final distance = (activity['distance'] ?? 0.0) as double;
    final timestamp = DateTime.parse(activity['timestamp']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: ListTile(
        onTap: () => context.push('/activity', extra: activity),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: sport == 'run' ? Colors.orange[50] : Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            sport == 'run' ? Icons.directions_run : Icons.directions_bike,
            color: sport == 'run' ? Colors.orange[900] : Colors.blue[900],
            size: 26,
          ),
        ),
        title: Text(
          sport == 'run' ? "COURSE À PIED" : "SORTIE VÉLO",
          style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            "${timestamp.day}/${timestamp.month}/${timestamp.year} • ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${distance.toStringAsFixed(2)}",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const Text(
              "KM",
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}