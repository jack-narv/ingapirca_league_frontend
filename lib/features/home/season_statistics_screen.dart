import 'package:flutter/material.dart';
import '../../core/widgets/app_scaffold_with_nav.dart';
import '../../models/match.dart';
import '../../models/season.dart';
import '../../models/season_category.dart';
import '../../models/team.dart';
import '../../services/matches_service.dart';
import '../../services/seasons_service.dart';
import '../../services/teams_service.dart';

class SeasonStatisticsScreen extends StatefulWidget {
  final Season season;

  const SeasonStatisticsScreen({
    super.key,
    required this.season,
  });

  @override
  State<SeasonStatisticsScreen> createState() =>
      _SeasonStatisticsScreenState();
}

class _SeasonStatisticsScreenState
    extends State<SeasonStatisticsScreen> {
  final MatchesService _matchesService = MatchesService();
  final TeamsService _teamsService = TeamsService();
  final SeasonsService _seasonsService = SeasonsService();

  late Future<_SeasonStatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_SeasonStatsData> _loadData() async {
    final results = await Future.wait([
      _matchesService.getBySeason(widget.season.id),
      _teamsService.getBySeason(widget.season.id),
      _seasonsService.getCategoriesBySeason(widget.season.id),
    ]);

    return _SeasonStatsData(
      matches: results[0] as List<Match>,
      teams: results[1] as List<Team>,
      categories: results[2] as List<SeasonCategory>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Estadisticas - ${widget.season.name}",
      currentIndex: 0,
      onNavTap: (_) {},
      body: FutureBuilder<_SeasonStatsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
                      "No se pudieron cargar las estadisticas",
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
          final stats = _SeasonStats.fromData(data);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(title: "Resumen general"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: "Partidos",
                    value: "${stats.totalMatches}",
                    icon: Icons.sports_soccer,
                  ),
                  _MetricCard(
                    label: "Jugados",
                    value: "${stats.playedMatches}",
                    icon: Icons.task_alt,
                  ),
                  _MetricCard(
                    label: "Goles",
                    value: "${stats.totalGoals}",
                    icon: Icons.sports_score,
                  ),
                  _MetricCard(
                    label: "Promedio gol/partido",
                    value: stats.averageGoalsLabel,
                    icon: Icons.insights,
                  ),
                  _MetricCard(
                    label: "Equipos",
                    value: "${stats.totalTeams}",
                    icon: Icons.groups,
                  ),
                  _MetricCard(
                    label: "Categorias",
                    value: "${stats.totalCategories}",
                    icon: Icons.category,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Estado de partidos"),
              const SizedBox(height: 12),
              _ChartCard(
                child: Column(
                  children: [
                    _BarStat(
                      label: "Jugados",
                      value: stats.playedMatches,
                      total: stats.totalMatches,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "Programados",
                      value: stats.scheduledMatches,
                      total: stats.totalMatches,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "En juego",
                      value: stats.playingMatches,
                      total: stats.totalMatches,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    _BarStat(
                      label: "Cancelados",
                      value: stats.canceledMatches,
                      total: stats.totalMatches,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: "Rendimiento por categoria"),
              const SizedBox(height: 12),
              _ChartCard(
                child: Column(
                  children: stats.categorySummaries
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CategoryStatRow(item: item),
                        ),
                      )
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

class _SeasonStatsData {
  final List<Match> matches;
  final List<Team> teams;
  final List<SeasonCategory> categories;

  _SeasonStatsData({
    required this.matches,
    required this.teams,
    required this.categories,
  });
}

class _SeasonStats {
  final int totalMatches;
  final int playedMatches;
  final int scheduledMatches;
  final int playingMatches;
  final int canceledMatches;
  final int totalGoals;
  final int totalTeams;
  final int totalCategories;
  final String averageGoalsLabel;
  final List<_CategorySummary> categorySummaries;

  _SeasonStats({
    required this.totalMatches,
    required this.playedMatches,
    required this.scheduledMatches,
    required this.playingMatches,
    required this.canceledMatches,
    required this.totalGoals,
    required this.totalTeams,
    required this.totalCategories,
    required this.averageGoalsLabel,
    required this.categorySummaries,
  });

  factory _SeasonStats.fromData(_SeasonStatsData data) {
    final matches = data.matches;
    final totalMatches = matches.length;

    final playedMatches =
        matches.where((m) => m.status.toUpperCase() == 'PLAYED').length;
    final scheduledMatches =
        matches.where((m) => m.status.toUpperCase() == 'SCHEDULED').length;
    final playingMatches =
        matches.where((m) => m.status.toUpperCase() == 'PLAYING').length;
    final canceledMatches =
        matches.where((m) => m.status.toUpperCase() == 'CANCELED').length;

    final playedGames = matches.where((m) => m.status.toUpperCase() == 'PLAYED');
    final totalGoals = playedGames.fold<int>(
      0,
      (acc, match) => acc + match.homeScore + match.awayScore,
    );

    final avgGoals = playedMatches == 0 ? 0 : (totalGoals / playedMatches);
    final averageGoalsLabel = avgGoals.toStringAsFixed(2);

    final categoryById = {
      for (final category in data.categories) category.id: category.name,
    };

    final categoryTeams = <String, int>{};
    for (final team in data.teams) {
      final key = team.categoryId ?? 'none';
      categoryTeams[key] = (categoryTeams[key] ?? 0) + 1;
    }

    final categoryMatches = <String, int>{};
    final categoryPlayedMatches = <String, int>{};
    final categoryGoals = <String, int>{};

    for (final match in matches) {
      final key = match.categoryId ?? 'none';
      categoryMatches[key] = (categoryMatches[key] ?? 0) + 1;

      if (match.status.toUpperCase() == 'PLAYED') {
        categoryPlayedMatches[key] = (categoryPlayedMatches[key] ?? 0) + 1;
        categoryGoals[key] = (categoryGoals[key] ?? 0) +
            match.homeScore +
            match.awayScore;
      }
    }

    final orderedCategoryKeys = <String>{
      ...categoryById.keys,
      ...categoryMatches.keys,
      ...categoryTeams.keys,
    }.toList();

    orderedCategoryKeys.sort((a, b) {
      final nameA = categoryById[a] ?? 'Sin categoria';
      final nameB = categoryById[b] ?? 'Sin categoria';
      return nameA.compareTo(nameB);
    });

    final summaries = orderedCategoryKeys.map((key) {
      final matchesCount = categoryMatches[key] ?? 0;
      final playedCount = categoryPlayedMatches[key] ?? 0;
      final goals = categoryGoals[key] ?? 0;
      final teams = categoryTeams[key] ?? 0;
      final avg = playedCount == 0 ? 0.0 : goals / playedCount;

      return _CategorySummary(
        categoryName: categoryById[key] ?? 'Sin categoria',
        teams: teams,
        matches: matchesCount,
        playedMatches: playedCount,
        goals: goals,
        averageGoals: avg,
      );
    }).toList();

    summaries.sort((a, b) => b.matches.compareTo(a.matches));

    return _SeasonStats(
      totalMatches: totalMatches,
      playedMatches: playedMatches,
      scheduledMatches: scheduledMatches,
      playingMatches: playingMatches,
      canceledMatches: canceledMatches,
      totalGoals: totalGoals,
      totalTeams: data.teams.length,
      totalCategories: data.categories.length,
      averageGoalsLabel: averageGoalsLabel,
      categorySummaries: summaries,
    );
  }
}

class _CategorySummary {
  final String categoryName;
  final int teams;
  final int matches;
  final int playedMatches;
  final int goals;
  final double averageGoals;

  _CategorySummary({
    required this.categoryName,
    required this.teams,
    required this.matches,
    required this.playedMatches,
    required this.goals,
    required this.averageGoals,
  });
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

class _CategoryStatRow extends StatelessWidget {
  final _CategorySummary item;

  const _CategoryStatRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final completion = item.matches == 0 ? 0.0 : item.playedMatches / item.matches;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF111827),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.categoryName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Equipos: ${item.teams}  |  Partidos: ${item.matches}  |  Goles: ${item.goals}",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Finalizados: ${item.playedMatches}",
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                "Promedio gol: ${item.averageGoals.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF06B6D4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
