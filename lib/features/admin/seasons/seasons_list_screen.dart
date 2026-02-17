import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/league.dart';
import '../../../models/season.dart';
import '../../../services/auth_service.dart';
import '../../../services/seasons_service.dart';
import '../../home/home_screen.dart';
import '../../home/home_screen_season.dart';
import 'create_season_screen.dart';

class SeasonsListScreen extends StatefulWidget {
  final League league;

  const SeasonsListScreen({
    super.key,
    required this.league,
  });

  @override
  State<SeasonsListScreen> createState() => _SeasonsListScreenState();
}

class _SeasonsListScreenState extends State<SeasonsListScreen> {
  final SeasonsService _service = SeasonsService();
  late Future<List<Season>> _seasonsFuture;

  @override
  void initState() {
    super.initState();
    _seasonsFuture = _service.getByLeague(widget.league.id);
  }

  void _refresh() {
    setState(() {
      _seasonsFuture = _service.getByLeague(widget.league.id);
    });
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

  Color _statusColor(String status) {
    switch (status) {
      case "ACTIVE":
        return Colors.green;
      case "FINISHED":
        return Colors.blueGrey;
      case "PLANNED":
      default:
        return Colors.orange;
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.league.name,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            "${widget.league.country} - ${widget.league.city}",
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Temporadas",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonCard(Season season) {
    final statusColor = _statusColor(season.status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreenSeason(season: season),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
              color: Colors.black.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.15),
              ),
              child: Icon(
                Icons.calendar_month,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    season.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      season.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Temporadas",
      currentIndex: 0,
      onNavTap: _handleBottomNavTap,
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService().isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == false) {
            return const SizedBox();
          }

          return FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateSeasonScreen(leagueId: widget.league.id),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<Season>>(
        future: _seasonsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: Text(
                      "No hay temporadas aun",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ],
            );
          }

          final seasons = snapshot.data!;

          return ListView(
            children: [
              _buildHeader(),
              ...seasons.map(_buildSeasonCard).toList(),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
