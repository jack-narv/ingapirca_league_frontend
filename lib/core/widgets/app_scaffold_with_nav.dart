import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';
import '../../services/auth_service.dart';

class AppScaffoldWithNav extends StatelessWidget {
  final String title;
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget? floatingActionButton;

  const AppScaffoldWithNav({
    super.key,
    required this.title,
    required this.body,
    required this.currentIndex,
    required this.onNavTap,
    this.floatingActionButton,
  });

  void _logout(BuildContext rootContext) {
    final authService = AuthService();

    showDialog(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Cerrar sesion"),
        content: const Text("Estas seguro que deseas salir?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              await authService.logout();
              if (!rootContext.mounted) return;
              Navigator.pushAndRemoveUntil(
                rootContext,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text("Salir"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          color: Color(0xFF0F172A),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.white54,
          currentIndex: currentIndex,
          onTap: onNavTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: "Inicio",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Perfil",
            ),
          ],
        ),
      ),
    );
  }
}
