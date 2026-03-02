import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/season_category.dart';
import '../../../models/standings.dart';
import '../../../models/team.dart';
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

  late Future<List<SeasonCategory>> _categoriesFuture;
  late Future<List<Standing>> _standingsFuture;
  String? _selectedCategoryId;
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _standingsFuture = _loadStandingsForCategory(categoryId);
    });
    _scrollToTop();
  }

  Future<List<Standing>> _loadStandingsForCategory(String categoryId) async {
    final results = await Future.wait([
      _standingsService.getBySeason(widget.seasonId, categoryId: categoryId),
      _teamsService.getBySeason(widget.seasonId, categoryId: categoryId),
    ]);

    final standings = results[0] as List<Standing>;
    final teams = results[1] as List<Team>;

    final teamIdsInStandings = standings
        .map((s) => s.teamId)
        .where((id) => id.isNotEmpty)
        .toSet();

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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 16,
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
            final isBottomTwo =
                rows.length >= 2 && index >= rows.length - 2;
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
                DataCell(SizedBox(width: 180, child: _buildTeamCell(row))),
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
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Clasificacion - ${widget.seasonName}",
      currentIndex: 3,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 3,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      body: FutureBuilder<List<Standing>>(
        future: _standingsFuture,
        builder: (context, standingsSnapshot) {
          if (!standingsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = standingsSnapshot.data!;

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              FutureBuilder<List<SeasonCategory>>(
                future: _categoriesFuture,
                builder: (context, categorySnapshot) {
                  final categories = categorySnapshot.data ?? [];
                  final validCategoryIds = categories
                      .map((c) => c.id)
                      .toSet();
                  final safeSelectedCategoryId =
                      validCategoryIds.contains(_selectedCategoryId)
                          ? _selectedCategoryId
                          : (categories.isNotEmpty ? categories.first.id : null);

                  if (safeSelectedCategoryId != null &&
                      safeSelectedCategoryId != _selectedCategoryId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _applyCategory(safeSelectedCategoryId);
                    });
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        safeSelectedCategoryId ?? 'no-categories',
                      ),
                      initialValue: safeSelectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: "Filtrar por categoria",
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ).toList(),
                      onChanged: categories.isEmpty
                          ? null
                          : (value) {
                              if (value == null) return;
                              _applyCategory(value);
                            },
                    ),
                  );
                },
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
                    Text(
                      rows.isEmpty ? "Sin datos aun" : "${rows.length} equipos",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: Center(
                    child: Text(
                      "No hay clasificacion disponible",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                _buildTable(rows),
            ],
          );
        },
      ),
    );
  }
}
