import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:tower_defense/data/repositories/account_progress_repository.dart';
import 'package:tower_defense/domain/progress/account_progress.dart';
import 'package:tower_defense/shared/audio_service.dart';
import 'package:tower_defense/ui/screens/game_screen.dart';
import 'package:tower_defense/ui/screens/lobby_screen.dart';
import 'package:tower_defense/ui/screens/login_screen.dart';
import 'package:tower_defense/ui/screens/nickname_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  if (kDebugMode) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  } else {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }
  runApp(const TowerDefenseApp());
}

class TowerDefenseApp extends StatefulWidget {
  const TowerDefenseApp({super.key});

  @override
  State<TowerDefenseApp> createState() => _TowerDefenseAppState();
}

class _TowerDefenseAppState extends State<TowerDefenseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(AppAudioService.instance.stopBgm());
      unawaited(AppAudioService.instance.stopAllSfx());
    }
  }

  Widget _buildGameScreen({
    required String difficultyId,
    required String stageId,
    required AccountProgress progress,
    required bool showDamage,
    required VoidCallback onExit,
  }) {
    return GameScreen(
      difficultyId: difficultyId,
      stageId: stageId,
      progress: progress,
      showDamage: showDamage,
      onExit: onExit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tower Defense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B3B42)),
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF07111F),
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF8FD3FF),
                  ),
                ),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return LoginScreen(
              gameScreenBuilder: _buildGameScreen,
            );
          }

          return _AuthenticatedEntry(
            gameScreenBuilder: _buildGameScreen,
          );
        },
      ),
    );
  }
}

class _AuthenticatedEntry extends StatelessWidget {
  final LoginGameScreenBuilder gameScreenBuilder;

  const _AuthenticatedEntry({
    required this.gameScreenBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final progressRepo = AccountProgressRepository();
    return FutureBuilder<AccountProgress>(
      future: progressRepo.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF07111F),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF8FD3FF),
                ),
              ),
            ),
          );
        }

        final progress = snapshot.data;
        if (progress == null || progress.nickname.trim().isEmpty) {
          return LoginScreen(
            gameScreenBuilder: gameScreenBuilder,
          );
        }

        return LobbyScreen(
          gameScreenBuilder: gameScreenBuilder,
          initialProgress: progress,
        );
      },
    );
  }
}
