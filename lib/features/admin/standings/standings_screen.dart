import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/season_category.dart';
import '../../../models/standings.dart';
import '../../../services/seasons_service.dart';
import '../../../services/standings_service.dart';
import '../../home/home_screen.dart';

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
    _standingsFuture = _standingsService.getBySeason(widget.seasonId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleBottomNavTap(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 1)),
      (route) => false,
    );
  }

  void _applyCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _standingsFuture = _standingsService.getBySeason(
        widget.seasonId,
        categoryId: categoryId,
      );
    });
    _scrollToTop();
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
      currentIndex: 0,
      onNavTap: _handleBottomNavTap,
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
                          : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(
                        safeSelectedCategoryId ?? 'all-categories',
                      ),
                      initialValue: safeSelectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: "Filtrar por categoria",
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text("Todas las categorias"),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: _applyCategory,
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
