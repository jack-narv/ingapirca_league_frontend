import 'package:flutter/material.dart';
import 'package:ingapirca_league_frontend/features/home/home_screen.dart';
import 'package:ingapirca_league_frontend/features/auth/login_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const IngaPircaLeagueApp());
}

class IngaPircaLeagueApp extends StatelessWidget {
  const IngaPircaLeagueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ingapirca League',
      theme: AppTheme.darkTheme,
      home: const _SessionGateScreen(),
    );
  }
}

class _SessionGateScreen extends StatefulWidget {
  const _SessionGateScreen();

  @override
  State<_SessionGateScreen> createState() => _SessionGateScreenState();
}

class _SessionGateScreenState extends State<_SessionGateScreen> {
  final AuthService _authService = AuthService();
  late final Future<bool> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _authService.hasValidSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasSession = snapshot.data == true;
        return hasSession ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
