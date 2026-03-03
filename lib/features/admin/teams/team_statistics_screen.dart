import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/standings.dart';
import '../../../models/team.dart';
import '../../../services/matches_service.dart';
import '../../../services/standings_service.dart';

class TeamStatisticsScreen extends StatefulWidget {
  final Team team;
  final String seasonId;
  final String seasonName;

  const TeamStatisticsScreen({
    super.key,
    required this.team,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<TeamStatisticsScreen> createState() =>
      _TeamStatisticsScreenState();
}

class _TeamStatisticsScreenState
    extends State<TeamStatisticsScreen> {
  final StandingsService _standingsService = StandingsService();
  final MatchesService _matchesService = MatchesService();

  late Future<_TeamStatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_TeamStatsData> _loadData() async {
    final results = await Future.wait([
      _standingsService.getBySeason(
        widget.seasonId,
        categoryId: widget.team.categoryId,
      ),
      _matchesService.getBySeason(
        widget.seasonId,
        categoryId: widget.team.categoryId,
      ),
    ]);

    final standings = results[0] as List<Standing>;
    final matches = results[1] as List<Match>;

    final standing = standings.where((s) => s.teamId == widget.team.id).fold<
            Standing?>(
        null, (previous, element) => previous ?? element);

    final teamMatches = matches.where((match) {
      return match.homeTeamId == widget.team.id ||
          match.awayTeamId == widget.team.id;
    }).toList();

    teamMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));

    return _TeamStatsData(
      standing: standing,
      matches: teamMatches,
      team: widget.team,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Estadisticas - ${widget.team.name}",
      currentIndex: 2,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 2,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      body: FutureBuilder<_TeamStatsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No se pudieron cargar las estadisticas del equipo",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _future = _loadData();
                        });
                      },
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final summary = _TeamSummary.fromData(data);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(title: "Resumen"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: "Partidos jugados",
                    value: "${summary.played}",
                    icon: Icons.sports_soccer,
                  ),
                  _MetricCard(
                    label: "Puntos",
                    value: "${summary.points}",
                    icon: Icons.emoji_events_outlined,
                  ),
                  _MetricCard(
                    label: "Victorias",
                    value: "${summary.wins}",
                    icon: Icons.check_circle_outline,
                  ),
                  _MetricCard(
                    label: "Empates",
                    value: "${summary.draws}",
                    icon: Icons.horizontal_rule,
                  ),
                  _MetricCard(
                    label: "Derrotas",
                    value: "${summary.losses}",
                    icon: Icons.cancel_outlined,
                  ),
                  _MetricCard(
                    label: "Diferencia gol",
                    value: "${summary.goalDifference}",
                    icon: Icons.compare_arrows,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Rendimiento"),
              const SizedBox(height: 12),
              _ChartCard(
                child: Column(
                  children: [
                    _BarStat(
                      label: "Victorias",
                      value: summary.wins,
                      total: summary.played,
                      color: const Color(0xFF22C55E),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "Empates",
                      value: summary.draws,
                      total: summary.played,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "Derrotas",
                      value: summary.losses,
                      total: summary.played,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Goles"),
              const SizedBox(height: 12),
              _ChartCard(
                child: Column(
                  children: [
                    _BarStat(
                      label: "A favor",
                      value: summary.goalsFor,
                      total: summary.goalsFor + summary.goalsAgainst,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "En contra",
                      value: summary.goalsAgainst,
                      total: summary.goalsFor + summary.goalsAgainst,
                      color: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Promedio gol por partido: ${summary.avgGoalsPerMatch}",
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Forma reciente"),
              const SizedBox(height: 12),
              _ChartCard(
                child: summary.recentResults.isEmpty
                    ? const Text(
                        "No hay resultados jugados todavia",
                        style: TextStyle(color: Colors.white70),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: summary.recentResults
                            .map((item) => _ResultChip(item: item))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamStatsData {
  final Team team;
  final Standing? standing;
  final List<Match> matches;

  _TeamStatsData({
    required this.team,
    required this.standing,
    required this.matches,
  });
}

class _RecentResult {
  final String label;
  final Color color;

  _RecentResult({
    required this.label,
    required this.color,
  });
}

class _TeamSummary {
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final String avgGoalsPerMatch;
  final List<_RecentResult> recentResults;

  _TeamSummary({
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.avgGoalsPerMatch,
    required this.recentResults,
  });

  factory _TeamSummary.fromData(_TeamStatsData data) {
    final playedMatches = data.matches.where((m) {
      return m.status.toUpperCase() == 'PLAYED';
    }).toList();

    final standing = data.standing;

    int goalsFor = 0;
    int goalsAgainst = 0;
    int wins = 0;
    int draws = 0;
    int losses = 0;

    for (final match in playedMatches) {
      final isHome = match.homeTeamId == data.team.id;
      final teamGoals = isHome ? match.homeScore : match.awayScore;
      final rivalGoals = isHome ? match.awayScore : match.homeScore;

      goalsFor += teamGoals;
      goalsAgainst += rivalGoals;

      if (teamGoals > rivalGoals) {
        wins++;
      } else if (teamGoals == rivalGoals) {
        draws++;
      } else {
        losses++;
      }
    }

    final safePlayed = standing?.played ?? playedMatches.length;
    final safeWins = standing?.wins ?? wins;
    final safeDraws = standing?.draws ?? draws;
    final safeLosses = standing?.losses ?? losses;
    final safeGoalsFor = standing?.goalsFor ?? goalsFor;
    final safeGoalsAgainst = standing?.goalsAgainst ?? goalsAgainst;
    final points = standing?.points ?? (safeWins * 3 + safeDraws);

    final avgGoals = safePlayed == 0 ? 0.0 : safeGoalsFor / safePlayed;

    final lastFive = playedMatches.reversed.take(5).toList().reversed.toList();
    final recent = lastFive.map((match) {
      final isHome = match.homeTeamId == data.team.id;
      final teamGoals = isHome ? match.homeScore : match.awayScore;
      final rivalGoals = isHome ? match.awayScore : match.homeScore;

      final resultLabel = teamGoals > rivalGoals
          ? 'V'
          : teamGoals == rivalGoals
              ? 'E'
              : 'D';

      final color = teamGoals > rivalGoals
          ? const Color(0xFF22C55E)
          : teamGoals == rivalGoals
              ? const Color(0xFFF59E0B)
              : const Color(0xFFEF4444);

      return _RecentResult(
        label: "$resultLabel  $teamGoals-$rivalGoals",
        color: color,
      );
    }).toList();

    return _TeamSummary(
      played: safePlayed,
      wins: safeWins,
      draws: safeDraws,
      losses: safeLosses,
      points: points,
      goalsFor: safeGoalsFor,
      goalsAgainst: safeGoalsAgainst,
      goalDifference: safeGoalsFor - safeGoalsAgainst,
      avgGoalsPerMatch: avgGoals.toStringAsFixed(2),
      recentResults: recent,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0F172A),
      ),
      child: child,
    );
  }
}

class _BarStat extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _BarStat({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : value / total;
    final percentLabel = "${(percent * 100).toStringAsFixed(0)}%";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text("$value ($percentLabel)"),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent.clamp(0, 1).toDouble(),
            minHeight: 10,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final _RecentResult item;

  const _ResultChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: item.color.withValues(alpha: 0.18),
        border: Border.all(
          color: item.color.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        item.label,
        style: TextStyle(
          color: item.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
