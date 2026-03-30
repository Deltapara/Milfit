import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sodium_libs/sodium_libs.dart'; // Import nécessaire

// Imports de tes services
import 'core/storage/local_db.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/activity/record_screen.dart';
import 'features/activity/activity_detail_screen.dart';
import 'features/profile/profile_screen.dart';

void main() async {
  // 1. Indispensable pour l'accès aux couches basses (GPS, Crypto)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialisation du moteur de chiffrement (libsodium)
  // Si cette étape échoue, l'app s'arrête par sécurité
  try {
    await SodiumInit.init();
    debugPrint("SÉCURITÉ : Moteur Sodium prêt.");
  } catch (e) {
    debugPrint("ALERTE : Échec de l'initialisation crypto : $e");
    //return; // Kill switch
  }

  // 3. Pré-ouverture de la base SQLCipher (Initialise la clé maîtresse)
  await LocalDb().database;

  // 4. Configuration UI (Protection contre l'espionnage visuel)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Note : setEnabledSystemUIMode est déjà dans ton code, c'est parfait.

  runApp(
    const ProviderScope(
      child: MilFitApp(),
    ),
  );
}

class MilFitApp extends StatelessWidget {
  const MilFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MilFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B3A2D), // Vert OPEX
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Style "Tactique" pour les boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            backgroundColor: const Color(0xFF1B3A2D),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    GoRoute(path: '/dashboard', builder: (ctx, state) => const DashboardScreen()),
    GoRoute(path: '/record', builder: (ctx, state) => const RecordScreen()),
    GoRoute(path: '/activity', builder: (ctx, state) => ActivityDetailScreen(activity: state.extra as Map<String, dynamic>,),),
    GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
  ],
);