import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingapirca_league_frontend/features/home/home_screen.dart';
import 'package:ingapirca_league_frontend/features/auth/login_screen.dart';
import 'package:ingapirca_league_frontend/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final AppUpdateService _appUpdateService = AppUpdateService();
  late final Future<_StartupDecision> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = _buildStartupDecision();
  }

  Future<_StartupDecision> _buildStartupDecision() async {
    final updateResult = await _appUpdateService.checkForceUpdate();
    if (updateResult.required) {
      return _StartupDecision(
        hasSession: false,
        forceUpdate: updateResult,
      );
    }

    final hasSession = await _authService.hasValidSession();
    return _StartupDecision(hasSession: hasSession);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupDecision>(
      future: _startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final startup = snapshot.data;
        if (startup?.forceUpdate != null) {
          return _ForceUpdateScreen(result: startup!.forceUpdate!);
        }

        final hasSession = startup?.hasSession == true;
        return hasSession ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

class _StartupDecision {
  const _StartupDecision({
    required this.hasSession,
    this.forceUpdate,
  });

  final bool hasSession;
  final ForceUpdateResult? forceUpdate;
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.result});

  final ForceUpdateResult result;

  Future<void> _openStore() async {
    final url = result.storeUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _closeApp() async {
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update, size: 72),
                    const SizedBox(height: 16),
                    const Text(
                      'Actualizacion requerida',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tu version (${result.currentVersion}) esta desactualizada. '
                      'Debes actualizar a la version ${result.requiredVersion} para continuar.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openStore,
                        child: const Text('Actualizar ahora'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _closeApp,
                        child: const Text('Cerrar app'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
