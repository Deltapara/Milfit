import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/storage/activity_repository.dart';
import '../../shared/models/sport_type.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ActivityRepository();
  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  String _name = 'Militaire';
  String _grade = 'Soldat';
  bool _editingName = false;
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final data = await _repo.loadActivities();
    final name = await _storage.read(key: 'profile_name') ?? 'Militaire';
    final grade = await _storage.read(key: 'profile_grade') ?? 'Soldat';
    if (!mounted) return;
    setState(() {
      _activities = data;
      _name = name;
      _grade = grade;
      _nameController.text = name;
      _gradeController.text = grade;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    await _storage.write(key: 'profile_name', value: _nameController.text.trim());
    await _storage.write(key: 'profile_grade', value: _gradeController.text.trim());
    setState(() {
      _name = _nameController.text.trim();
      _grade = _gradeController.text.trim();
      _editingName = false;
    });
  }

  // --- CALCULS STATS ---

  double get _totalKm => _activities.fold(
      0.0, (s, a) => s + ((a['distance_km'] as num?) ?? 0.0));

  int get _totalSeconds => _activities.fold(
      0, (s, a) => s + ((a['duration_seconds'] as int?) ?? 0));

  double get _bestDistance => _activities.isEmpty
      ? 0.0
      : _activities
      .map((a) => (a['distance_km'] as num?)?.toDouble() ?? 0.0)
      .reduce((a, b) => a > b ? a : b);

  Map<SportType, double> get _kmBySport {
    final map = <SportType, double>{};
    for (final a in _activities) {
      final sport = SportType.values.firstWhere(
            (s) => s.name == (a['sport'] as String? ?? ''),
        orElse: () => SportType.running,
      );
      map[sport] = (map[sport] ?? 0) +
          ((a['distance_km'] as num?)?.toDouble() ?? 0.0);
    }
    return map;
  }

  /// Distance par semaine sur les 4 dernières semaines
  List<double> get _weeklyKm {
    final now = DateTime.now();
    return List.generate(4, (i) {
      final start = now.subtract(Duration(days: (3 - i) * 7 + 7));
      final end = now.subtract(Duration(days: (3 - i) * 7));
      return _activities
          .where((a) {
        final ts = DateTime.tryParse(a['timestamp'] as String? ?? '');
        if (ts == null) return false;
        return ts.isAfter(start) && ts.isBefore(end);
      })
          .fold(0.0, (s, a) => s + ((a['distance_km'] as num?) ?? 0.0));
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        centerTitle: true,
        title: const Text('MON PROFIL',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white70, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: Icon(
                _editingName ? Icons.check : Icons.edit,
                color: _editingName ? Colors.greenAccent : Colors.white70),
            onPressed: _editingName ? _saveProfile : () => setState(() => _editingName = true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIdentityCard(),
            const SizedBox(height: 16),
            _buildStatsGrid(),
            const SizedBox(height: 16),
            _buildWeeklyChart(),
            const SizedBox(height: 16),
            _buildSportBreakdown(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- CARTE IDENTITÉ ---
  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3A2D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.greenAccent, width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _editingName
                ? Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                  decoration: const InputDecoration(
                    hintText: 'Nom',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
                TextField(
                  controller: _gradeController,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Grade',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ],
            )
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(height: 4),
                Text(_grade,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shield,
                        color: Colors.greenAccent, size: 12),
                    const SizedBox(width: 4),
                    Text('${_activities.length} missions',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- GRILLE DE STATS ---
  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _StatTile(
          label: 'DISTANCE TOTALE',
          value: '${_totalKm.toStringAsFixed(1)} km',
          icon: Icons.straighten,
          color: const Color(0xFFFF4500),
        ),
        _StatTile(
          label: 'TEMPS TOTAL',
          value: _formatDuration(_totalSeconds),
          icon: Icons.timer,
          color: Colors.blueAccent,
        ),
        _StatTile(
          label: 'MISSIONS',
          value: '${_activities.length}',
          icon: Icons.flag,
          color: Colors.greenAccent,
        ),
        _StatTile(
          label: 'RECORD DISTANCE',
          value: '${_bestDistance.toStringAsFixed(2)} km',
          icon: Icons.emoji_events,
          color: Colors.amber,
        ),
      ],
    );
  }

  // --- GRAPHIQUE HEBDOMADAIRE ---
  Widget _buildWeeklyChart() {
    final weeks = _weeklyKm;
    final maxKm = weeks.isEmpty ? 1.0 : weeks.reduce((a, b) => a > b ? a : b);
    final labels = ['S-3', 'S-2', 'S-1', 'Cette S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACTIVITÉ 4 SEMAINES',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final km = weeks[i];
              final ratio = maxKm > 0 ? km / maxKm : 0.0;
              final isCurrentWeek = i == 3;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text('${km.toStringAsFixed(1)}',
                          style: TextStyle(
                              color: isCurrentWeek
                                  ? const Color(0xFFFF4500)
                                  : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        height: 80 * ratio + 4,
                        decoration: BoxDecoration(
                          color: isCurrentWeek
                              ? const Color(0xFFFF4500)
                              : const Color(0xFF3A3A5C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i],
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          const Text('km par semaine',
              style: TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }

  // --- RÉPARTITION PAR SPORT ---
  Widget _buildSportBreakdown() {
    final breakdown = _kmBySport;
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final total = breakdown.values.fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RÉPARTITION PAR SPORT',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          ...breakdown.entries.map((entry) {
            final pct = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(entry.key.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(entry.key.label,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${entry.value.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFF2A2A3E),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF4500)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}