import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/season_category.dart';
import '../../../models/team.dart';
import '../../../services/auth_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';
import 'create_team_screen.dart';
import 'team_detail_screen.dart';

class TeamsListScreen extends StatefulWidget {
  final String seasonId;
  final String seasonName;

  const TeamsListScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<TeamsListScreen> createState() => _TeamsListScreenState();
}

class _TeamsListScreenState extends State<TeamsListScreen> {
  final TeamsService _service = TeamsService();
  final SeasonsService _seasonsService =
      SeasonsService();
  late Future<List<Team>> _teamsFuture;
  late Future<List<SeasonCategory>>
      _categoriesFuture;
  String? _selectedCategoryId;
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  @override
  void initState() {
    super.initState();
    _teamsFuture = _service.getBySeason(widget.seasonId);
    _categoriesFuture = _seasonsService
        .getCategoriesBySeason(widget.seasonId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _teamsFuture = _service.getBySeason(
        widget.seasonId,
        categoryId: _selectedCategoryId,
      );
    });
    _scrollToTop();
  }

  void _applyCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _teamsFuture = _service.getBySeason(
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

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: widget.seasonName,
      currentIndex: 2,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 2,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService().canManageTeams(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!) {
            return const SizedBox();
          }

          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTeamScreen(
                    seasonId: widget.seasonId,
                    seasonName: widget.seasonName,
                  ),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<Team>>(
        future: _teamsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teams = snapshot.data!;
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: teams.isEmpty ? 2 : teams.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return FutureBuilder<List<SeasonCategory>>(
                  future: _categoriesFuture,
                  builder: (context, categorySnapshot) {
                    final categories =
                        categorySnapshot.data ?? [];
                    final validCategoryIds = categories
                        .map((c) => c.id)
                        .toSet();
                    final safeSelectedCategoryId =
                        validCategoryIds.contains(_selectedCategoryId)
                            ? _selectedCategoryId
                            : null;

                    return Container(
                      margin: const EdgeInsets.only(
                          bottom: 16),
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(
                          'team-category-${safeSelectedCategoryId ?? 'all'}',
                        ),
                        initialValue: safeSelectedCategoryId,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Filtrar por categoria",
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                                "Todas las categorias"),
                          ),
                          ...categories.map((category) =>
                              DropdownMenuItem<String?>(
                                value: category.id,
                                child:
                                    Text(category.name),
                              )),
                        ],
                        onChanged: _applyCategory,
                      ),
                    );
                  },
                );
              }

              if (teams.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text("No hay equipos aun"),
                  ),
                );
              }

              final team = teams[index - 1];
              final logo = _buildTeamLogo(team.logoUrl);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(
                      team: team,
                      seasonId: widget.seasonId,
                      seasonName: widget.seasonName,
                    ),
                  ),
                );
              },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFF1A2332),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white10,
                        foregroundImage: logo,
                        onForegroundImageError:
                            logo != null ? (_, _) {} : null,
                        child: const Icon(
                          Icons.shield,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (team.foundedYear != null)
                              Text(
                                "Fundado en ${team.foundedYear}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              team.logoUrl?.trim().isNotEmpty == true
                                  ? team.logoUrl!
                                  : "Sin logo_url",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  ImageProvider<Object>? _buildTeamLogo(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    return NetworkImage(value);
  }
}
