import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../services/matches_service.dart';
import '../../../services/teams_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/match.dart';
import '../../../models/team.dart';
import 'match_lineup_screen.dart';
import 'match_live_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({
    super.key,
    required this.match,
  });

  @override
  State<MatchDetailScreen> createState() =>
      _MatchDetailScreenState();
}

class _MatchDetailScreenState
    extends State<MatchDetailScreen> {
  final MatchesService _service = MatchesService();
  final TeamsService _teamsService = TeamsService();
  late Match _match;
  Map<String, Team> _teamsById = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _loadTeams();
  }

  Future<void> _refresh() async {
    final updated =
        await _service.getMatch(_match.id);
    setState(() {
      _match = updated;
    });
    await _loadTeams();
  }

  Future<void> _loadTeams() async {
    final teams =
        await _teamsService.getBySeason(_match.seasonId);
    if (!mounted) return;
    setState(() {
      _teamsById = {
        for (final team in teams) team.id: team,
      };
    });
  }

  Future<void> _startMatch() async {
    setState(() => _loading = true);
    await _service.startMatch(_match.id);
    await _refresh();
    setState(() => _loading = false);
  }

  Future<void> _finishMatchDialog() async {
    final homeController =
        TextEditingController();
    final awayController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text("Finalizar partido"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                      labelText:
                          "Goles Local"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: awayController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                      labelText:
                          "Goles Visitante"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.finishMatch(
                _match.id,
                int.parse(
                    homeController.text),
                int.parse(
                    awayController.text),
                null,
              );
              await _refresh();
            },
            child: const Text("Finalizar"),
          )
        ],
      ),
    );
  }

  Future<void> _cancelMatch() async {
    await _service.cancelMatch(
      _match.id,
      null,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Detalle Partido",
      currentIndex: 0,
      onNavTap: (_) {},
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildScoreboard(),
            const SizedBox(height: 30),
            _buildActions(),
            const SizedBox(height: 30),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
                    alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _match.status,
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _teamInfo(
                  teamId: _match.homeTeamId,
                  alignEnd: false,
                ),
              ),
              Text(
                _match.status ==
                        "SCHEDULED"
                    ? "vs"
                    : "${_match.homeScore} - ${_match.awayScore}",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                  color: _match.status ==
                          "PLAYING"
                      ? Colors.greenAccent
                      : Colors.white,
                ),
              ),
              Expanded(
                child: _teamInfo(
                  teamId: _match.awayTeamId,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return FutureBuilder<bool>(
      future: AuthService().isAdmin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            !snapshot.data!) {
          return const SizedBox();
        }

        return Column(
          children: [
            if (_match.status ==
                "SCHEDULED")
              ElevatedButton(
                onPressed:
                    _loading ? null : _startMatch,
                child:
                    const Text("Iniciar Partido"),
              ),
            if (_match.status ==
                "PLAYING")
              ElevatedButton(
                onPressed:
                    _finishMatchDialog,
                child: const Text(
                    "Finalizar Partido"),
              ),
            if (_match.status !=
                "PLAYED")
              TextButton(
                onPressed:
                    _cancelMatch,
                child:
                    const Text("Cancelar Partido"),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MatchLineupScreen(
                  matchId: _match.id,
                  teamId: _match.homeTeamId,
                  teamName: _teamName(_match.homeTeamId),
                ),
              ),
            );
          },
          child: const Text(
              "Alineacion Local"),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MatchLineupScreen(
                  matchId: _match.id,
                  teamId: _match.awayTeamId,
                  teamName: _teamName(_match.awayTeamId),
                ),
              ),
            );
          },
          child: const Text(
              "Alineacion Visitante"),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _match.status ==
                  "PLAYING"
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LiveMatchScreen(
                        matchId:
                            _match.id,
                      ),
                    ),
                  );
                }
              : null,
          child:
              const Text("Pantalla en Vivo"),
        ),
      ],
    );
  }

  String _teamName(String teamId) {
    return _teamsById[teamId]?.name ?? teamId;
  }

  Widget _teamInfo({
    required String teamId,
    required bool alignEnd,
  }) {
    final team = _teamsById[teamId];
    final teamName = team?.name ?? teamId;
    final logoUrl = team?.logoUrl;
    final initials =
        teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignEnd)
          CircleAvatar(
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
          ),
        if (!alignEnd) const SizedBox(width: 8),
        Flexible(
          child: Text(
            teamName,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (alignEnd) const SizedBox(width: 8),
        if (alignEnd)
          CircleAvatar(
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
          ),
      ],
    );
  }
}
