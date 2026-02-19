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
import 'add_match_event_dialog.dart';

class LiveMatchScreen extends StatefulWidget {
  final String matchId;

  const LiveMatchScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final LiveMatchSocketService _socketService;

  final MatchesService _matchesService = MatchesService();
  final MatchEventsService _eventsService = MatchEventsService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final TeamsService _teamsService = TeamsService();

  bool _connected = false;
  bool _canAddEvents = false;
  bool _bootstrapping = true;

  int _homeScore = 0;
  int _awayScore = 0;

  final List<Map<String, dynamic>> _events = [];
  Match? _match;
  Team? _homeTeam;
  Team? _awayTeam;
  List<MatchLineupPlayer> _homeLineup = [];
  List<MatchLineupPlayer> _awayLineup = [];

  StreamSubscription? _connSub;
  StreamSubscription? _scoreSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _finishSub;

  @override
  void initState() {
    super.initState();
    _socketService = LiveMatchSocketService(authService: AuthService());
    _initSocket();
  }

  Future<void> _initSocket() async {
    await _bootstrapData();
    await _socketService.connect();
    _socketService.joinMatch(widget.matchId);

    _connSub = _socketService.connected$.listen((ok) {
      if (!mounted) return;
      setState(() => _connected = ok);
    });

    _scoreSub = _socketService.score$.listen((data) {
      if (!mounted) return;

      final hs = data['homeScore'] ?? data['home_score'] ?? data['home'];
      final as = data['awayScore'] ?? data['away_score'] ?? data['away'];

      setState(() {
        if (hs is int) _homeScore = hs;
        if (as is int) _awayScore = as;
      });
    });

    _eventSub = _socketService.event$.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, _decorateEvent(event));
      });
    });

    _finishSub = _socketService.finished$.listen((data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partido finalizado')),
      );
      Navigator.pop(context);
    });
  }

  Future<void> _bootstrapData() async {
    try {
      final canAdd = await AuthService().isAdmin();
      final match = await _matchesService.getMatch(widget.matchId);
      final teams = await _teamsService.getBySeason(match.seasonId);
      final homeLineup =
          await _lineupsService.getLineup(widget.matchId, match.homeTeamId);
      final awayLineup =
          await _lineupsService.getLineup(widget.matchId, match.awayTeamId);
      final timeline = await _eventsService.getTimeline(widget.matchId);

      final teamMap = {for (final t in teams) t.id: t};

      if (!mounted) return;
      setState(() {
        _canAddEvents = canAdd;
        _match = match;
        _homeTeam = teamMap[match.homeTeamId];
        _awayTeam = teamMap[match.awayTeamId];
        _homeLineup = homeLineup;
        _awayLineup = awayLineup;
        _homeScore = match.homeScore;
        _awayScore = match.awayScore;
        _events
          ..clear()
          ..addAll(timeline.reversed.map(_eventToMap));
      });
    } finally {
      if (mounted) {
        setState(() => _bootstrapping = false);
      }
    }
  }

  Map<String, dynamic> _eventToMap(MatchEvent e) {
    return _decorateEvent({
      'event_type': e.eventType,
      'minute': e.minute,
      'team_id': e.teamId,
      'player_id': e.playerId,
      'player_name': e.playerName,
      'shirt_number': e.shirtNumber,
    });
  }

  Map<String, dynamic> _decorateEvent(Map<String, dynamic> raw) {
    final explicitTeamId = (raw['team_id'] ?? '').toString();
    final playerId = (raw['player_id'] ?? '').toString();
    MatchLineupPlayer? player;
    String inferredTeamId = explicitTeamId;

    if (playerId.isNotEmpty) {
      for (final p in _homeLineup) {
        if (p.playerId == playerId) {
          player = p;
          inferredTeamId = _match?.homeTeamId ?? inferredTeamId;
          break;
        }
      }

      if (player == null) {
        for (final p in _awayLineup) {
          if (p.playerId == playerId) {
            player = p;
            inferredTeamId = _match?.awayTeamId ?? inferredTeamId;
            break;
          }
        }
      }
    }

    final rawTeamName = (raw['team_name'] ?? '').toString();
    final teamName = rawTeamName.isNotEmpty
        ? rawTeamName
        : _teamNameFromId(inferredTeamId);

    return {
      ...raw,
      'team_id': inferredTeamId,
      'team_name': teamName,
      'player_name': raw['player_name'] ?? player?.playerName,
      'shirt_number': raw['shirt_number'] ?? player?.shirtNumber,
    };
  }

  String _teamNameFromId(String teamId) {
    if (teamId.isEmpty) return '';
    if (teamId == _match?.homeTeamId) {
      return _homeTeam?.name ?? '';
    }
    if (teamId == _match?.awayTeamId) {
      return _awayTeam?.name ?? '';
    }
    return '';
  }

  Future<void> _addEvent() async {
    if (_match == null) return;
    if (_homeLineup.isEmpty && _awayLineup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay alineaciones cargadas'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AddMatchEventDialog(
        matchId: widget.matchId,
        homeTeamId: _match!.homeTeamId,
        awayTeamId: _match!.awayTeamId,
        homeTeamName: _homeTeam?.name ?? 'Local',
        awayTeamName: _awayTeam?.name ?? 'Visitante',
        homeLineup: _homeLineup,
        awayLineup: _awayLineup,
      ),
    );

    if (ok == true) {
      final timeline = await _eventsService.getTimeline(widget.matchId);
      if (!mounted) return;
      setState(() {
        _events
          ..clear()
          ..addAll(timeline.reversed.map(_eventToMap));
      });
    }
  }

  @override
  void dispose() {
    _socketService.leaveMatch(widget.matchId);
    _connSub?.cancel();
    _scoreSub?.cancel();
    _eventSub?.cancel();
    _finishSub?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: 'En Vivo',
      currentIndex: 0,
      onNavTap: (_) {},
      floatingActionButton: _canAddEvents
          ? FloatingActionButton(
              onPressed: _addEvent,
              child: const Icon(Icons.add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_bootstrapping)
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: LinearProgressIndicator(),
            ),
          _buildConnectionCard(),
          const SizedBox(height: 18),
          _buildScoreboard(),
          const SizedBox(height: 18),
          _buildEventsHeader(),
          const SizedBox(height: 10),
          _buildEventsList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A2332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _connected ? Icons.wifi : Icons.wifi_off,
            color: _connected ? Colors.greenAccent : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connected ? 'Conectado en vivo' : 'Reconectando...',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: (_connected ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.15),
            ),
            child: Text(
              _connected ? 'LIVE' : 'OFF',
              style: TextStyle(
                color: _connected ? Colors.greenAccent : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Marcador',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$_homeScore  -  $_awayScore',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: _connected ? Colors.greenAccent : Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Match ID: ${widget.matchId}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsHeader() {
    return Row(
      children: [
        const Icon(Icons.bolt, color: Colors.white70),
        const SizedBox(width: 10),
        const Text(
          'Eventos en vivo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${_events.length}',
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: Text(
            'Aun no hay eventos',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children: _events.map(_buildEventTile).toList(),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e) {
    final type = (e['type'] ?? e['event_type'] ?? 'EVENT').toString();
    final minute = e['minute']?.toString();
    final playerName = (e['player_name'] ?? '').toString();
    final shirt = e['shirt_number']?.toString();
    final teamName = (e['team_name'] ?? '').toString();
    final teamNameResolved = teamName.isNotEmpty
        ? teamName
        : _teamNameFromId((e['team_id'] ?? '').toString());
    final desc = (e['description'] ?? e['detail'] ?? '').toString();

    final icon = _eventIcon(type);
    final color = _eventColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A2332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  minute == null ? type : "$type • $minute'",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                if (playerName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    shirt == null || shirt.isEmpty
                        ? playerName
                        : '$playerName (#$shirt)',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (teamNameResolved.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    teamNameResolved,
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
