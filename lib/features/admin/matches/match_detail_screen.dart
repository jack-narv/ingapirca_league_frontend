import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/match_event.dart';
import '../../../models/match_lineup.dart';
import '../../../models/team.dart';
import '../../../services/auth_service.dart';
import '../../../services/live_match_service.dart';
import '../../../services/match_events_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/teams_service.dart';
import 'match_lineup_screen.dart';
import 'match_live_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({
    super.key,
    required this.match,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final MatchesService _service = MatchesService();
  final TeamsService _teamsService = TeamsService();
  final MatchEventsService _eventsService = MatchEventsService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final LiveMatchSocketService _socketService =
      LiveMatchSocketService(authService: AuthService());

  late Match _match;
  Map<String, Team> _teamsById = {};

  late Future<bool> _isAdminFuture;
  late Future<List<MatchLineupPlayer>> _homeLineupFuture;
  late Future<List<MatchLineupPlayer>> _awayLineupFuture;

  final List<Map<String, dynamic>> _events = [];
  final Map<String, String> _playerNamesById = {};
  final Map<String, int> _shirtByPlayerId = {};
  final Map<String, String> _teamIdByPlayerId = {};

  StreamSubscription? _scoreSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _startSub;
  StreamSubscription? _finishSub;

  bool _loading = false;
  bool _eventsLoading = true;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _isAdminFuture = AuthService().isAdmin();
    _prepareLineupFutures();
    _loadAll();
    _initLive();
  }

  @override
  void dispose() {
    _socketService.leaveMatch(_match.id);
    _scoreSub?.cancel();
    _eventSub?.cancel();
    _startSub?.cancel();
    _finishSub?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  void _prepareLineupFutures() {
    _homeLineupFuture =
        _lineupsService.getLineup(_match.id, _match.homeTeamId);
    _awayLineupFuture =
        _lineupsService.getLineup(_match.id, _match.awayTeamId);
  }

  Future<void> _loadAll() async {
    await _loadTeams();
    await _loadEvents();
    await _loadLineupCaches();
  }

  Future<void> _initLive() async {
    await _socketService.connect();
    _socketService.joinMatch(_match.id);

    _startSub = _socketService.matchStarted$.listen((_) {
      if (!mounted) return;
      setState(() {
        _match = Match(
          id: _match.id,
          seasonId: _match.seasonId,
          categoryId: _match.categoryId,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: 'PLAYING',
          homeScore: _match.homeScore,
          awayScore: _match.awayScore,
          observations: _match.observations,
        );
      });
    });

    _scoreSub = _socketService.score$.listen((data) {
      if (!mounted) return;
      final hs = data['homeScore'] ?? data['home_score'] ?? data['home'];
      final awayValue =
          data['awayScore'] ?? data['away_score'] ?? data['away'];

      setState(() {
        _match = Match(
          id: _match.id,
          seasonId: _match.seasonId,
          categoryId: _match.categoryId,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: _match.status,
          homeScore: hs is int ? hs : _match.homeScore,
          awayScore:
              awayValue is int ? awayValue : _match.awayScore,
          observations: _match.observations,
        );
      });
    });

    _eventSub = _socketService.event$.listen((event) {
      if (!mounted) return;
      final normalized = _normalizeEvent(event);
      setState(() {
        final id = normalized['id']?.toString();
        if (id != null &&
            id.isNotEmpty &&
            _events.any((e) => e['id']?.toString() == id)) {
          return;
        }
        _events.insert(0, normalized);
      });
    });

    _finishSub = _socketService.finished$.listen((data) {
      if (!mounted) return;
      final hs = data['homeScore'] ?? data['home_score'];
      final awayValue = data['awayScore'] ?? data['away_score'];
      setState(() {
        _match = Match(
          id: _match.id,
          seasonId: _match.seasonId,
          categoryId: _match.categoryId,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: 'PLAYED',
          homeScore: hs is int ? hs : _match.homeScore,
          awayScore:
              awayValue is int ? awayValue : _match.awayScore,
          observations: _match.observations,
        );
      });
    });
  }

  Future<void> _refresh() async {
    final updated = await _service.getMatch(_match.id);
    if (!mounted) return;

    setState(() {
      _match = updated;
      _prepareLineupFutures();
    });

    await _loadAll();
  }

  Future<void> _loadTeams() async {
    final teams = await _teamsService.getBySeason(_match.seasonId);
    if (!mounted) return;
    setState(() {
      _teamsById = {
        for (final team in teams) team.id: team,
      };
    });
  }

  Future<void> _loadLineupCaches() async {
    try {
      final home =
          await _lineupsService.getLineup(_match.id, _match.homeTeamId);
      final away =
          await _lineupsService.getLineup(_match.id, _match.awayTeamId);

      _playerNamesById.clear();
      _shirtByPlayerId.clear();
      _teamIdByPlayerId.clear();

      for (final p in home) {
        _playerNamesById[p.playerId] = p.playerName;
        _shirtByPlayerId[p.playerId] = p.shirtNumber;
        _teamIdByPlayerId[p.playerId] = _match.homeTeamId;
      }

      for (final p in away) {
        _playerNamesById[p.playerId] = p.playerName;
        _shirtByPlayerId[p.playerId] = p.shirtNumber;
        _teamIdByPlayerId[p.playerId] = _match.awayTeamId;
      }
    } catch (_) {
      // keep best-effort caches
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final timeline = await _eventsService.getTimeline(_match.id);
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(
            timeline.reversed.map(
              (e) => _normalizeEvent(_eventToMap(e)),
            ),
          );
      });
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Map<String, dynamic> _eventToMap(MatchEvent e) {
    return {
      'id': e.id,
      'event_type': e.eventType,
      'minute': e.minute,
      'team_id': e.teamId,
      'player_id': e.playerId,
      'player_name': e.playerName,
      'shirt_number': e.shirtNumber,
    };
  }

  Map<String, dynamic> _normalizeEvent(Map<String, dynamic> raw) {
    final playerId = (raw['player_id'] ?? '').toString();
    final playerName = (raw['player_name'] ?? '').toString();
    final explicitTeamId = (raw['team_id'] ?? '').toString();
    final inferredTeamId = explicitTeamId.isNotEmpty
        ? explicitTeamId
        : (_teamIdByPlayerId[playerId] ?? '');
    final rawTeamName = (raw['team_name'] ?? '').toString();
    final mappedTeamName = _teamNameOrEmpty(inferredTeamId);

    return {
      ...raw,
      'event_type':
          (raw['event_type'] ?? raw['type'] ?? 'EVENT').toString(),
      'minute': int.tryParse((raw['minute'] ?? 0).toString()) ?? 0,
      'team_id': inferredTeamId,
      'team_name': rawTeamName.isNotEmpty ? rawTeamName : mappedTeamName,
      'player_name': playerName.isNotEmpty
          ? playerName
          : (_playerNamesById[playerId] ?? playerId),
      'shirt_number': raw['shirt_number'] ?? _shirtByPlayerId[playerId],
    };
  }

  Future<void> _startMatch() async {
    setState(() => _loading = true);
    try {
      await _service.startMatch(_match.id);
      await _refresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishMatchDialog() async {
    final homeController = TextEditingController();
    final awayController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Finalizar partido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Goles Local'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: awayController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Goles Visitante'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.finishMatch(
                _match.id,
                int.tryParse(homeController.text) ?? 0,
                int.tryParse(awayController.text) ?? 0,
                null,
              );
              await _refresh();
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelMatch() async {
    await _service.cancelMatch(_match.id, null);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppScaffoldWithNav(
        title: 'Detalle Partido',
        currentIndex: 0,
        onNavTap: (_) {},
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildScoreboard(),
              const SizedBox(height: 16),
              _buildAdminActions(),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: 'Eventos'),
                    Tab(text: 'Alineaciones'),
                    Tab(text: 'Observaciones'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEventsTab(),
                    _buildLineupsTab(),
                    _buildObservationsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
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
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _teamInfo(
                  teamId: _match.homeTeamId,
                  alignEnd: false,
                ),
              ),
              Text(
                _match.status == 'SCHEDULED'
                    ? 'vs'
                    : '${_match.homeScore} - ${_match.awayScore}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: _match.status == 'PLAYING'
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

  Widget _buildAdminActions() {
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox();
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_match.status == 'SCHEDULED')
              ElevatedButton(
                onPressed: _loading ? null : _startMatch,
                child: const Text('Iniciar'),
              ),
            if (_match.status == 'PLAYING')
              ElevatedButton(
                onPressed: _finishMatchDialog,
                child: const Text('Finalizar'),
              ),
            if (_match.status != 'PLAYED')
              TextButton(
                onPressed: _cancelMatch,
                child: const Text('Cancelar'),
              ),
            if (_match.status == 'PLAYING')
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveMatchScreen(
                        matchId: _match.id,
                      ),
                    ),
                  );
                },
                child: const Text('Gestionar En Vivo'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEventsTab() {
    if (_eventsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return const Center(
        child: Text(
          'Aun no hay eventos',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _events.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final e = _events[index];
          final minute = e['minute']?.toString() ?? '0';
          final type = (e['event_type'] ?? 'EVENT').toString();
          final playerName = (e['player_name'] ?? '').toString();
          final shirt = e['shirt_number']?.toString();
          final teamName = (e['team_name'] ?? '').toString();
          final teamNameResolved = teamName.isNotEmpty
              ? teamName
              : _teamNameOrEmpty((e['team_id'] ?? '').toString());
          final icon = _eventIcon(type);
          final color = _eventColor(type);

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1A2332),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  "$minute'",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shirt == null || shirt.isEmpty
                            ? playerName
                            : '$playerName (#$shirt)',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (teamNameResolved.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          teamNameResolved,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildLineupsTab() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildLineupSection(
            title: _teamName(_match.homeTeamId),
            teamId: _match.homeTeamId,
            future: _homeLineupFuture,
          ),
          const SizedBox(height: 14),
          _buildLineupSection(
            title: _teamName(_match.awayTeamId),
            teamId: _match.awayTeamId,
            future: _awayLineupFuture,
          ),
        ],
      ),
    );
  }

  Widget _buildLineupSection({
    required String title,
    required String teamId,
    required Future<List<MatchLineupPlayer>> future,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2332),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              FutureBuilder<bool>(
                future: _isAdminFuture,
                builder: (context, snapshot) {
                  if (snapshot.data != true) {
                    return const SizedBox();
                  }
                  return TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchLineupScreen(
                            matchId: _match.id,
                            teamId: teamId,
                            teamName: title,
                          ),
                        ),
                      );
                      await _refresh();
                    },
                    child: const Text('Editar'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<MatchLineupPlayer>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final lineup = snapshot.data!;
              if (lineup.isEmpty) {
                return const Text(
                  'Sin alineacion',
                  style: TextStyle(color: Colors.white70),
                );
              }

              return Column(
                children: lineup.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.2),
                          child: Text(
                            p.shirtNumber.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.isStarting)
                          const Text(
                            'Titular',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsTab() {
    final obs = (_match.observations ?? '').trim();

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF1A2332),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Observaciones del partido',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                obs.isEmpty
                    ? 'Sin observaciones registradas.'
                    : obs,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _teamName(String teamId) {
    return _teamsById[teamId]?.name ?? teamId;
  }

  String _teamNameOrEmpty(String teamId) {
    if (teamId.isEmpty) return '';
    return _teamsById[teamId]?.name ?? '';
  }

  Widget _teamInfo({
    required String teamId,
    required bool alignEnd,
  }) {
    final team = _teamsById[teamId];
    final teamName = team?.name ?? teamId;
    final logoUrl = team?.logoUrl;
    final initials = teamName.isNotEmpty ? teamName[0].toUpperCase() : '?';

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignEnd)
          CircleAvatar(
            radius: 16,
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
            radius: 16,
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

  IconData _eventIcon(String type) {
    switch (type.toUpperCase()) {
      case 'GOAL':
        return Icons.sports_soccer;
      case 'YELLOW_CARD':
      case 'YELLOW':
        return Icons.square;
      case 'RED_CARD':
      case 'RED':
        return Icons.block;
      case 'SUBSTITUTION':
      case 'SUB_IN':
      case 'SUB_OUT':
        return Icons.swap_horiz;
      default:
        return Icons.bolt;
    }
  }

  Color _eventColor(String type) {
    switch (type.toUpperCase()) {
      case 'GOAL':
        return Colors.greenAccent;
      case 'YELLOW_CARD':
      case 'YELLOW':
        return Colors.amber;
      case 'RED_CARD':
      case 'RED':
        return Colors.redAccent;
      case 'SUBSTITUTION':
      case 'SUB_IN':
      case 'SUB_OUT':
        return Colors.cyanAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
