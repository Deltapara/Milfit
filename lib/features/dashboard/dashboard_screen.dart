import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MILFIT COMMAND"),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => context.go('/login'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      // ----------------------------
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            const Center(child: Text("Aucune activité récente")),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/record'),
        label: const Text("NOUVELLE MISSION"),
        icon: const Icon(Icons.add_location_alt),
        backgroundColor: const Color(0xFF1B3A2D),
      ),
    );
  }

  Widget _buildStatusCard() {
    return const Card(
      color: Colors.black45,
      child: ListTile(
        leading: Icon(Icons.security, color: Colors.green),
        title: Text("Système Ghost Track : ACTIF"),
        subtitle: Text("Localisation brouillée (Rayon 500m)"),
      ),
    );
  }
}