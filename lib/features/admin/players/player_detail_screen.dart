import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/player.dart';
import '../../../models/match_event.dart';
import '../../../models/match_lineup.dart';
import '../../../models/player_statistics.dart';
import '../../../services/match_events_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/player_statistics_service.dart';
import '../../../services/players_service.dart';

class PlayerDetailScreen extends StatefulWidget {
  final String playerId;
  final String seasonId;
  final String seasonName;
  final String? teamId;

  const PlayerDetailScreen({
    super.key,
    required this.playerId,
    required this.seasonId,
    required this.seasonName,
    this.teamId,
  });

  @override
  State<PlayerDetailScreen> createState() =>
      _PlayerDetailScreenState();
}

class _PlayerDetailScreenState
    extends State<PlayerDetailScreen> {
  final PlayersService _service = PlayersService();
  final MatchesService _matchesService = MatchesService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final MatchEventsService _eventsService = MatchEventsService();
  final PlayerStatisticsService _playerStatisticsService =
      PlayerStatisticsService();
  late Future<_PlayerDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadPlayerDetailData();
  }

  Future<_PlayerDetailData> _loadPlayerDetailData() async {
    final player = await _service.getPlayer(widget.playerId);
    final stats = await _loadPlayerStats(player);
    return _PlayerDetailData(player: player, stats: stats);
  }

  Future<_PlayerStats> _loadPlayerStats(Player player) async {
    final fallbackTeamId =
        player.teamInfo.isNotEmpty ? player.teamInfo.first.teamId : null;
    final teamId = widget.teamId ?? fallbackTeamId;
    if (teamId == null || teamId.isEmpty) {
      return const _PlayerStats.empty();
    }

    final derivedStats = await _loadDerivedStatsFromMatches(
      player: player,
      teamId: teamId,
    );

    try {
      final stats = await _playerStatisticsService.getByPlayerSeason(
        player.id,
        widget.seasonId,
      );
      return derivedStats.applySeasonStatistics(stats);
    } catch (_) {
      return derivedStats;
    }
  }

  Future<_PlayerStats> _loadDerivedStatsFromMatches({
    required Player player,
    required String teamId,
  }) async {
    final seasonMatches = await _matchesService.getBySeason(widget.seasonId);
    final teamMatches = seasonMatches
        .where(
          (m) => m.homeTeamId == teamId || m.awayTeamId == teamId,
        )
        .toList()
      ..sort((a, b) => a.matchDate.compareTo(b.matchDate));

    int matchesPlayed = 0;
    int starts = 0;
    int goals = 0;
    int ownGoals = 0;
    int yellowCards = 0;
    int redCards = 0;
    int subIns = 0;
    int subOuts = 0;

    for (final match in teamMatches) {
      MatchLineupPlayer? lineupPlayer;
      List<MatchEvent> events = const [];

      try {
        final lineup = await _lineupsService.getLineup(match.id, teamId);
        for (final playerLineup in lineup) {
          if (playerLineup.playerId == player.id) {
            lineupPlayer = playerLineup;
            break;
          }
        }
      } catch (_) {
        // Best effort if lineup endpoint fails for this match.
      }

      try {
        events = await _eventsService.getTimeline(match.id);
      } catch (_) {
        // Best effort if events endpoint fails for this match.
      }

      final playerEvents = events
          .where((event) => event.playerId == player.id)
          .toList();

      final hasEventParticipation = playerEvents.any((event) {
        final type = event.eventType.toUpperCase();
        return type == 'GOAL' ||
            type == 'OWN_GOAL' ||
            type == 'YELLOW' ||
            type == 'YELLOW_CARD' ||
            type == 'RED' ||
            type == 'RED_CARD' ||
            type == 'SUB_IN' ||
            type == 'SUB_OUT';
      });

      final playedThisMatch =
          match.status.toUpperCase() == 'PLAYED' &&
          (lineupPlayer != null || hasEventParticipation);

      if (playedThisMatch) {
        matchesPlayed++;
      }
      if (lineupPlayer?.isStarting == true) {
        starts++;
      }

      for (final event in playerEvents) {
        switch (event.eventType.toUpperCase()) {
          case 'GOAL':
            goals++;
            break;
          case 'OWN_GOAL':
            ownGoals++;
            break;
          case 'YELLOW':
          case 'YELLOW_CARD':
            yellowCards++;
            break;
          case 'RED':
          case 'RED_CARD':
            redCards++;
            break;
          case 'SUB_IN':
            subIns++;
            break;
          case 'SUB_OUT':
            subOuts++;
            break;
          default:
            break;
        }
      }
    }

    final totalCards = yellowCards + redCards;
    final suspensions = redCards;

    return _PlayerStats(
      matchesPlayed: matchesPlayed,
      starts: starts,
      goals: goals,
      assists: 0,
      ownGoals: ownGoals,
      yellowCards: yellowCards,
      redCards: redCards,
      totalCards: totalCards,
      suspensions: suspensions,
      subIns: subIns,
      subOuts: subOuts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Detalle Jugador",
      currentIndex: 2,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 2,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      body: FutureBuilder<_PlayerDetailData>(
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
                "No se pudo cargar el jugador y sus estadisticas",
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

          final detail = snapshot.data!;
          final player = detail.player;
          final stats = detail.stats;
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
                        color: Colors.black.withValues(alpha: 0.45),
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
                            .withValues(alpha: 0.2),
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
                const Text(
                  "Estadisticas",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  children: [
                    _StatTile(
                      label: "Partidos",
                      value: "${stats.matchesPlayed}",
                      icon: Icons.sports,
                    ),
                    _StatTile(
                      label: "Goles",
                      value: "${stats.goals}",
                      icon: Icons.sports_soccer,
                    ),
                    _StatTile(
                      label: "Tarjetas",
                      value: "${stats.totalCards}",
                      icon: Icons.style_outlined,
                    ),
                    _StatTile(
                      label: "Suspensiones",
                      value: "${stats.suspensions}",
                      icon: Icons.block_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF1A2332),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      _miniStat("Titular", stats.starts),
                      _miniStat("Asistencias", stats.assists),
                      _miniStat("Autogoles", stats.ownGoals),
                      _miniStat("Amarillas", stats.yellowCards),
                      _miniStat("Rojas", stats.redCards),
                      _miniStat("Sub In", stats.subIns),
                      _miniStat("Sub Out", stats.subOuts),
                    ],
                  ),
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

  Widget _miniStat(String label, int value) {
    return Text(
      "$label: $value",
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ImageProvider<Object>? _buildPhoto(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(value);
  }
}

class _PlayerDetailData {
  final Player player;
  final _PlayerStats stats;

  _PlayerDetailData({
    required this.player,
    required this.stats,
  });
}

class _PlayerStats {
  final int matchesPlayed;
  final int starts;
  final int goals;
  final int assists;
  final int ownGoals;
  final int yellowCards;
  final int redCards;
  final int totalCards;
  final int suspensions;
  final int subIns;
  final int subOuts;

  const _PlayerStats({
    required this.matchesPlayed,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.ownGoals,
    required this.yellowCards,
    required this.redCards,
    required this.totalCards,
    required this.suspensions,
    required this.subIns,
    required this.subOuts,
  });

  const _PlayerStats.empty()
      : matchesPlayed = 0,
        starts = 0,
        goals = 0,
        assists = 0,
        ownGoals = 0,
        yellowCards = 0,
        redCards = 0,
        totalCards = 0,
        suspensions = 0,
        subIns = 0,
        subOuts = 0;

  _PlayerStats applySeasonStatistics(PlayerStatistics stats) {
    return _PlayerStats(
      matchesPlayed: matchesPlayed,
      starts: starts,
      goals: stats.goals,
      assists: stats.assists,
      ownGoals: ownGoals,
      yellowCards: stats.yellowCards,
      redCards: stats.redCards,
      totalCards: stats.totalCards,
      suspensions: stats.redCards,
      subIns: subIns,
      subOuts: subOuts,
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
            color: Colors.black.withValues(alpha: 0.25),
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
