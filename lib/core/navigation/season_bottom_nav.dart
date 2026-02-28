import 'package:flutter/material.dart';
import '../../features/admin/matches/matches_list_screen.dart';
import '../../features/admin/standings/standings_screen.dart';
import '../../features/admin/teams/teams_list_screen.dart';
import '../../features/home/home_screen_season.dart';

const List<BottomNavigationBarItem> seasonNavItems = [
  BottomNavigationBarItem(
    icon: Icon(Icons.home_outlined),
    label: 'Inicio',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.sports_soccer),
    label: 'Partidos',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.groups),
    label: 'Equipos',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.emoji_events_outlined),
    label: 'Tabla',
  ),
];

void handleSeasonNavTap(
  BuildContext context, {
  required int tappedIndex,
  required int currentIndex,
  required String seasonId,
  required String seasonName,
}) {
  if (tappedIndex == currentIndex) return;

  Widget destination;
  switch (tappedIndex) {
    case 0:
      destination = HomeScreenSeason.basic(
        seasonId: seasonId,
        seasonName: seasonName,
      );
      break;
    case 1:
      destination = MatchesListScreen(
        seasonId: seasonId,
        seasonName: seasonName,
      );
      break;
    case 2:
      destination = TeamsListScreen(
        seasonId: seasonId,
        seasonName: seasonName,
      );
      break;
    case 3:
      destination = StandingsScreen(
        seasonId: seasonId,
        seasonName: seasonName,
      );
      break;
    default:
      return;
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => destination),
  );
}
