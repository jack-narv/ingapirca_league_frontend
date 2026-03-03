import 'package:flutter/material.dart';
import '../../core/widgets/app_scaffold_with_nav.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../admin/leagues/leagues_list_screen.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final AuthService _authService = AuthService();
  late Future<Map<String, String>> _profileFuture;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _profileFuture = _loadProfileData();
  }

  Future<Map<String, String>> _loadProfileData() async {
    final token = await _authService.getToken();
    if (token == null || token.trim().isEmpty) {
      return {
        'fullName': 'Usuario',
        'email': 'No disponible',
      };
    }

    final parts = token.split('.');
    if (parts.length != 3) {
      return {
        'fullName': 'Usuario',
        'email': 'No disponible',
      };
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return {
          'fullName': 'Usuario',
          'email': 'No disponible',
        };
      }

      final fullNameRaw = (decoded['full_name'] ?? decoded['name'] ?? '').toString().trim();
      final email = (decoded['email'] ?? '').toString().trim();

      return {
        'fullName': fullNameRaw.isNotEmpty ? fullNameRaw : _nameFromEmail(email),
        'email': email.isNotEmpty ? email : 'No disponible',
      };
    } catch (_) {
      return {
        'fullName': 'Usuario',
        'email': 'No disponible',
      };
    }
  }

  String _nameFromEmail(String email) {
    if (email.trim().isEmpty) return 'Usuario';
    final localPart = email.split('@').first;
    final words = localPart
        .replaceAll('.', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .toList();
    return words.isEmpty ? 'Usuario' : words.join(' ');
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deletingAccount) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta accion eliminara tu cuenta. Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await _authService.deleteAccount();
      await _authService.logout();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta eliminada correctamente')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final message = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Widget _buildDashboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bienvenido",
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ListView(
              children: [
                _MainDashboardCard(
                  title: "Campeonatos",
                  subtitle: "Gestiona ligas y temporadas",
                  icon: Icons.emoji_events,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminLeaguesListScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return FutureBuilder<Map<String, String>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data ?? const {
          'fullName': 'Usuario',
          'email': 'No disponible',
        };

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF1E293B),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perfil de usuario',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nombre completo',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile['fullName'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Correo',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile['email'] ?? 'No disponible',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deletingAccount ? null : _confirmDeleteAccount,
                      icon: _deletingAccount
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline, color: Colors.redAccent),
                      label: Text(
                        _deletingAccount ? 'Eliminando...' : 'Eliminar cuenta',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildProfile(),
    ];

    return AppScaffoldWithNav(
      title: "Ingapirca App",
      body: pages[_currentIndex],
      currentIndex: _currentIndex,
      onNavTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }
}

class _MainDashboardCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MainDashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  State<_MainDashboardCard> createState() => _MainDashboardCardState();
}

class _MainDashboardCardState extends State<_MainDashboardCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
