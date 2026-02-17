import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/team.dart';
import '../../../models/team_player.dart';
import '../../../services/players_service.dart';
import '../../../services/auth_service.dart';
import '../players/create_player_screen.dart';
import '../players/player_detail_screen.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;

  const TeamDetailScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailScreen> createState() =>
      _TeamDetailScreenState();
}

class _TeamDetailScreenState
    extends State<TeamDetailScreen> {
  final PlayersService _service = PlayersService();
  late Future<List<TeamPlayer>> _playersFuture;

  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _playersFuture =
        _service.getByTeam(widget.team.id);
  }

  void _refresh() {
    setState(() {
      _playersFuture =
          _service.getByTeam(widget.team.id);
    });
  }

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
    return FutureBuilder<List<TeamPlayer>>(
      future: _playersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        if (!snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "No hay jugadores en este equipo",
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          );
        }

        final players = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.only(
              top: 20, bottom: 100),
          children: players
              .map((p) => _buildPlayerCard(p))
              .toList(),
        );
      },
    );
  }

  Widget _buildPlayerCard(TeamPlayer teamPlayer) {
      final player = teamPlayer.player;
      final playerId = teamPlayer.playerId;
      final initial = player.firstName.isNotEmpty
          ? player.firstName[0]
          : "?";

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (playerId.isEmpty) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PlayerDetailScreen(playerId: playerId),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white10,
                child: Text(
                  initial,
                  style: const TextStyle(
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _badge(
                            teamPlayer.position,
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
            ],
          ),
        ),
      );
    }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(20),
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

  Widget? _buildFab() {
    return FutureBuilder<bool>(
      future: AuthService().isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data == false) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton(
          backgroundColor:
              Theme.of(context).colorScheme.primary,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: widget.team.name,
      currentIndex: _navIndex,
      onNavTap: _onNavTap,
      floatingActionButton: _buildFab(),
      body: _buildBody(),
    );
  }
}
