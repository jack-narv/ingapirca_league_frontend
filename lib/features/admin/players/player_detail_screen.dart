import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/player.dart';
import '../../../services/players_service.dart';

class PlayerDetailScreen extends StatefulWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  State<PlayerDetailScreen> createState() =>
      _PlayerDetailScreenState();
}

class _PlayerDetailScreenState
    extends State<PlayerDetailScreen> {
  final PlayersService _service = PlayersService();
  late Future<Player> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPlayer(widget.playerId);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Detalle Jugador",
      currentIndex: 0,
      onNavTap: (_) {},
      body: FutureBuilder<Player>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "No se pudo cargar el jugador",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                "Jugador no encontrado",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final player = snapshot.data!;
          final currentTeam = player.teamInfo.isNotEmpty
              ? player.teamInfo.first
              : null;
          final initial = player.firstName.isNotEmpty
              ? player.firstName[0]
              : "?";
          final photo = _buildPhoto(player.photoUrl);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        foregroundImage: photo,
                        onForegroundImageError:
                            photo != null ? (_, _) {} : null,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${player.firstName} ${player.lastName}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              player.nationality,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Perfil Deportivo",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoChip(
                      icon: Icons.confirmation_num_outlined,
                      label: "Camiseta",
                      value: currentTeam != null
                          ? "#${currentTeam.shirtNumber}"
                          : "--",
                    ),
                    _infoChip(
                      icon: Icons.sports_soccer_outlined,
                      label: "Posicion",
                      value: currentTeam?.position.isNotEmpty == true
                          ? currentTeam!.position
                          : "--",
                    ),
                    _infoChip(
                      icon: Icons.shield_outlined,
                      label: "Equipo",
                      value: currentTeam?.teamName.isNotEmpty == true
                          ? currentTeam!.teamName
                          : "Sin equipo",
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Text(
                      "Estadisticas",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 10),
                    _SoonBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  children: const [
                    _StatTile(
                      label: "Partidos",
                      value: "--",
                      icon: Icons.sports,
                    ),
                    _StatTile(
                      label: "Goles",
                      value: "--",
                      icon: Icons.sports_soccer,
                    ),
                    _StatTile(
                      label: "Tarjetas",
                      value: "--",
                      icon: Icons.style_outlined,
                    ),
                    _StatTile(
                      label: "Suspensiones",
                      value: "--",
                      icon: Icons.block_outlined,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            "$label: $value",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _buildPhoto(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(value);
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        "Proximamente",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
