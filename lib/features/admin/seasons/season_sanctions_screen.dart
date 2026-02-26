import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/cards_summary.dart';
import '../../../models/match.dart';
import '../../../models/match_event.dart';
import '../../../models/match_lineup.dart';
import '../../../models/player.dart';
import '../../../models/season.dart';
import '../../../models/season_category.dart';
import '../../../models/suspension_summary.dart';
import '../../../models/team.dart';
import '../../../services/match_events_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/players_service.dart';
import '../../../services/sanctions_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';

class SeasonSanctionsScreen extends StatefulWidget {
  final Season season;

  const SeasonSanctionsScreen({
    super.key,
    required this.season,
  });

  @override
  State<SeasonSanctionsScreen> createState() => _SeasonSanctionsScreenState();
}

class _SeasonSanctionsScreenState extends State<SeasonSanctionsScreen> {
  final MatchesService _matchesService = MatchesService();
  final MatchEventsService _eventsService = MatchEventsService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final TeamsService _teamsService = TeamsService();
  final SeasonsService _seasonsService = SeasonsService();
  final PlayersService _playersService = PlayersService();
  final SanctionsService _sanctionsService = SanctionsService();

  late Future<_SanctionsData> _future;
  late Future<List<CardsSummary>> _cardsFuture;
  late Future<List<SuspensionSummary>> _suspensionsFuture;

  String? _cardsCategoryId;
  String? _cardsTeamId;

  String? _suspensionsCategoryId;
  String? _suspensionsTeamId;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _cardsFuture = _loadCardsSummary();
    _suspensionsFuture = _loadSuspensionsSummary();
  }

  Future<_SanctionsData> _loadData() async {
    final matches = await _matchesService.getBySeason(widget.season.id);

    List<Team> teams = <Team>[];
    List<SeasonCategory> categories = <SeasonCategory>[];
    List<Player> players = <Player>[];

    try {
      teams = await _teamsService.getBySeason(widget.season.id);
    } catch (_) {}

    try {
      categories = await _seasonsService.getCategoriesBySeason(widget.season.id);
    } catch (_) {}

    try {
      players = await _playersService.getAllPlayers();
    } catch (_) {}

    final timelines = await Future.wait(
      matches.map((m) async {
        try {
          return await _eventsService.getTimeline(m.id);
        } catch (_) {
          return <MatchEvent>[];
        }
      }),
    );

    final lineupSnapshots = <_LineupShirtSnapshot>[];
    for (final match in matches) {
      final home = await _safeGetLineup(match.id, match.homeTeamId);
      final away = await _safeGetLineup(match.id, match.awayTeamId);
      lineupSnapshots.addAll(
        home.map(
          (p) => _LineupShirtSnapshot(
            matchId: match.id,
            playerId: p.playerId,
            shirtNumber: p.shirtNumber,
          ),
        ),
      );
      lineupSnapshots.addAll(
        away.map(
          (p) => _LineupShirtSnapshot(
            matchId: match.id,
            playerId: p.playerId,
            shirtNumber: p.shirtNumber,
          ),
        ),
      );
    }

    return _SanctionsData(
      matches: matches,
      teams: teams,
      categories: categories,
      players: players,
      events: timelines.expand((e) => e).toList(),
      lineupShirts: lineupSnapshots,
    );
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

  Future<List<SuspensionSummary>> _loadSuspensionsSummary() {
    return _sanctionsService.getSuspensionsSummaryBySeason(
      seasonId: widget.season.id,
      categoryId: _suspensionsCategoryId,
      teamId: _suspensionsTeamId,
    );
  }

  Future<List<CardsSummary>> _loadCardsSummary() {
    return _sanctionsService.getCardsSummaryBySeason(
      seasonId: widget.season.id,
      categoryId: _cardsCategoryId,
      teamId: _cardsTeamId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Sanciones - ${widget.season.name}",
      currentIndex: 0,
      onNavTap: (_) {},
      body: FutureBuilder<_SanctionsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
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
                      "No se pudieron cargar las sanciones",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _future = _loadData();
                          _cardsFuture = _loadCardsSummary();
                          _suspensionsFuture = _loadSuspensionsSummary();
                        });
                      },
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            );
          }

          final vm = _SanctionsViewModel.fromData(snapshot.data!);

          return DefaultTabController(
            length: 2,
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
                      Tab(text: "TARJETAS"),
                      Tab(text: "SUSPENSIONES"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCardsTab(vm),
                      _buildSuspensionsTab(vm),
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

  Widget _buildCardsTab(_SanctionsViewModel vm) {
    final availableTeams = _availableTeams(
      vm.teams,
      selectedCategoryId: _cardsCategoryId,
    );
    final safeTeamId =
        availableTeams.any((t) => t.id == _cardsTeamId) ? _cardsTeamId : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de tarjetas",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _cardsCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ...vm.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _cardsCategoryId = value;
                    final stillValid = _availableTeams(
                      vm.teams,
                      selectedCategoryId: value,
                    ).any((t) => t.id == _cardsTeamId);
                    if (!stillValid) {
                      _cardsTeamId = null;
                    }
                    _cardsFuture = _loadCardsSummary();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("cards-team-${_cardsCategoryId ?? 'all'}"),
                initialValue: safeTeamId,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _cardsTeamId = value;
                  _cardsFuture = _loadCardsSummary();
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CardsSummary>>(
          future: _cardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final rows = snapshot.data ?? <CardsSummary>[];
            final yellowCount =
                rows.fold<int>(0, (acc, item) => acc + item.yellowCards);
            final redDirectCount = rows.fold<int>(
              0,
              (acc, item) => acc + item.redDirectCards,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(
                      label: "Jugadores con tarjetas",
                      value: "${rows.length}",
                      icon: Icons.style,
                    ),
                    _MetricCard(
                      label: "Amarillas",
                      value: "$yellowCount",
                      icon: Icons.square_rounded,
                    ),
                    _MetricCard(
                      label: "Rojas directas",
                      value: "$redDirectCount",
                      icon: Icons.stop_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: "Registro de tarjetas"),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const _ChartCard(
                    child: Text(
                      "No hay tarjetas para los filtros seleccionados",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  _ModernTableCard(
                    title: "Resumen de tarjetas",
                    subtitle:
                        "Suma de YELLOW y RED_DIRECT por jugador",
                    child: _CardsSummaryTable(entries: rows),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuspensionsTab(_SanctionsViewModel vm) {
    final availableTeams = _availableTeams(
      vm.teams,
      selectedCategoryId: _suspensionsCategoryId,
    );
    final safeTeamId = availableTeams.any((t) => t.id == _suspensionsTeamId)
        ? _suspensionsTeamId
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de suspensiones",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _suspensionsCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ...vm.categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _suspensionsCategoryId = value;
                    final stillValid = _availableTeams(
                      vm.teams,
                      selectedCategoryId: value,
                    ).any((t) => t.id == _suspensionsTeamId);
                    if (!stillValid) {
                      _suspensionsTeamId = null;
                    }
                    _suspensionsFuture = _loadSuspensionsSummary();
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("susp-team-${_suspensionsCategoryId ?? 'all'}"),
                initialValue: safeTeamId,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() {
                      _suspensionsTeamId = value;
                      _suspensionsFuture = _loadSuspensionsSummary();
                    }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<SuspensionSummary>>(
          future: _suspensionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final summary = snapshot.data ?? <SuspensionSummary>[];
            final rows = summary
                .map(
                  (s) => _SuspensionSummaryRow(
                    playerId: s.playerId,
                    playerName: s.fullName.isEmpty ? s.playerId : s.fullName,
                    shirtNumber: s.shirtNumber,
                    totalMatchesSuspended: s.totalMatchesSuspended,
                  ),
                )
                .toList();

            final totalMatchesAffected = rows.fold<int>(
              0,
              (acc, item) => acc + item.totalMatchesSuspended,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(
                      label: "Jugadores suspendidos",
                      value: "${rows.length}",
                      icon: Icons.gavel,
                    ),
                    _MetricCard(
                      label: "Partidos de sancion",
                      value: "$totalMatchesAffected",
                      icon: Icons.confirmation_number,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: "Registro de suspensiones"),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const _ChartCard(
                    child: Text(
                      "No hay suspensiones para los filtros seleccionados",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                else
                  _ModernTableCard(
                    title: "Resumen de suspensiones",
                    subtitle: "Suma de partidos suspendidos por jugador",
                    child: _SuspensionsSummaryTable(entries: rows),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Team> _availableTeams(
    List<Team> teams, {
    required String? selectedCategoryId,
  }) {
    if (selectedCategoryId == null) {
      return teams;
    }

    return teams.where((t) => t.categoryId == selectedCategoryId).toList();
  }
}

class _SanctionsData {
  final List<Match> matches;
  final List<Team> teams;
  final List<SeasonCategory> categories;
  final List<Player> players;
  final List<MatchEvent> events;
  final List<_LineupShirtSnapshot> lineupShirts;

  _SanctionsData({
    required this.matches,
    required this.teams,
    required this.categories,
    required this.players,
    required this.events,
    required this.lineupShirts,
  });
}

class _LineupShirtSnapshot {
  final String matchId;
  final String playerId;
  final int shirtNumber;

  _LineupShirtSnapshot({
    required this.matchId,
    required this.playerId,
    required this.shirtNumber,
  });
}

class _CardEventRow {
  final String matchId;
  final DateTime matchDate;
  final String categoryId;
  final String categoryName;
  final String teamId;
  final String teamName;
  final String playerId;
  final String playerName;
  final int? shirtNumber;
  final int minute;
  final String eventType;

  _CardEventRow({
    required this.matchId,
    required this.matchDate,
    required this.categoryId,
    required this.categoryName,
    required this.teamId,
    required this.teamName,
    required this.playerId,
    required this.playerName,
    required this.shirtNumber,
    required this.minute,
    required this.eventType,
  });
}

class _SuspensionRow {
  final String matchId;
  final DateTime matchDate;
  final String categoryId;
  final String categoryName;
  final String teamId;
  final String teamName;
  final String playerId;
  final String playerName;
  final int? shirtNumber;
  final int matchesAffected;
  final String reason;
  final int minute;

  _SuspensionRow({
    required this.matchId,
    required this.matchDate,
    required this.categoryId,
    required this.categoryName,
    required this.teamId,
    required this.teamName,
    required this.playerId,
    required this.playerName,
    required this.shirtNumber,
    required this.matchesAffected,
    required this.reason,
    required this.minute,
  });
}

class _SuspensionSummaryRow {
  final String playerId;
  final String playerName;
  final int? shirtNumber;
  final int totalMatchesSuspended;

  _SuspensionSummaryRow({
    required this.playerId,
    required this.playerName,
    required this.shirtNumber,
    required this.totalMatchesSuspended,
  });
}

class _SanctionsViewModel {
  final List<SeasonCategory> categories;
  final List<Team> teams;
  final List<_CardEventRow> cardEvents;
  final List<_SuspensionRow> suspensions;
  final Map<String, int> cardTypeCounts;

  _SanctionsViewModel({
    required this.categories,
    required this.teams,
    required this.cardEvents,
    required this.suspensions,
    required this.cardTypeCounts,
  });

  factory _SanctionsViewModel.fromData(_SanctionsData data) {
    final teamById = {for (final team in data.teams) team.id: team};
    final playerById = {for (final p in data.players) p.id: p};
    final categoryById = {for (final c in data.categories) c.id: c};
    final matchById = {for (final m in data.matches) m.id: m};
    final lineupShirtByMatchPlayer = <String, int>{
      for (final s in data.lineupShirts) '${s.matchId}_${s.playerId}': s.shirtNumber,
    };

    final cardEvents = <_CardEventRow>[];
    final cardTypeCounts = <String, int>{};

    for (final event in data.events) {
      if (!_isCardEvent(event.eventType)) {
        continue;
      }

      final match = matchById[event.matchId];
      if (match == null) {
        continue;
      }

      final categoryId = match.categoryId ?? '';
      final categoryName = categoryById[categoryId]?.name ?? 'Sin categoria';
      final teamName = teamById[event.teamId]?.name ?? 'Sin equipo';
      final fallbackPlayer = playerById[event.playerId];
      final playerName = (event.playerName ?? '').trim().isNotEmpty
          ? (event.playerName ?? '').trim()
          : fallbackPlayer != null
              ? '${fallbackPlayer.firstName} ${fallbackPlayer.lastName}'.trim()
              : event.playerId;
      final lineupShirt =
          lineupShirtByMatchPlayer['${event.matchId}_${event.playerId}'];
      int? fallbackShirt;
      if (fallbackPlayer != null) {
        for (final teamInfo in fallbackPlayer.teamInfo) {
          if (teamInfo.teamId == event.teamId) {
            fallbackShirt = teamInfo.shirtNumber;
            break;
          }
        }
      }

      cardEvents.add(
        _CardEventRow(
          matchId: event.matchId,
          matchDate: match.matchDate,
          categoryId: categoryId,
          categoryName: categoryName,
          teamId: event.teamId,
          teamName: teamName,
          playerId: event.playerId,
          playerName: playerName,
          shirtNumber: event.shirtNumber ?? lineupShirt ?? fallbackShirt,
          minute: event.minute,
          eventType: event.eventType,
        ),
      );

      cardTypeCounts[event.eventType] = (cardTypeCounts[event.eventType] ?? 0) + 1;
    }

    cardEvents.sort((a, b) {
      final dateSort = b.matchDate.compareTo(a.matchDate);
      if (dateSort != 0) return dateSort;
      return b.minute.compareTo(a.minute);
    });

    final suspensions = _computeSuspensions(cardEvents);
    suspensions.sort((a, b) {
      final dateSort = b.matchDate.compareTo(a.matchDate);
      if (dateSort != 0) return dateSort;
      return b.minute.compareTo(a.minute);
    });

    final categoriesSorted = [...data.categories]
      ..sort((a, b) => a.name.compareTo(b.name));
    final teamsSorted = [...data.teams]..sort((a, b) => a.name.compareTo(b.name));

    return _SanctionsViewModel(
      categories: categoriesSorted,
      teams: teamsSorted,
      cardEvents: cardEvents,
      suspensions: suspensions,
      cardTypeCounts: cardTypeCounts,
    );
  }

  static bool _isCardEvent(String type) {
    return type == 'YELLOW' ||
        type == 'RED_DIRECT' ||
        type == 'DOBLE_YELLOW_RED';
  }

  static List<_SuspensionRow> _computeSuspensions(List<_CardEventRow> cardEvents) {
    final ordered = [...cardEvents]
      ..sort((a, b) {
        final dateSort = a.matchDate.compareTo(b.matchDate);
        if (dateSort != 0) return dateSort;
        return a.minute.compareTo(b.minute);
      });

    final seasonYellowCountByPlayer = <String, int>{};
    final yellowsInMatchByPlayer = <String, int>{};
    final suspensions = <_SuspensionRow>[];

    for (final event in ordered) {
      if (event.eventType == 'RED_DIRECT') {
        suspensions.add(
          _SuspensionRow(
            matchId: event.matchId,
            matchDate: event.matchDate,
            categoryId: event.categoryId,
            categoryName: event.categoryName,
            teamId: event.teamId,
            teamName: event.teamName,
            playerId: event.playerId,
            playerName: event.playerName,
            shirtNumber: event.shirtNumber,
            matchesAffected: 2,
            reason: 'Roja directa',
            minute: event.minute,
          ),
        );
        continue;
      }

      if (event.eventType == 'DOBLE_YELLOW_RED') {
        suspensions.add(
          _SuspensionRow(
            matchId: event.matchId,
            matchDate: event.matchDate,
            categoryId: event.categoryId,
            categoryName: event.categoryName,
            teamId: event.teamId,
            teamName: event.teamName,
            playerId: event.playerId,
            playerName: event.playerName,
            shirtNumber: event.shirtNumber,
            matchesAffected: 1,
            reason: 'Doble amarilla en el mismo partido',
            minute: event.minute,
          ),
        );
        continue;
      }

      if (event.eventType != 'YELLOW') {
        continue;
      }

      final matchKey = '${event.matchId}_${event.playerId}';
      final inMatch = (yellowsInMatchByPlayer[matchKey] ?? 0) + 1;
      yellowsInMatchByPlayer[matchKey] = inMatch;

      final inSeason = (seasonYellowCountByPlayer[event.playerId] ?? 0) + 1;
      seasonYellowCountByPlayer[event.playerId] = inSeason;

      if (inMatch == 2) {
        suspensions.add(
          _SuspensionRow(
            matchId: event.matchId,
            matchDate: event.matchDate,
            categoryId: event.categoryId,
            categoryName: event.categoryName,
            teamId: event.teamId,
            teamName: event.teamName,
            playerId: event.playerId,
            playerName: event.playerName,
            shirtNumber: event.shirtNumber,
            matchesAffected: 1,
            reason: 'Dos amarillas en el mismo partido',
            minute: event.minute,
          ),
        );
        continue;
      }

      if (inSeason % 5 == 0) {
        suspensions.add(
          _SuspensionRow(
            matchId: event.matchId,
            matchDate: event.matchDate,
            categoryId: event.categoryId,
            categoryName: event.categoryName,
            teamId: event.teamId,
            teamName: event.teamName,
            playerId: event.playerId,
            playerName: event.playerName,
            shirtNumber: event.shirtNumber,
            matchesAffected: 1,
            reason: 'Acumulacion de tarjetas amarillas',
            minute: event.minute,
          ),
        );
      }
    }

    return suspensions;
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CardsSummaryTable extends StatelessWidget {
  final List<CardsSummary> entries;

  const _CardsSummaryTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 46,
        columns: const [
          DataColumn(label: Text("Jugador")),
          DataColumn(label: Text("Dorsal")),
          DataColumn(label: Text("YELLOW")),
          DataColumn(label: Text("RED_DIRECT")),
        ],
        rows: entries.map((entry) {
          final name = entry.fullName.isEmpty ? entry.playerId : entry.fullName;
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(entry.shirtNumber?.toString() ?? "--")),
              DataCell(Text("${entry.yellowCards}")),
              DataCell(Text("${entry.redDirectCards}")),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SuspensionsSummaryTable extends StatelessWidget {
  final List<_SuspensionSummaryRow> entries;

  const _SuspensionsSummaryTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 46,
        columns: const [
          DataColumn(label: Text("Jugador")),
          DataColumn(label: Text("Dorsal")),
          DataColumn(label: Text("Partidos suspendido")),
        ],
        rows: entries.map((entry) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    entry.playerName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(entry.shirtNumber?.toString() ?? "--")),
              DataCell(Text("${entry.totalMatchesSuspended}")),
            ],
          );
        }).toList(),
      ),
    );
  }
}
