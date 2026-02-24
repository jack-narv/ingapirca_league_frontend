import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/match_event.dart';
import '../../../models/match_lineup.dart';
import '../../../models/player.dart';
import '../../../models/player_statistics.dart';
import '../../../models/season.dart';
import '../../../models/season_category.dart';
import '../../../models/team.dart';
import '../../../services/match_events_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/players_service.dart';
import '../../../services/player_statistics_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';

enum _MvpMetric { total, bestPlayer, bestGoalkeeper }

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

class _SeasonStatisticsScreenState extends State<SeasonStatisticsScreen> {
  final MatchesService _matchesService = MatchesService();
  final MatchEventsService _eventsService = MatchEventsService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final TeamsService _teamsService = TeamsService();
  final SeasonsService _seasonsService = SeasonsService();
  final PlayersService _playersService = PlayersService();
  final PlayerStatisticsService _playerStatisticsService =
      PlayerStatisticsService();

  late Future<_SeasonStatsData> _future;

  String? _scorerCategoryId;
  String? _scorerTeamId;
  int _scorerTopLimit = 10;

  String? _mvpCategoryId;
  String? _mvpTeamId;
  int _mvpTopLimit = 10;
  _MvpMetric _mvpMetric = _MvpMetric.total;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_SeasonStatsData> _loadData() async {
    final matches = await _matchesService.getBySeason(widget.season.id);
    final teams = await _safeGetTeams();
    final categories = await _safeGetCategories();
    final players = await _safeGetPlayers();
    final seasonPlayerStatistics =
        await _safeGetPlayerStatisticsBySeason();
    final categoryPlayerStatistics = <String, List<PlayerStatistics>>{};
    if (categories.isNotEmpty) {
      final categoryResults = await Future.wait(
        categories.map((c) async {
          final stats = await _safeGetPlayerStatisticsBySeason(
            categoryId: c.id,
          );
          return MapEntry(c.id, stats);
        }),
      );
      for (final entry in categoryResults) {
        categoryPlayerStatistics[entry.key] = entry.value;
      }
    }

    final playedMatches =
        matches.where((m) => m.status.toUpperCase() == 'PLAYED').toList();
    final eventResults = await Future.wait(
      playedMatches.map((match) async {
        try {
          return await _eventsService.getTimeline(match.id);
        } catch (_) {
          return <MatchEvent>[];
        }
      }),
    );

    final lineupResults = await Future.wait(
      playedMatches.map((match) async {
        final home = await _safeGetLineup(match.id, match.homeTeamId);
        final away = await _safeGetLineup(match.id, match.awayTeamId);
        return <_LineupPlayerSnapshot>[
          ...home.map(
            (p) => _LineupPlayerSnapshot(
              playerId: p.playerId,
              teamId: match.homeTeamId,
              playerName: p.playerName,
              shirtNumber: p.shirtNumber,
            ),
          ),
          ...away.map(
            (p) => _LineupPlayerSnapshot(
              playerId: p.playerId,
              teamId: match.awayTeamId,
              playerName: p.playerName,
              shirtNumber: p.shirtNumber,
            ),
          ),
        ];
      }),
    );

    return _SeasonStatsData(
      matches: matches,
      teams: teams,
      categories: categories,
      players: players,
      seasonPlayerStatistics: seasonPlayerStatistics,
      categoryPlayerStatistics: categoryPlayerStatistics,
      events: eventResults.expand((e) => e).toList(),
      lineupPlayers: lineupResults.expand((e) => e).toList(),
    );
  }

  Future<List<Team>> _safeGetTeams() async {
    try {
      return await _teamsService.getBySeason(widget.season.id);
    } catch (_) {
      return <Team>[];
    }
  }

  Future<List<SeasonCategory>> _safeGetCategories() async {
    try {
      return await _seasonsService.getCategoriesBySeason(widget.season.id);
    } catch (_) {
      return <SeasonCategory>[];
    }
  }

  Future<List<Player>> _safeGetPlayers() async {
    try {
      return await _playersService.getAllPlayers();
    } catch (_) {
      return <Player>[];
    }
  }

  Future<List<PlayerStatistics>> _safeGetPlayerStatisticsBySeason({
    String? categoryId,
  }) async {
    try {
      return await _playerStatisticsService.getBySeason(
        widget.season.id,
        categoryId: categoryId,
      );
    } catch (_) {
      return <PlayerStatistics>[];
    }
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

          final stats = _SeasonStats.fromData(snapshot.data!);

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: "ESTADISTICAS"),
                      Tab(text: "GOLEADORES"),
                      Tab(text: "MEJORES JUGADORES"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStatisticsTab(stats),
                      _buildScorersTab(stats),
                      _buildMvpTab(stats),
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

  Widget _buildStatisticsTab(_SeasonStats stats) {
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
  }

  Widget _buildScorersTab(_SeasonStats stats) {
    final availableScorerTeams = _availableScorerTeams(stats);
    final safeTeamFilter =
        availableScorerTeams.any((t) => t.id == _scorerTeamId) ? _scorerTeamId : null;
    final filteredCategories = _filteredScorerCategories(
      stats,
      teamId: safeTeamFilter,
    );
    final topPlayers =
        _mergeScorerPlayers(filteredCategories, topLimit: _scorerTopLimit);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de goleadores",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _scorerCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ...stats.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _scorerCategoryId = value;
                    final teamStillValid = _availableScorerTeams(stats)
                        .any((t) => t.id == _scorerTeamId);
                    if (!teamStillValid) _scorerTeamId = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("scorer-team-${_scorerCategoryId ?? 'all'}"),
                initialValue: safeTeamFilter,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableScorerTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _scorerTeamId = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _TopLimitChip(
                    selected: _scorerTopLimit == 5,
                    label: "Top 5",
                    onTap: () => setState(() => _scorerTopLimit = 5),
                  ),
                  _TopLimitChip(
                    selected: _scorerTopLimit == 10,
                    label: "Top 10",
                    onTap: () => setState(() => _scorerTopLimit = 10),
                  ),
                  _TopLimitChip(
                    selected: _scorerTopLimit == 0,
                    label: "Todos",
                    onTap: () => setState(() => _scorerTopLimit = 0),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: "Top goleadores"),
        const SizedBox(height: 10),
        if (topPlayers.isEmpty)
          const _ChartCard(
            child: Text(
              "No hay goles para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          _ModernTableCard(
            title: "Ranking general",
            subtitle: "Goles acumulados por jugador",
            child: _ScorerDataTable(entries: topPlayers),
          ),
        const SizedBox(height: 18),
        _SectionTitle(title: "Goleadores por categoria y equipo"),
        const SizedBox(height: 10),
        if (filteredCategories.isEmpty)
          const _ChartCard(
            child: Text(
              "Sin registros para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...filteredCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryScorersCard(
                category: category,
                topLimit: _scorerTopLimit,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMvpTab(_SeasonStats stats) {
    final availableMvpTeams = _availableMvpTeams(stats);
    final safeTeamFilter =
        availableMvpTeams.any((t) => t.id == _mvpTeamId) ? _mvpTeamId : null;
    final filteredCategories = _filteredMvpCategories(stats, teamId: safeTeamFilter);
    final topPlayers = _mergeMvpPlayers(
      filteredCategories,
      metric: _mvpMetric,
      topLimit: _mvpTopLimit,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de mejores jugadores",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _mvpCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ...stats.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _mvpCategoryId = value;
                    final teamStillValid =
                        _availableMvpTeams(stats).any((t) => t.id == _mvpTeamId);
                    if (!teamStillValid) _mvpTeamId = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("mvp-team-${_mvpCategoryId ?? 'all'}"),
                initialValue: safeTeamFilter,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableMvpTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _mvpTeamId = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    selected: _mvpMetric == _MvpMetric.total,
                    label: "Total MVP",
                    onTap: () => setState(() => _mvpMetric = _MvpMetric.total),
                  ),
                  _MetricChip(
                    selected: _mvpMetric == _MvpMetric.bestPlayer,
                    label: "Mejor Jugador",
                    onTap: () =>
                        setState(() => _mvpMetric = _MvpMetric.bestPlayer),
                  ),
                  _MetricChip(
                    selected: _mvpMetric == _MvpMetric.bestGoalkeeper,
                    label: "Mejor Arquero",
                    onTap: () => setState(
                      () => _mvpMetric = _MvpMetric.bestGoalkeeper,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _TopLimitChip(
                    selected: _mvpTopLimit == 5,
                    label: "Top 5",
                    onTap: () => setState(() => _mvpTopLimit = 5),
                  ),
                  _TopLimitChip(
                    selected: _mvpTopLimit == 10,
                    label: "Top 10",
                    onTap: () => setState(() => _mvpTopLimit = 10),
                  ),
                  _TopLimitChip(
                    selected: _mvpTopLimit == 0,
                    label: "Todos",
                    onTap: () => setState(() => _mvpTopLimit = 0),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionTitle(title: "Top MVP"),
        const SizedBox(height: 10),
        if (topPlayers.isEmpty)
          const _ChartCard(
            child: Text(
              "No hay MVP registrados para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          _ModernTableCard(
            title: "Ranking general",
            subtitle: _mvpMetricLabel(_mvpMetric),
            child: _MvpDataTable(entries: topPlayers),
          ),
        const SizedBox(height: 18),
        _SectionTitle(title: "MVP por categoria y equipo"),
        const SizedBox(height: 10),
        if (filteredCategories.isEmpty)
          const _ChartCard(
            child: Text(
              "Sin registros para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...filteredCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryMvpCard(
                category: category,
                metric: _mvpMetric,
                topLimit: _mvpTopLimit,
              ),
            ),
          ),
      ],
    );
  }

  List<Team> _availableScorerTeams(_SeasonStats stats) {
    final categories = _filteredScorerCategories(stats);
    final map = <String, Team>{};
    for (final category in categories) {
      for (final team in category.teams) {
        map[team.teamId] = Team(
          id: team.teamId,
          categoryId: category.categoryId,
          name: team.teamName,
          foundedYear: null,
          logoUrl: null,
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<Team> _availableMvpTeams(_SeasonStats stats) {
    final categories = _filteredMvpCategories(stats);
    final map = <String, Team>{};
    for (final category in categories) {
      for (final team in category.teams) {
        map[team.teamId] = Team(
          id: team.teamId,
          categoryId: category.categoryId,
          name: team.teamName,
          foundedYear: null,
          logoUrl: null,
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<_CategoryScorers> _filteredScorerCategories(
    _SeasonStats stats, {
    String? teamId,
  }) {
    var categories = stats.categoryScorers;
    if (_scorerCategoryId != null) {
      categories =
          categories.where((c) => c.categoryId == _scorerCategoryId).toList();
    }
    if (teamId == null) return categories;

    return categories
        .map(
          (category) => _CategoryScorers(
            categoryId: category.categoryId,
            categoryName: category.categoryName,
            teams: category.teams.where((team) => team.teamId == teamId).toList(),
            topPlayers: category.topPlayers
                .where((player) => player.teamId == teamId)
                .toList(),
          ),
        )
        .where((category) => category.teams.isNotEmpty || category.topPlayers.isNotEmpty)
        .toList();
  }

  List<_CategoryMvp> _filteredMvpCategories(
    _SeasonStats stats, {
    String? teamId,
  }) {
    var categories = stats.categoryMvps;
    if (_mvpCategoryId != null) {
      categories = categories.where((c) => c.categoryId == _mvpCategoryId).toList();
    }
    if (teamId == null) return categories;

    return categories
        .map(
          (category) => _CategoryMvp(
            categoryId: category.categoryId,
            categoryName: category.categoryName,
            teams: category.teams.where((team) => team.teamId == teamId).toList(),
            topPlayers: category.topPlayers
                .where((player) => player.teamId == teamId)
                .toList(),
          ),
        )
        .where((category) => category.teams.isNotEmpty || category.topPlayers.isNotEmpty)
        .toList();
  }

  List<_ScorerEntry> _mergeScorerPlayers(
    List<_CategoryScorers> categories, {
    required int topLimit,
  }) {
    final byKey = <String, _ScorerEntry>{};
    for (final category in categories) {
      for (final player in category.topPlayers) {
        final key = "${player.teamId}|${player.playerId}|${player.playerName}";
        final prev = byKey[key];
        if (prev == null) {
          byKey[key] = player;
        } else {
          byKey[key] = _ScorerEntry(
            playerId: prev.playerId,
            playerName: prev.playerName,
            teamId: prev.teamId,
            teamName: prev.teamName,
            goals: prev.goals + player.goals,
          );
        }
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        final byGoals = b.goals.compareTo(a.goals);
        if (byGoals != 0) return byGoals;
        return a.playerName.compareTo(b.playerName);
      });
    return _applyTop(list, topLimit);
  }

  List<_MvpEntry> _mergeMvpPlayers(
    List<_CategoryMvp> categories, {
    required _MvpMetric metric,
    required int topLimit,
  }) {
    final byKey = <String, _MvpEntry>{};
    for (final category in categories) {
      for (final player in category.topPlayers) {
        final key = "${player.teamId}|${player.playerId}|${player.playerName}";
        final prev = byKey[key];
        if (prev == null) {
          byKey[key] = player;
        } else {
          byKey[key] = _MvpEntry(
            playerId: prev.playerId,
            playerName: prev.playerName,
            teamId: prev.teamId,
            teamName: prev.teamName,
            shirtNumber: prev.shirtNumber ?? player.shirtNumber,
            bestPlayerAwards: prev.bestPlayerAwards + player.bestPlayerAwards,
            bestGoalkeeperAwards:
                prev.bestGoalkeeperAwards + player.bestGoalkeeperAwards,
          );
        }
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) {
        final byMetric = _metricValue(b, metric).compareTo(_metricValue(a, metric));
        if (byMetric != 0) return byMetric;
        return b.totalAwards.compareTo(a.totalAwards);
      });
    return _applyTop(list, topLimit);
  }

  int _metricValue(_MvpEntry entry, _MvpMetric metric) {
    switch (metric) {
      case _MvpMetric.total:
        return entry.totalAwards;
      case _MvpMetric.bestPlayer:
        return entry.bestPlayerAwards;
      case _MvpMetric.bestGoalkeeper:
        return entry.bestGoalkeeperAwards;
    }
  }

  String _mvpMetricLabel(_MvpMetric metric) {
    switch (metric) {
      case _MvpMetric.total:
        return "Total de premios (Mejor Jugador + Mejor Arquero)";
      case _MvpMetric.bestPlayer:
        return "Premios de Mejor Jugador";
      case _MvpMetric.bestGoalkeeper:
        return "Premios de Mejor Arquero";
    }
  }

  List<T> _applyTop<T>(List<T> source, int topLimit) {
    if (topLimit <= 0 || source.length <= topLimit) return source;
    return source.take(topLimit).toList();
  }

  Future<List<MatchLineupPlayer>> _safeGetLineup(
    String matchId,
    String teamId,
  ) async {
    try {
      return await _lineupsService.getLineup(matchId, teamId);
    } catch (_) {
      return <MatchLineupPlayer>[];
    }
  }
}

class _SeasonStatsData {
  final List<Match> matches;
  final List<Team> teams;
  final List<SeasonCategory> categories;
  final List<Player> players;
  final List<PlayerStatistics> seasonPlayerStatistics;
  final Map<String, List<PlayerStatistics>> categoryPlayerStatistics;
  final List<MatchEvent> events;
  final List<_LineupPlayerSnapshot> lineupPlayers;

  _SeasonStatsData({
    required this.matches,
    required this.teams,
    required this.categories,
    required this.players,
    required this.seasonPlayerStatistics,
    required this.categoryPlayerStatistics,
    required this.events,
    required this.lineupPlayers,
  });
}

class _LineupPlayerSnapshot {
  final String playerId;
  final String teamId;
  final String playerName;
  final int shirtNumber;

  _LineupPlayerSnapshot({
    required this.playerId,
    required this.teamId,
    required this.playerName,
    required this.shirtNumber,
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
  final List<_CategoryScorers> categoryScorers;
  final List<_CategoryMvp> categoryMvps;
  final List<SeasonCategory> categories;

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
    required this.categoryScorers,
    required this.categoryMvps,
    required this.categories,
  });

  factory _SeasonStats.fromData(_SeasonStatsData data) {
    final categoryById = {
      for (final category in data.categories) category.id: category.name,
    };
    final teamById = {for (final team in data.teams) team.id: team};
    final playerById = {for (final player in data.players) player.id: player};
    final matchById = {for (final match in data.matches) match.id: match};

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
    final avgGoals =
        playedMatches == 0 ? 0.0 : (totalGoals / playedMatches.toDouble());

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

    final summaryCategoryKeys = <String>{
      ...categoryById.keys,
      ...categoryMatches.keys,
      ...categoryTeams.keys,
    }.toList()
      ..sort((a, b) {
        final nameA = categoryById[a] ?? 'Sin categoria';
        final nameB = categoryById[b] ?? 'Sin categoria';
        return nameA.compareTo(nameB);
      });

    final categorySummaries = summaryCategoryKeys.map((key) {
      final matchesCount = categoryMatches[key] ?? 0;
      final playedCount = categoryPlayedMatches[key] ?? 0;
      final goals = categoryGoals[key] ?? 0;
      final teams = categoryTeams[key] ?? 0;
      final avg = playedCount == 0 ? 0.0 : goals / playedCount.toDouble();

      return _CategorySummary(
        categoryName: categoryById[key] ?? 'Sin categoria',
        teams: teams,
        matches: matchesCount,
        playedMatches: playedCount,
        goals: goals,
        averageGoals: avg,
      );
    }).toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));

    final scorerCategories = data.seasonPlayerStatistics.isNotEmpty ||
            data.categoryPlayerStatistics.values.any((v) => v.isNotEmpty)
        ? _buildScorerCategoriesFromPlayerStatistics(
            data: data,
            categoryById: categoryById,
            teamById: teamById,
          )
        : _buildScorerCategories(
            data: data,
            categoryById: categoryById,
            teamById: teamById,
            playerById: playerById,
            matchById: matchById,
          );

    final mvpCategories = _buildMvpCategories(
      data: data,
      categoryById: categoryById,
      teamById: teamById,
      playerById: playerById,
    );

    return _SeasonStats(
      totalMatches: totalMatches,
      playedMatches: playedMatches,
      scheduledMatches: scheduledMatches,
      playingMatches: playingMatches,
      canceledMatches: canceledMatches,
      totalGoals: totalGoals,
      totalTeams: data.teams.length,
      totalCategories: data.categories.length,
      averageGoalsLabel: avgGoals.toStringAsFixed(2),
      categorySummaries: categorySummaries,
      categoryScorers: scorerCategories,
      categoryMvps: mvpCategories,
      categories: data.categories,
    );
  }

  static List<_CategoryScorers> _buildScorerCategoriesFromPlayerStatistics({
    required _SeasonStatsData data,
    required Map<String, String> categoryById,
    required Map<String, Team> teamById,
  }) {
    final teamByPlayerId = <String, String>{};
    for (final lp in data.lineupPlayers) {
      if (lp.playerId.trim().isEmpty) continue;
      teamByPlayerId.putIfAbsent(lp.playerId, () => lp.teamId);
    }

    final categoryKeys = <String>{
      ...data.categories.map((c) => c.id),
      ...data.categoryPlayerStatistics.keys,
    }.toList()
      ..sort((a, b) {
        final nameA = categoryById[a] ?? 'Sin categoria';
        final nameB = categoryById[b] ?? 'Sin categoria';
        return nameA.compareTo(nameB);
      });

    return categoryKeys.map((categoryId) {
      final stats = data.categoryPlayerStatistics[categoryId] ?? <PlayerStatistics>[];
      final entries = stats.map((s) {
        final playerId = s.playerId.trim();
        final playerName = s.player?.fullName ?? playerId;
        final teamId = teamByPlayerId[playerId] ?? 'unknown';
        final teamName = teamById[teamId]?.name ??
            (teamId == 'unknown' ? 'Sin equipo' : teamId);
        return _ScorerEntry(
          playerId: playerId,
          playerName: playerName,
          teamId: teamId,
          teamName: teamName,
          goals: s.goals,
        );
      }).toList()
        ..sort((a, b) {
          final byGoals = b.goals.compareTo(a.goals);
          if (byGoals != 0) return byGoals;
          return a.playerName.compareTo(b.playerName);
        });

      final byTeam = <String, List<_ScorerEntry>>{};
      for (final entry in entries) {
        byTeam.putIfAbsent(entry.teamId, () => <_ScorerEntry>[]).add(entry);
      }

      final teams = byTeam.entries.map((entry) {
        final players = entry.value;
        final totalGoals =
            players.fold<int>(0, (acc, player) => acc + player.goals);
        return _TeamScorers(
          teamId: entry.key,
          teamName: teamById[entry.key]?.name ??
              (entry.key == 'unknown' ? 'Sin equipo' : entry.key),
          totalGoals: totalGoals,
          players: players,
        );
      }).toList()
        ..sort((a, b) => a.teamName.compareTo(b.teamName));

      return _CategoryScorers(
        categoryId: categoryId,
        categoryName: categoryById[categoryId] ?? 'Sin categoria',
        teams: teams,
        topPlayers: entries,
      );
    }).toList();
  }

  static List<_CategoryScorers> _buildScorerCategories({
    required _SeasonStatsData data,
    required Map<String, String> categoryById,
    required Map<String, Team> teamById,
    required Map<String, Player> playerById,
    required Map<String, Match> matchById,
  }) {
    final goalsByCategoryTeamPlayer =
        <String, Map<String, Map<String, _ScorerEntry>>>{};

    for (final event in data.events) {
      if (event.eventType.toUpperCase() != 'GOAL') continue;
      final match = matchById[event.matchId];
      if (match == null) continue;

      final categoryId = match.categoryId ?? 'none';
      final teamId = event.teamId.trim();
      if (teamId.isEmpty) continue;

      final playerId = event.playerId.trim();
      final playerFromStore = playerById[playerId];
      final playerNameFromStore = playerFromStore == null
          ? ''
          : "${playerFromStore.firstName} ${playerFromStore.lastName}".trim();
      final eventName = (event.playerName ?? '').trim();
      final playerName = eventName.isNotEmpty
          ? eventName
          : (playerNameFromStore.isNotEmpty
              ? playerNameFromStore
              : (playerId.isNotEmpty ? playerId : 'Jugador'));
      final playerKey = playerId.isNotEmpty ? playerId : "name:$playerName";
      final teamName = teamById[teamId]?.name ?? teamId;

      final playerBucket = goalsByCategoryTeamPlayer
          .putIfAbsent(categoryId, () => <String, Map<String, _ScorerEntry>>{})
          .putIfAbsent(teamId, () => <String, _ScorerEntry>{});

      final prev = playerBucket[playerKey];
      if (prev == null) {
        playerBucket[playerKey] = _ScorerEntry(
          playerId: playerId,
          playerName: playerName,
          teamId: teamId,
          teamName: teamName,
          goals: 1,
        );
      } else {
        playerBucket[playerKey] = _ScorerEntry(
          playerId: prev.playerId,
          playerName: prev.playerName,
          teamId: prev.teamId,
          teamName: prev.teamName,
          goals: prev.goals + 1,
        );
      }
    }

    final categoryKeys = <String>{
      ...data.categories.map((c) => c.id),
      ...goalsByCategoryTeamPlayer.keys,
      ...data.teams.map((t) => t.categoryId ?? 'none'),
    }.toList()
      ..sort((a, b) {
        final nameA = categoryById[a] ?? 'Sin categoria';
        final nameB = categoryById[b] ?? 'Sin categoria';
        return nameA.compareTo(nameB);
      });

    return categoryKeys.map((categoryId) {
      final teamsForCategory = data.teams
          .where((team) => (team.categoryId ?? 'none') == categoryId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final goalsByTeam =
          goalsByCategoryTeamPlayer[categoryId] ?? <String, Map<String, _ScorerEntry>>{};

      final teamIds = <String>{
        ...teamsForCategory.map((t) => t.id),
        ...goalsByTeam.keys,
      }.toList()
        ..sort((a, b) {
          final nameA = teamById[a]?.name ?? a;
          final nameB = teamById[b]?.name ?? b;
          return nameA.compareTo(nameB);
        });

      final teams = teamIds.map((teamId) {
        final players = (goalsByTeam[teamId]?.values.toList() ?? <_ScorerEntry>[])
          ..sort((a, b) {
            final byGoals = b.goals.compareTo(a.goals);
            if (byGoals != 0) return byGoals;
            return a.playerName.compareTo(b.playerName);
          });
        final totalGoals =
            players.fold<int>(0, (acc, player) => acc + player.goals);

        return _TeamScorers(
          teamId: teamId,
          teamName: teamById[teamId]?.name ?? teamId,
          totalGoals: totalGoals,
          players: players,
        );
      }).toList();

      final topPlayers = teams.expand((t) => t.players).toList()
        ..sort((a, b) {
          final byGoals = b.goals.compareTo(a.goals);
          if (byGoals != 0) return byGoals;
          return a.playerName.compareTo(b.playerName);
        });

      return _CategoryScorers(
        categoryId: categoryId,
        categoryName: categoryById[categoryId] ?? 'Sin categoria',
        teams: teams,
        topPlayers: topPlayers,
      );
    }).toList();
  }

  static List<_CategoryMvp> _buildMvpCategories({
    required _SeasonStatsData data,
    required Map<String, String> categoryById,
    required Map<String, Team> teamById,
    required Map<String, Player> playerById,
  }) {
    final lineupByPlayerId = <String, _LineupPlayerSnapshot>{};
    for (final lp in data.lineupPlayers) {
      if (lp.playerId.trim().isEmpty) continue;
      final current = lineupByPlayerId[lp.playerId];
      if (current == null) {
        lineupByPlayerId[lp.playerId] = lp;
        continue;
      }
      final currentHasName = current.playerName.trim().isNotEmpty;
      final nextHasName = lp.playerName.trim().isNotEmpty;
      final currentHasShirt = current.shirtNumber > 0;
      final nextHasShirt = lp.shirtNumber > 0;
      if ((!currentHasName && nextHasName) ||
          (!currentHasShirt && nextHasShirt)) {
        lineupByPlayerId[lp.playerId] = lp;
      }
    }

    final byCategoryTeamPlayer = <String, Map<String, Map<String, _MvpEntry>>>{};

    void addAward({
      required String categoryId,
      required String teamId,
      required String playerId,
      required bool isBestGoalkeeper,
    }) {
      if (playerId.trim().isEmpty) return;
      final resolvedTeamId = teamId.trim().isEmpty ? 'unknown' : teamId;
      final teamName = teamById[resolvedTeamId]?.name ??
          (resolvedTeamId == 'unknown' ? 'Sin equipo' : resolvedTeamId);
      final player = playerById[playerId];
      final lineup = lineupByPlayerId[playerId];
      final lineupName = (lineup?.playerName ?? '').trim();
      final playerName = lineupName.isNotEmpty
          ? lineupName
          : player == null
          ? playerId
          : "${player.firstName} ${player.lastName}".trim();
      final shirtNumber = (lineup?.shirtNumber ?? 0) > 0
          ? lineup!.shirtNumber
          : null;

      final playerBucket = byCategoryTeamPlayer
          .putIfAbsent(categoryId, () => <String, Map<String, _MvpEntry>>{})
          .putIfAbsent(resolvedTeamId, () => <String, _MvpEntry>{});

      final prev = playerBucket[playerId];
      final bestPlayerAwards =
          (prev?.bestPlayerAwards ?? 0) + (isBestGoalkeeper ? 0 : 1);
      final bestGoalkeeperAwards =
          (prev?.bestGoalkeeperAwards ?? 0) + (isBestGoalkeeper ? 1 : 0);

      playerBucket[playerId] = _MvpEntry(
        playerId: playerId,
        playerName: playerName.isEmpty ? playerId : playerName,
        teamId: resolvedTeamId,
        teamName: teamName,
        shirtNumber: shirtNumber,
        bestPlayerAwards: bestPlayerAwards,
        bestGoalkeeperAwards: bestGoalkeeperAwards,
      );
    }

    for (final match in data.matches) {
      if (match.status.toUpperCase() != 'PLAYED') continue;
      final categoryId = match.categoryId ?? 'none';
      final bestPlayerId = (match.bestPlayerId ?? '').trim();
      final bestGoalkeeperId = (match.bestGoalkeeperId ?? '').trim();

      String guessTeam(String playerId) {
        final fromLineup = lineupByPlayerId[playerId]?.teamId.trim() ?? '';
        if (fromLineup.isNotEmpty) return fromLineup;
        final player = playerById[playerId];
        if (player == null || player.teamInfo.isEmpty) return 'unknown';
        final teamId = player.teamInfo.first.teamId.trim();
        return teamId.isEmpty ? 'unknown' : teamId;
      }

      if (bestPlayerId.isNotEmpty) {
        addAward(
          categoryId: categoryId,
          teamId: guessTeam(bestPlayerId),
          playerId: bestPlayerId,
          isBestGoalkeeper: false,
        );
      }
      if (bestGoalkeeperId.isNotEmpty) {
        addAward(
          categoryId: categoryId,
          teamId: guessTeam(bestGoalkeeperId),
          playerId: bestGoalkeeperId,
          isBestGoalkeeper: true,
        );
      }
    }

    final categoryKeys = <String>{
      ...data.categories.map((c) => c.id),
      ...byCategoryTeamPlayer.keys,
      ...data.teams.map((t) => t.categoryId ?? 'none'),
    }.toList()
      ..sort((a, b) {
        final nameA = categoryById[a] ?? 'Sin categoria';
        final nameB = categoryById[b] ?? 'Sin categoria';
        return nameA.compareTo(nameB);
      });

    return categoryKeys.map((categoryId) {
      final teamMap = byCategoryTeamPlayer[categoryId] ?? <String, Map<String, _MvpEntry>>{};
      final teamsForCategory = data.teams
          .where((team) => (team.categoryId ?? 'none') == categoryId)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      final teamIds = <String>{
        ...teamsForCategory.map((t) => t.id),
        ...teamMap.keys,
      }.toList()
        ..sort((a, b) {
          final nameA = teamById[a]?.name ?? a;
          final nameB = teamById[b]?.name ?? b;
          return nameA.compareTo(nameB);
        });

      final teams = teamIds.map((teamId) {
        final players = (teamMap[teamId]?.values.toList() ?? <_MvpEntry>[])
          ..sort((a, b) => b.totalAwards.compareTo(a.totalAwards));
        final totalAwards =
            players.fold<int>(0, (acc, player) => acc + player.totalAwards);
        return _TeamMvp(
          teamId: teamId,
          teamName: teamById[teamId]?.name ??
              (teamId == 'unknown' ? 'Sin equipo' : teamId),
          totalAwards: totalAwards,
          players: players,
        );
      }).toList();

      final topPlayers = teams.expand((t) => t.players).toList()
        ..sort((a, b) => b.totalAwards.compareTo(a.totalAwards));

      return _CategoryMvp(
        categoryId: categoryId,
        categoryName: categoryById[categoryId] ?? 'Sin categoria',
        teams: teams,
        topPlayers: topPlayers,
      );
    }).toList();
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

class _CategoryScorers {
  final String categoryId;
  final String categoryName;
  final List<_TeamScorers> teams;
  final List<_ScorerEntry> topPlayers;

  _CategoryScorers({
    required this.categoryId,
    required this.categoryName,
    required this.teams,
    required this.topPlayers,
  });
}

class _TeamScorers {
  final String teamId;
  final String teamName;
  final int totalGoals;
  final List<_ScorerEntry> players;

  _TeamScorers({
    required this.teamId,
    required this.teamName,
    required this.totalGoals,
    required this.players,
  });
}

class _ScorerEntry {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int goals;

  _ScorerEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.goals,
  });
}

class _CategoryMvp {
  final String categoryId;
  final String categoryName;
  final List<_TeamMvp> teams;
  final List<_MvpEntry> topPlayers;

  _CategoryMvp({
    required this.categoryId,
    required this.categoryName,
    required this.teams,
    required this.topPlayers,
  });
}

class _TeamMvp {
  final String teamId;
  final String teamName;
  final int totalAwards;
  final List<_MvpEntry> players;

  _TeamMvp({
    required this.teamId,
    required this.teamName,
    required this.totalAwards,
    required this.players,
  });
}

class _MvpEntry {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int? shirtNumber;
  final int bestPlayerAwards;
  final int bestGoalkeeperAwards;

  _MvpEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.shirtNumber,
    required this.bestPlayerAwards,
    required this.bestGoalkeeperAwards,
  });

  int get totalAwards => bestPlayerAwards + bestGoalkeeperAwards;
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            "Equipos: ${item.teams}  |  Partidos: ${item.matches}  |  Goles: ${item.goals}",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Finalizados: ${item.playedMatches}",
                  style: const TextStyle(fontSize: 12)),
              Text("Promedio gol: ${item.averageGoals.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final Widget child;

  const _FilterCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A2332),
      ),
      child: child,
    );
  }
}

class _TopLimitChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _TopLimitChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _MetricChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ModernTableCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ModernTableCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ScorerDataTable extends StatelessWidget {
  final List<_ScorerEntry> entries;

  const _ScorerDataTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 42,
        columns: const [
          DataColumn(label: Text("#")),
          DataColumn(label: Text("Jugador")),
          DataColumn(label: Text("Equipo")),
          DataColumn(label: Text("Goles")),
        ],
        rows: List.generate(entries.length, (index) {
          final entry = entries[index];
          return DataRow(
            cells: [
              DataCell(Text("${index + 1}")),
              DataCell(
                SizedBox(
                  width: 180,
                  child: Text(entry.playerName, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 140,
                  child: Text(entry.teamName, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text("${entry.goals}")),
            ],
          );
        }),
      ),
    );
  }
}

class _CategoryScorersCard extends StatelessWidget {
  final _CategoryScorers category;
  final int topLimit;

  const _CategoryScorersCard({
    required this.category,
    required this.topLimit,
  });

  @override
  Widget build(BuildContext context) {
    List<_ScorerEntry> top = category.topPlayers;
    if (topLimit > 0 && top.length > topLimit) {
      top = top.take(topLimit).toList();
    }

    return _ModernTableCard(
      title: category.categoryName,
      subtitle: "Top goleadores de la categoria y detalle por equipo",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top.isNotEmpty) ...[
            const Text("Top categoria", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _ScorerDataTable(entries: top),
            const SizedBox(height: 10),
          ],
          if (category.teams.isEmpty)
            const Text("Sin goles registrados en esta categoria",
                style: TextStyle(color: Colors.white70))
          else
            ...category.teams.map((team) {
              var players = team.players;
              if (topLimit > 0 && players.length > topLimit) {
                players = players.take(topLimit).toList();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF111827),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${team.teamName} - ${team.totalGoals} goles",
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (players.isEmpty)
                        const Text("Sin goles",
                            style: TextStyle(color: Colors.white70, fontSize: 12))
                      else
                        _ScorerDataTable(entries: players),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MvpDataTable extends StatelessWidget {
  final List<_MvpEntry> entries;

  const _MvpDataTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 42,
        columns: const [
          DataColumn(label: Text("#")),
          DataColumn(label: Text("Jugador")),
          DataColumn(label: Text("Dorsal")),
          DataColumn(label: Text("Equipo")),
          DataColumn(label: Text("Mejor Jugador")),
          DataColumn(label: Text("Mejor Arquero")),
          DataColumn(label: Text("Total")),
        ],
        rows: List.generate(entries.length, (index) {
          final entry = entries[index];
          return DataRow(
            cells: [
              DataCell(Text("${index + 1}")),
              DataCell(
                SizedBox(
                  width: 180,
                  child: Text(entry.playerName, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text(entry.shirtNumber?.toString() ?? "--")),
              DataCell(
                SizedBox(
                  width: 140,
                  child: Text(entry.teamName, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(Text("${entry.bestPlayerAwards}")),
              DataCell(Text("${entry.bestGoalkeeperAwards}")),
              DataCell(Text("${entry.totalAwards}")),
            ],
          );
        }),
      ),
    );
  }
}

class _CategoryMvpCard extends StatelessWidget {
  final _CategoryMvp category;
  final _MvpMetric metric;
  final int topLimit;

  const _CategoryMvpCard({
    required this.category,
    required this.metric,
    required this.topLimit,
  });

  int _metricValue(_MvpEntry entry) {
    switch (metric) {
      case _MvpMetric.total:
        return entry.totalAwards;
      case _MvpMetric.bestPlayer:
        return entry.bestPlayerAwards;
      case _MvpMetric.bestGoalkeeper:
        return entry.bestGoalkeeperAwards;
    }
  }

  @override
  Widget build(BuildContext context) {
    var top = category.topPlayers.toList()
      ..sort((a, b) => _metricValue(b).compareTo(_metricValue(a)));
    if (topLimit > 0 && top.length > topLimit) {
      top = top.take(topLimit).toList();
    }

    return _ModernTableCard(
      title: category.categoryName,
      subtitle: "MVP de categoria y MVP de cada equipo",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top.isNotEmpty) ...[
            const Text("Top categoria", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _MvpDataTable(entries: top),
            const SizedBox(height: 10),
          ],
          if (category.teams.isEmpty)
            const Text("Sin MVP registrados en esta categoria",
                style: TextStyle(color: Colors.white70))
          else
            ...category.teams.map((team) {
              var players = team.players.toList()
                ..sort((a, b) => _metricValue(b).compareTo(_metricValue(a)));
              if (topLimit > 0 && players.length > topLimit) {
                players = players.take(topLimit).toList();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF111827),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${team.teamName} - ${team.totalAwards} premios",
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (players.isEmpty)
                        const Text("Sin MVP",
                            style: TextStyle(color: Colors.white70, fontSize: 12))
                      else
                        _MvpDataTable(entries: players),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
