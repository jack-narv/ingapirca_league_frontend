import 'package:flutter/material.dart';
import '../../../services/leagues_service.dart';
import '../../../models/league.dart';
import 'create_league_screen.dart';
import '../../../services/auth_service.dart';
import '../seasons/seasons_list_screen.dart';

class AdminLeaguesListScreen extends StatefulWidget {
  const AdminLeaguesListScreen({super.key});

  @override
  State<AdminLeaguesListScreen> createState() =>
      _AdminLeagueListScreenState();
}

class _AdminLeagueListScreenState
    extends State<AdminLeaguesListScreen> {
  final LeaguesService _service = LeaguesService();
  late Future<List<League>> _leaguesFuture;

  @override
  void initState() {
    super.initState();
    _leaguesFuture = _service.getLeagues();
  }

  void _refresh() {
    setState(() {
      _leaguesFuture = _service.getLeagues();
    });
  }

  Widget _buildLeagueCard(League league) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeasonsListScreen(league: league),
          ),
        );
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
              color: Colors.black.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.15),
              ),
              child: Icon(
                Icons.emoji_events,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    league.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${league.country} • ${league.city}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 60,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            "No hay campeonatos aún",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
          left: 24, right: 24, top: 20),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Campeonatos",
            style:
                Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            "Administra las ligas registradas",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService().isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == false) {
            return const SizedBox();
          }

          return FloatingActionButton(
            backgroundColor:
                Theme.of(context).colorScheme.primary,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CreateLeagueScreen(),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<League>>(
        future: _leaguesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: Text(
                      "No hay campeonatos aún",
                      style: TextStyle(
                          color: Colors.white70),
                    ),
                  ),
                ),
              ],
            );
          }

          final leagues = snapshot.data!;

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24),
                  itemCount: leagues.length,
                  itemBuilder: (context, index) =>
                      _buildLeagueCard(
                          leagues[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
