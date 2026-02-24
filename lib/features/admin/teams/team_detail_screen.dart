import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/team.dart';
import '../players/players_list_screen.dart';
import 'team_statistics_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;
  final String seasonId;

  const TeamDetailScreen({
    super.key,
    required this.team,
    required this.seasonId,
  });

  @override
  State<TeamDetailScreen> createState() =>
      _TeamDetailScreenState();
}

class _TeamDetailScreenState
    extends State<TeamDetailScreen> {
  int _navIndex = 0;

  void _onNavTap(int index) {
    setState(() {
      _navIndex = index;
    });

    // Example navigation
    if (index == 0) {
      Navigator.pop(context);
    }
  }

  Widget _buildBody() {
    final logo = _buildTeamLogo(widget.team.logoUrl);

    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white10,
                foregroundImage: logo,
                onForegroundImageError:
                    logo != null ? (_, _) {} : null,
                child: const Icon(Icons.shield, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.team.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Menu de gestion del equipo",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.team.logoUrl?.trim().isNotEmpty == true
                          ? widget.team.logoUrl!
                          : "Sin logo_url",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _menuCard(
          icon: Icons.groups_rounded,
          title: "Jugadores",
          subtitle: "Plantilla, detalle y altas",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PlayersListScreen(team: widget.team),
              ),
            );
          },
        ),
        _menuCard(
          icon: Icons.sports_soccer,
          title: "Partidos",
          subtitle: "Calendario y resultados",
          onTap: () => _showSoon("Partidos"),
        ),
        _menuCard(
          icon: Icons.query_stats_rounded,
          title: "Estadisticas",
          subtitle: "Rendimiento del equipo",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamStatisticsScreen(
                  team: widget.team,
                  seasonId: widget.seasonId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white10,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSoon(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$moduleName estara disponible proximamente",
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildTeamLogo(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: widget.team.name,
      currentIndex: _navIndex,
      onNavTap: _onNavTap,
      body: _buildBody(),
    );
  }
}
