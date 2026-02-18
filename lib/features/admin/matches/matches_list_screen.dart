import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/season_category.dart';
import '../../../services/matches_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/match.dart';
import '../../../models/team.dart';
import 'create_match_screen.dart';
import 'match_detail_screen.dart';

class MatchesListScreen extends StatefulWidget{
  final String seasonId;
  final String seasonName;

  const MatchesListScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<MatchesListScreen> createState() =>
    _MatchesListScreenState();
}

class _MatchesListScreenState
  extends State<MatchesListScreen> {
    final MatchesService _service = MatchesService();
    final TeamsService _teamsService = TeamsService();
    final SeasonsService _seasonsService =
        SeasonsService();
    late Future<List<Match>> _future;
    late Future<List<Team>> _teamsFuture;
    late Future<List<SeasonCategory>>
        _categoriesFuture;
    SeasonCategory? _selectedCategory;
    Map<String, Team> _teamsById = {};

    @override
    void initState(){
      super.initState();
      _future = _service.getBySeason(
        widget.seasonId,
      );
      _teamsFuture = _teamsService.getBySeason(
        widget.seasonId,
      );
      _categoriesFuture = _seasonsService
          .getCategoriesBySeason(widget.seasonId);
      _loadTeams();
    }

    void _refresh(){
      setState(() {
        _future = _service.getBySeason(
          widget.seasonId,
          categoryId: _selectedCategory?.id,
        );
        _teamsFuture = _teamsService.getBySeason(
          widget.seasonId,
          categoryId: _selectedCategory?.id,
        );
      });
      _loadTeams();
    }

    Future<void> _loadTeams() async {
      final teams = await _teamsFuture;
      if (!mounted) return;
      setState(() {
        _teamsById = {
          for (final team in teams) team.id: team,
        };
      });
    }

    Future<void> _applyCategory(
      SeasonCategory? category,
    ) async {
      setState(() {
        _selectedCategory = category;
        _future = _service.getBySeason(
          widget.seasonId,
          categoryId: category?.id,
        );
        _teamsFuture = _teamsService.getBySeason(
          widget.seasonId,
          categoryId: category?.id,
        );
      });
      await _loadTeams();
    }

    @override
    Widget build(BuildContext context) {
      return AppScaffoldWithNav(
        title: "Partidos - ${widget.seasonName}",
        currentIndex: 0,
        onNavTap: (_) {},
        floatingActionButton: FutureBuilder<bool>(
          future: AuthService().isAdmin(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!) {
              return const SizedBox();
            }

            return FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateMatchScreen(
                          seasonId: widget.seasonId,
                        ),
                  ),
                );
                _refresh();
              },
              child: const Icon(Icons.add),
            );
          },
        ),
      body: FutureBuilder<List<Match>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator());
            }

            final matches = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FutureBuilder<List<SeasonCategory>>(
                  future: _categoriesFuture,
                  builder: (context, categorySnapshot) {
                    final categories =
                        categorySnapshot.data ?? [];

                    return Container(
                      margin: const EdgeInsets.only(
                          bottom: 18),
                      child: DropdownButtonFormField<
                          SeasonCategory?>(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(
                          labelText:
                              "Filtrar por categoria",
                        ),
                        items: [
                          const DropdownMenuItem<
                              SeasonCategory?>(
                            value: null,
                            child: Text(
                                "Todas las categorias"),
                          ),
                          ...categories.map((category) =>
                              DropdownMenuItem<
                                  SeasonCategory?>(
                                value: category,
                                child:
                                    Text(category.name),
                              )),
                        ],
                        onChanged: _applyCategory,
                      ),
                    );
                  },
                ),
                if (matches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(
                      child: Text(
                        "No hay partidos programados",
                        style: TextStyle(
                            color: Colors.white70),
                      ),
                    ),
                  ),
                ...matches.map(
                  (match) => _buildMatchCard(match),
                ),
              ],
            );
          },
        ),
      );
    }

    Widget _buildMatchCard(Match match) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MatchDetailScreen(match: match),
            ),
          ).then((_) => _refresh());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
                color: Colors.black.withValues(
                    alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _statusBadge(match.status),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _teamInfo(
                      teamId: match.homeTeamId,
                      alignEnd: false,
                    ),
                  ),
                  _scoreWidget(match),
                  Expanded(
                    child: _teamInfo(
                      teamId: match.awayTeamId,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 16,
                      color: Colors.white54),
                  const SizedBox(width: 6),
                  Text(
                    "${match.matchDate.day}/${match.matchDate.month}/${match.matchDate.year} "
                    "${match.matchDate.hour}:${match.matchDate.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget _scoreWidget(Match match) {
      if (match.status == 'SCHEDULED') {
        return const Text(
          "vs",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        );
      }

      return Text(
        "${match.homeScore} - ${match.awayScore}",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: match.status == 'PLAYING'
              ? Colors.greenAccent
              : Colors.white,
        ),
      );
    }

    Widget _statusBadge(String status) {
      Color color;

      switch (status) {
        case 'SCHEDULED':
          color = Colors.orange;
          break;
        case 'PLAYING':
          color = Colors.green;
          break;
        case 'PLAYED':
          color = Colors.blue;
          break;
        case 'CANCELED':
          color = Colors.red;
          break;
        default:
          color = Colors.grey;
      }

      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Widget _teamInfo({
      required String teamId,
      required bool alignEnd,
    }) {
      final team = _teamsById[teamId];
      final teamName = team?.name ?? teamId;
      final logoUrl = team?.logoUrl;

      return Row(
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!alignEnd) _teamLogo(logoUrl, teamName),
          if (!alignEnd) const SizedBox(width: 8),
          Flexible(
            child: Text(
              teamName,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (alignEnd) const SizedBox(width: 8),
          if (alignEnd) _teamLogo(logoUrl, teamName),
        ],
      );
    }

    Widget _teamLogo(String? logoUrl, String teamName) {
      final initials = teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';

      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFF1A2332),
        backgroundImage: (logoUrl != null && logoUrl.isNotEmpty)
            ? NetworkImage(logoUrl)
            : null,
        child: (logoUrl == null || logoUrl.isEmpty)
            ? Text(
                initials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }
}
    
