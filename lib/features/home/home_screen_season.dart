import 'package:flutter/material.dart';
import '../../core/widgets/app_scaffold_with_nav.dart';
import '../../models/season.dart';
import '../admin/referees/referees_list_screen.dart';
import '../admin/standings/standings_screen.dart';
import '../admin/teams/teams_list_screen.dart';
import '../admin/venues/venues_list_screen.dart';
import 'home_screen.dart';
import '../admin/seasons/season_statistics_screen.dart';
import '../admin/seasons/season_sanctions_screen.dart';
import '../admin/matches/matches_list_screen.dart';

class HomeScreenSeason extends StatelessWidget {
  final Season season;

  const HomeScreenSeason({
    super.key,
    required this.season,
  });

  void _handleBottomNavTap(BuildContext context, int index) {
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

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: season.name,
      currentIndex: 0,
      onNavTap: (index) => _handleBottomNavTap(context, index),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Temporada",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              season.status,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _DashboardCard(
                    title: "Equipos",
                    icon: Icons.groups,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TeamsListScreen(
                            seasonId: season.id,
                            seasonName: season.name,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Partidos",
                    icon: Icons.sports_soccer,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchesListScreen(
                            seasonId: season.id,
                            seasonName: season.name,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Estadisticas",
                    icon: Icons.leaderboard,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeasonStatisticsScreen(
                            season: season,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Sanciones",
                    icon: Icons.gavel,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeasonSanctionsScreen(
                            season: season,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Clasificacion",
                    icon: Icons.emoji_events_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StandingsScreen(
                            seasonId: season.id,
                            seasonName: season.name,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Arbitros",
                    icon: Icons.sports,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RefereesListScreen(
                            seasonId: season.id,
                            seasonName: season.name,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    title: "Escenarios",
                    icon: Icons.location_on,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VenuesListScreen(
                            seasonId: season.id,
                            seasonName: season.name,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//class MatchesListScreen extends StatefulWidget {
//  final String seasonId;
//  final String seasonName;
//
//  const MatchesListScreen({
//    super.key,
//    required this.seasonId,
//    required this.seasonName,
//  });
//
//  @override
//  State<MatchesListScreen> createState() =>
//      _MatchesListScreenState();
//}


class _DashboardCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
