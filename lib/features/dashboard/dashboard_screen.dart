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
      appBar: AppBar(
        title: const Text('MILFIT COMMAND'),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadActivities();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _activities.isEmpty
                ? const Center(
              child: Text(
                'Aucune activité enregistrée',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final a = _activities[index];
                final ts = DateTime.parse(a['timestamp'] as String);
                final count = a['count'] as int;
                return ListTile(
                  onTap: () => context.go('/activity', extra: a),
                  leading: const Icon(
                    Icons.lock,
                    color: Colors.green,
                    size: 18,
                  ),
                  title: Text(
                    '${ts.day}/${ts.month}/${ts.year} '
                        '${ts.hour.toString().padLeft(2, '0')}:'
                        '${ts.minute.toString().padLeft(2, '0')}',
                  ),
                  subtitle: Text('$count points GPS · chiffré AES-256'),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/record'),
        label: const Text('NOUVELLE MISSION'),
        icon: const Icon(Icons.add_location_alt),
        backgroundColor: const Color(0xFF1B3A2D),
      ),
    );
  }

  Widget _buildStatusCard() {
    return const Card(
      margin: EdgeInsets.all(12),
      color: Colors.black45,
      child: ListTile(
        leading: Icon(Icons.security, color: Colors.green),
        title: Text('Ghost Track : ACTIF'),
        subtitle: Text('Localisation brouillée · Base chiffrée AES-256'),
      ),
    );
  }
}