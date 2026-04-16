import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/season_category.dart';
import '../../../models/standings.dart';
import '../../../models/team.dart';
import '../../../services/auth_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/standings_service.dart';
import '../../../services/teams_service.dart';

class StandingsScreen extends StatefulWidget {
  final String seasonId;
  final String seasonName;

  const StandingsScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final StandingsService _standingsService = StandingsService();
  final SeasonsService _seasonsService = SeasonsService();
  final TeamsService _teamsService = TeamsService();
  final MatchesService _matchesService = MatchesService();
  final AuthService _authService = AuthService();

  late Future<List<SeasonCategory>> _categoriesFuture;
  late Future<List<Standing>> _standingsFuture;
  late Future<_EliminationData> _eliminationFuture;

  String? _selectedCategoryId;
  String? _selectedEliminationCategoryId;
  bool _isAdmin = false;
  bool _isRefreshingStandings = false;

  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _categoriesFuture = _seasonsService.getCategoriesBySeason(widget.seasonId);
    _standingsFuture = _categoriesFuture.then((categories) {
      if (categories.isEmpty) {
        _selectedCategoryId = null;
        return <Standing>[];
      }

      final initialCategoryId = categories.first.id;
      _selectedCategoryId = initialCategoryId;
      return _loadStandingsForCategory(initialCategoryId);
    });

    _eliminationFuture = _categoriesFuture.then((categories) {
      if (categories.isEmpty) {
        _selectedEliminationCategoryId = null;
        return const _EliminationData(
          knockoutMatches: <Match>[],
          teamsById: <String, Team>{},
        );
      }

      final initialCategoryId = categories.first.id;
      _selectedEliminationCategoryId = initialCategoryId;
      return _loadEliminationData(initialCategoryId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    final isAdmin = await _authService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  void _applyCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _standingsFuture = _loadStandingsForCategory(categoryId);
    });
    _scrollToTop();
  }

  void _applyEliminationCategory(String categoryId) {
    setState(() {
      _selectedEliminationCategoryId = categoryId;
      _eliminationFuture = _loadEliminationData(categoryId);
    });
  }

  Future<List<Standing>> _loadStandingsForCategory(String categoryId) async {
    final results = await Future.wait([
      _standingsService.getBySeason(widget.seasonId, categoryId: categoryId),
      _teamsService.getBySeason(widget.seasonId, categoryId: categoryId),
    ]);

    final standings = results[0] as List<Standing>;
    final teams = results[1] as List<Team>;

    final teamIdsInStandings = standings.map((s) => s.teamId).where((id) => id.isNotEmpty).toSet();

    final missingRows = teams.where((team) {
      final teamId = team.id;
      return teamId.isNotEmpty && !teamIdsInStandings.contains(teamId);
    }).map((team) {
      return Standing(
        id: 'virtual-${team.id}',
        seasonId: widget.seasonId,
        teamId: team.id,
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        points: 0,
        teamName: team.name,
        teamLogoUrl: team.logoUrl,
        teamCategoryId: team.categoryId ?? categoryId,
      );
    });

    final merged = <Standing>[
      ...standings,
      ...missingRows,
    ];

    merged.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;

      final byGoalDiff = b.goalDifference.compareTo(a.goalDifference);
      if (byGoalDiff != 0) return byGoalDiff;

      final byGoalsFor = b.goalsFor.compareTo(a.goalsFor);
      if (byGoalsFor != 0) return byGoalsFor;

      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });

    return merged;
  }

  Future<_EliminationData> _loadEliminationData(String categoryId) async {
    final results = await Future.wait([
      _matchesService.getBySeason(
        widget.seasonId,
        categoryId: categoryId,
      ),
      _teamsService.getBySeason(
        widget.seasonId,
        categoryId: categoryId,
      ),
    ]);

    final allMatches = results[0] as List<Match>;
    final teams = results[1] as List<Team>;

    final knockoutMatches = allMatches
        .where(
          (m) =>
              _isKnockoutJournal(m.journal) &&
              m.status.toUpperCase() != 'CANCELED',
        )
        .toList()
      ..sort((a, b) => a.matchDate.compareTo(b.matchDate));

    return _EliminationData(
      knockoutMatches: knockoutMatches,
      teamsById: {
        for (final team in teams) team.id: team,
      },
    );
  }

  bool _isKnockoutJournal(String? journal) {
    final raw = journal?.trim() ?? '';
    if (raw.isEmpty) return false;

    if (RegExp(r'^\d+$').hasMatch(raw)) return false;
    if (RegExp(r'^JOURNAL\s+\d+$', caseSensitive: false).hasMatch(raw)) {
      return false;
    }

    return true;
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  Future<void> _refreshStandingsManually() async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null || _isRefreshingStandings) return;

    setState(() {
      _isRefreshingStandings = true;
    });

    try {
      await _standingsService.recalculateSeason(
        widget.seasonId,
        categoryId: categoryId,
      );

      if (!mounted) return;
      setState(() {
        _standingsFuture = _loadStandingsForCategory(categoryId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tabla actualizada correctamente'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la tabla: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshingStandings = false;
      });
    }
  }

  Widget _buildTeamCell(Standing row) {
    final logoUrl = row.teamLogoUrl?.trim() ?? '';
    final hasLogo = logoUrl.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.white10,
          foregroundImage: hasLogo ? NetworkImage(logoUrl) : null,
          child: !hasLogo
              ? Text(
                  row.teamName.isNotEmpty ? row.teamName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            row.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Standing> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                horizontalMargin: 8,
                columnSpacing: 10,
                headingTextStyle: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Equipo')),
                  DataColumn(numeric: true, label: Text('Pts')),
                  DataColumn(numeric: true, label: Text('PJ')),
                  DataColumn(numeric: true, label: Text('G')),
                  DataColumn(numeric: true, label: Text('E')),
                  DataColumn(numeric: true, label: Text('P')),
                  DataColumn(numeric: true, label: Text('GF')),
                  DataColumn(numeric: true, label: Text('GC')),
                  DataColumn(numeric: true, label: Text('DG')),
                ],
                rows: List.generate(rows.length, (index) {
                  final row = rows[index];
                  final isTopFour = index < 4;
                  final isBottomTwo = rows.length >= 2 && index >= rows.length - 2;
                  final rankColor = isTopFour
                      ? const Color(0xFF22D3EE)
                      : isBottomTwo
                          ? const Color(0xFFFF6B6B)
                          : Colors.white70;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      DataCell(SizedBox(width: 120, child: _buildTeamCell(row))),
                      DataCell(
                        Text(
                          "${row.points}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ),
                      DataCell(Text("${row.played}")),
                      DataCell(Text("${row.wins}")),
                      DataCell(Text("${row.draws}")),
                      DataCell(Text("${row.losses}")),
                      DataCell(Text("${row.goalsFor}")),
                      DataCell(Text("${row.goalsAgainst}")),
                      DataCell(Text("${row.goalDifference}")),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Clasificación - ${widget.seasonName}",
      currentIndex: 3,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 3,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      body: FutureBuilder<List<SeasonCategory>>(
        future: _categoriesFuture,
        builder: (context, categorySnapshot) {
          if (!categorySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data ?? [];

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
                      Tab(text: "CLASIFICACIÓN"),
                      Tab(text: "ELIMINACIÓN"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildClassificationTab(categories),
                      _buildEliminationTab(categories),
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

  Widget _buildClassificationTab(List<SeasonCategory> categories) {
    return FutureBuilder<List<Standing>>(
      future: _standingsFuture,
      builder: (context, standingsSnapshot) {
        if (!standingsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = standingsSnapshot.data!;
        final validCategoryIds = categories.map((c) => c.id).toSet();
        final safeSelectedCategoryId = validCategoryIds.contains(_selectedCategoryId)
            ? _selectedCategoryId
            : (categories.isNotEmpty ? categories.first.id : null);

        if (safeSelectedCategoryId != null && safeSelectedCategoryId != _selectedCategoryId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _applyCategory(safeSelectedCategoryId);
          });
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'classification-${safeSelectedCategoryId ?? 'no-categories'}',
                ),
                initialValue: safeSelectedCategoryId,
                decoration: const InputDecoration(
                  labelText: "Filtrar por categoria",
                  prefixIcon: Icon(Icons.category),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: categories.isEmpty
                    ? null
                    : (value) {
                        if (value == null) return;
                        _applyCategory(value);
                      },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1A2332),
              ),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: Color(0xFF22D3EE)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows.isEmpty ? "Sin datos aun" : "${rows.length} equipos",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  if (_isAdmin)
                    FilledButton.icon(
                      onPressed: _isRefreshingStandings
                          ? null
                          : _refreshStandingsManually,
                      icon: _isRefreshingStandings
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Actualizar tabla'),
                    ),
                ],
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 90),
                child: Center(
                  child: Text(
                    "No hay clasificación disponible",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              _buildTable(rows),
          ],
        );
      },
    );
  }

  Widget _buildEliminationTab(List<SeasonCategory> categories) {
    final validCategoryIds = categories.map((c) => c.id).toSet();
    final safeSelectedCategoryId = validCategoryIds.contains(_selectedEliminationCategoryId)
        ? _selectedEliminationCategoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    if (safeSelectedCategoryId != null && safeSelectedCategoryId != _selectedEliminationCategoryId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyEliminationCategory(safeSelectedCategoryId);
      });
    }

    return FutureBuilder<_EliminationData>(
      future: _eliminationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final rounds = _buildKnockoutRounds(data.knockoutMatches);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'elimination-${safeSelectedCategoryId ?? 'no-categories'}',
                ),
                initialValue: safeSelectedCategoryId,
                decoration: const InputDecoration(
                  labelText: "Filtrar por categoria",
                  prefixIcon: Icon(Icons.category),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                onChanged: categories.isEmpty
                    ? null
                    : (value) {
                        if (value == null) return;
                        _applyEliminationCategory(value);
                      },
              ),
            ),
            if (rounds.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 90),
                child: Center(
                  child: Text(
                    "No hay partidos de eliminación para esta categoria",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(rounds.length, (index) {
                    final round = rounds[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BracketRoundColumn(
                          round: round,
                          teamsById: data.teamsById,
                        ),
                        if (index < rounds.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 120),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  List<_BracketRound> _buildKnockoutRounds(List<Match> matches) {
    if (matches.isEmpty) return const <_BracketRound>[];

    final grouped = <int, List<Match>>{};

    for (final match in matches) {
      final stage = _matchStage(match.journal);
      if (stage == null) continue;
      grouped.putIfAbsent(stage.order, () => <Match>[]).add(match);
    }

    if (grouped.isEmpty) return const <_BracketRound>[];

    for (final list in grouped.values) {
      list.sort((a, b) {
        final byDate = a.matchDate.compareTo(b.matchDate);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
    }

    final startOrder = grouped.keys.reduce((a, b) => a < b ? a : b);
    final rounds = <_BracketRound>[];
    var expectedSlots = grouped[startOrder]!.length;
    if (expectedSlots <= 0) expectedSlots = 1;

    for (var order = startOrder; order <= _KnockoutStage.finalStage.order; order++) {
      final stage = _KnockoutStage.byOrder(order);
      if (stage == null) continue;

      final stageMatches = grouped[order] ?? <Match>[];
      if (order > startOrder) {
        final derived = (expectedSlots / 2).ceil();
        expectedSlots = derived > stageMatches.length ? derived : stageMatches.length;
      }

      if (stage.isFinal) {
        expectedSlots = stageMatches.length > 1 ? stageMatches.length : 1;
      }

      final slots = List<Match?>.filled(expectedSlots, null);
      for (var i = 0; i < stageMatches.length && i < slots.length; i++) {
        slots[i] = stageMatches[i];
      }

      rounds.add(
        _BracketRound(
          stage: stage,
          slots: slots,
        ),
      );
    }

    return rounds;
  }

  _KnockoutStage? _matchStage(String? journal) {
    final normalized = _normalizeJournalText(journal);
    if (normalized.isEmpty) return null;

    if (normalized.contains('SEMIFINAL') || normalized.contains('SEMI FINAL')) {
      return _KnockoutStage.semiFinal;
    }

    if (normalized == 'FINAL' || normalized.endsWith(' FINAL') || normalized.startsWith('FINAL ')) {
      return _KnockoutStage.finalStage;
    }

    if (normalized.contains('CUARTOS') ||
        normalized.contains('CUARTO FINAL') ||
        normalized.contains('QUARTERFINAL') ||
        normalized.contains('QUARTER FINAL')) {
      return _KnockoutStage.quarterFinal;
    }

    if (normalized.contains('OCTAVOS') ||
        normalized.contains('ROUND OF 16') ||
        normalized.contains('ROUND OF 8')) {
      return _KnockoutStage.roundOf16;
    }

    if (normalized.contains('ROUND OF 32')) {
      return _KnockoutStage.roundOf32;
    }

    return null;
  }

  String _normalizeJournalText(String? journal) {
    final input = (journal ?? '').trim().toUpperCase();
    if (input.isEmpty) return '';

    return input
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('_', ' ');
  }
}

class _EliminationData {
  final List<Match> knockoutMatches;
  final Map<String, Team> teamsById;

  const _EliminationData({
    required this.knockoutMatches,
    required this.teamsById,
  });
}

class _BracketRound {
  final _KnockoutStage stage;
  final List<Match?> slots;

  const _BracketRound({
    required this.stage,
    required this.slots,
  });
}

class _KnockoutStage {
  final int order;
  final String label;
  final bool isFinal;

  const _KnockoutStage._({
    required this.order,
    required this.label,
    this.isFinal = false,
  });

  static const roundOf32 = _KnockoutStage._(
    order: 0,
    label: 'Round of 32',
  );
  static const roundOf16 = _KnockoutStage._(
    order: 1,
    label: 'Octavos de final',
  );
  static const quarterFinal = _KnockoutStage._(
    order: 2,
    label: 'Cuartos de final',
  );
  static const semiFinal = _KnockoutStage._(
    order: 3,
    label: 'Semifinal',
  );
  static const finalStage = _KnockoutStage._(
    order: 4,
    label: 'Final',
    isFinal: true,
  );

  static _KnockoutStage? byOrder(int order) {
    switch (order) {
      case 0:
        return roundOf32;
      case 1:
        return roundOf16;
      case 2:
        return quarterFinal;
      case 3:
        return semiFinal;
      case 4:
        return finalStage;
      default:
        return null;
    }
  }
}

class _BracketRoundColumn extends StatelessWidget {
  final _BracketRound round;
  final Map<String, Team> teamsById;

  const _BracketRoundColumn({
    required this.round,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  round.stage.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${round.slots.whereType<Match>().length}/${round.slots.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(round.slots.length, (index) {
            final slot = round.slots[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == round.slots.length - 1 ? 0 : 12,
              ),
              child: _BracketMatchCard(
                match: slot,
                teamsById: teamsById,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  final Match? match;
  final Map<String, Team> teamsById;

  const _BracketMatchCard({
    required this.match,
    required this.teamsById,
  });

  @override
  Widget build(BuildContext context) {
    final homeTeam = match == null ? null : teamsById[match!.homeTeamId];
    final awayTeam = match == null ? null : teamsById[match!.awayTeamId];

    final homeName = homeTeam?.name ?? (match == null ? 'TBD' : match!.homeTeamId);
    final awayName = awayTeam?.name ?? (match == null ? 'TBD' : match!.awayTeamId);

    final homeLogo = homeTeam?.logoUrl;
    final awayLogo = awayTeam?.logoUrl;

    final isPlayedOrPlaying = match != null &&
        (match!.status.toUpperCase() == 'PLAYED' || match!.status.toUpperCase() == 'PLAYING');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _teamRow(
            teamName: homeName,
            logoUrl: homeLogo,
          ),
          const SizedBox(height: 8),
          _teamRow(
            teamName: awayName,
            logoUrl: awayLogo,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.sports_soccer,
                size: 14,
                color: isPlayedOrPlaying ? const Color(0xFF22D3EE) : Colors.white38,
              ),
              const SizedBox(width: 6),
              Text(
                match == null
                    ? 'Por definir'
                    : isPlayedOrPlaying
                        ? '${match!.homeScore} - ${match!.awayScore}'
                        : 'Por jugar',
                style: TextStyle(
                  color: isPlayedOrPlaying ? const Color(0xFF22D3EE) : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamRow({
    required String teamName,
    required String? logoUrl,
  }) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;
    final safeName = teamName.trim().isEmpty ? 'TBD' : teamName.trim();
    final initials = safeName[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Colors.white10,
          foregroundImage: hasLogo ? NetworkImage(logoUrl!.trim()) : null,
          child: hasLogo
              ? null
              : Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            safeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
