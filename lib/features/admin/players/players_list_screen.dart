import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/team.dart';
import '../../../services/players_service.dart';
import 'create_player_screen.dart';
import 'player_detail_screen.dart';
import '../../../services/auth_service.dart';
import '../../../models/team_player.dart';

class PlayersListScreen extends StatefulWidget {
  final Team team;
  const PlayersListScreen({
      super.key,
      required this.team
    });

  @override
  State<PlayersListScreen> createState() => _PlayersListScreenState();
}

class _PlayersListScreenState extends State<PlayersListScreen> {
  final PlayersService _service = PlayersService();
  late Future<List<TeamPlayer>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _playersFuture = _service.getByTeam(widget.team.id);
  }

  void _refresh() {
    setState(() {
      _playersFuture = _service.getByTeam(widget.team.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Jugadores - ${widget.team.name}",
      currentIndex: 0,
      onNavTap: (_) {},
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService().isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!) {
            return const SizedBox();
          }

          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePlayerScreen(
                    teamId: widget.team.id,
                  ),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.person_add),
          );
        },
      ),
      body: FutureBuilder<List<TeamPlayer>>(
        future: _playersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No hay jugadores en este equipo",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final teamPlayers = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: teamPlayers.length,
            itemBuilder: (context, index) {
              final teamPlayer = teamPlayers[index];
              final player = teamPlayer.player;
              final playerId = teamPlayer.playerId;
              final initial = player.firstName.isNotEmpty
                  ? player.firstName[0]
                  : "?";
              final photo = _buildPhoto(player.photoUrl);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  try {
                    if (playerId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("El jugador no tiene ID valido"),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerDetailScreen(playerId: playerId),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Error abriendo detalle: $e",
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF0F172A),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
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
                              color:
                                  Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _badge(teamPlayer.position,
                                      Colors.blue),
                                  const SizedBox(width: 8),
                                  _badge(
                                      "#${teamPlayer.shirtNumber}",
                                      Colors.green),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 14),
                      ],
                    ),
                  ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ImageProvider<Object>? _buildPhoto(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(value);
  }
}
