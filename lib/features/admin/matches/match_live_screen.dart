import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
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
  final String seasonId;
  final String seasonName;

  const LiveMatchScreen({
    super.key,
    required this.matchId,
    required this.seasonId,
    required this.seasonName,
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
  String? _deletingEventId;

  int _homeScore = 0;
  int _awayScore = 0;

  final List<Map<String, dynamic>> _events = [];
  Match? _match;
  Team? _homeTeam;
  Team? _awayTeam;
  List<MatchLineupPlayer> _homeLineup = [];
  List<MatchLineupPlayer> _awayLineup = [];

  StreamSubscription? _connSub;
  StreamSubscription? _startSub;
  StreamSubscription? _halfTimeSub;
  StreamSubscription? _secondHalfSub;
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

    _startSub = _socketService.matchStarted$.listen((_) {
      _setMatchStatus('PLAYING_FIRST_HALF');
    });

    _halfTimeSub = _socketService.halfTime$.listen((_) {
      _setMatchStatus('HALF_TIME');
    });

    _secondHalfSub = _socketService.secondHalfStarted$.listen((_) {
      _setMatchStatus('PLAYING_SECOND_HALF');
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
      _setMatchStatus('PLAYED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partido finalizado')),
      );
      Navigator.pop(context);
    });
  }

  void _setMatchStatus(String status) {
    if (!mounted || _match == null) return;
    setState(() {
      _match = Match(
        id: _match!.id,
        seasonId: _match!.seasonId,
        categoryId: _match!.categoryId,
        journal: _match!.journal,
        homeTeamId: _match!.homeTeamId,
        awayTeamId: _match!.awayTeamId,
        venueId: _match!.venueId,
        matchDate: _match!.matchDate,
        status: status,
        homeScore: _homeScore,
        awayScore: _awayScore,
        observations: _match!.observations,
        bestPlayerId: _match!.bestPlayerId,
        bestGoalkeeperId: _match!.bestGoalkeeperId,
      );
    });
  }

  Future<void> _bootstrapData() async {
    try {
      final canAdd = await AuthService().canManageMatchFlow();
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
      'id': e.id,
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
        matchStatus: _match!.status,
        homeLineup: _homeLineup,
        awayLineup: _awayLineup,
      ),
    );

    if (ok == true) {
      await _refreshTimelineAndScore();
    }
  }

  Future<void> _refreshTimelineAndScore() async {
    final timeline = await _eventsService.getTimeline(widget.matchId);
    final updatedMatch = await _matchesService.getMatch(widget.matchId);
    if (!mounted) return;
    setState(() {
      _match = updatedMatch;
      _homeScore = updatedMatch.homeScore;
      _awayScore = updatedMatch.awayScore;
      _events
        ..clear()
        ..addAll(timeline.reversed.map(_eventToMap));
    });
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    if (_deletingEventId != null) return;

    final eventId = (event['id'] ?? '').toString();
    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este evento no se puede eliminar'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text(
          'Se eliminara el evento y se revertira marcador/estadisticas. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deletingEventId = eventId);
    try {
      await _eventsService.deleteEvent(
        eventId,
        seasonId: widget.seasonId,
      );
      await _refreshTimelineAndScore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evento eliminado'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final message = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingEventId = null);
      }
    }
  }

  @override
  void dispose() {
    _socketService.leaveMatch(widget.matchId);
    _connSub?.cancel();
    _startSub?.cancel();
    _halfTimeSub?.cancel();
    _secondHalfSub?.cancel();
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
      currentIndex: 1,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 1,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      floatingActionButton: _canAddEvents && _isPlayingHalf(_match?.status)
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
    final homeName = _homeTeam?.name ?? 'Local';
    final awayName = _awayTeam?.name ?? 'Visitante';

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
          const SizedBox(height: 6),
          Text(
            _statusLabelEs(_match?.status ?? ''),
            style: TextStyle(
              color: _statusTextColor(_match?.status ?? ''),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScoreTeamInfo(
                  name: homeName,
                  logoUrl: _homeTeam?.logoUrl,
                  alignEnd: false,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_homeScore  -  $_awayScore',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: _connected ? Colors.greenAccent : Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildScoreTeamInfo(
                  name: awayName,
                  logoUrl: _awayTeam?.logoUrl,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$homeName vs $awayName',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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

  Widget _buildScoreTeamInfo({
    required String name,
    required String? logoUrl,
    required bool alignEnd,
  }) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignEnd) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1A2332),
            backgroundImage:
                (logoUrl != null && logoUrl.isNotEmpty) ? NetworkImage(logoUrl) : null,
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
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        if (alignEnd) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF1A2332),
            backgroundImage:
                (logoUrl != null && logoUrl.isNotEmpty) ? NetworkImage(logoUrl) : null,
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
      ],
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
    final eventId = (e['id'] ?? '').toString();
    final type = (e['type'] ?? e['event_type'] ?? 'EVENT').toString();
    final typeLabel = _eventLabelEs(type);
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
    final minuteLabel = _formatMinuteLabel(minute);

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
          _buildEventMarker(type, icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  minuteLabel.isEmpty ? typeLabel : "$typeLabel • $minuteLabel",
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
          if (_canAddEvents)
            IconButton(
              tooltip: 'Eliminar evento',
              onPressed: (eventId.isEmpty || _deletingEventId != null)
                  ? null
                  : () => _deleteEvent(e),
              icon: _deletingEventId == eventId
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
            ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (_normalizeEventType(type)) {
      case 'GOAL':
        return Icons.sports_soccer;
      case 'YELLOW_CARD':
      case 'YELLOW':
        return Icons.square;
      case 'RED_CARD':
      case 'RED_DIRECT':
      case 'DOUBLE_YELLOW_RED':
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
    switch (_normalizeEventType(type)) {
      case 'GOAL':
        return Colors.greenAccent;
      case 'YELLOW_CARD':
      case 'YELLOW':
        return Colors.amber;
      case 'RED_CARD':
      case 'RED_DIRECT':
      case 'DOUBLE_YELLOW_RED':
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

  String _eventLabelEs(String type) {
    switch (_normalizeEventType(type)) {
      case 'GOAL':
        return 'GOL';
      case 'YELLOW':
      case 'YELLOW_CARD':
        return 'AMARILLA';
      case 'RED':
      case 'RED_CARD':
        return 'ROJA';
      case 'RED_DIRECT':
        return 'ROJA DIRECTA';
      case 'DOUBLE_YELLOW_RED':
        return 'ROJA POR DOS AMARILLAS';
      case 'SUB_IN':
        return 'ENTRA';
      case 'SUB_OUT':
        return 'SALE';
      case 'OWN_GOAL':
        return 'AUTOGOL';
      default:
        return type;
    }
  }

  String _normalizeEventType(String type) {
    final normalized = type
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');

    if (normalized == 'DOBLE_YELLOW_RED') {
      return 'DOUBLE_YELLOW_RED';
    }

    if ((normalized.contains('DOUBLE') || normalized.contains('DOBLE')) &&
        normalized.contains('YELLOW') &&
        normalized.contains('RED')) {
      return 'DOUBLE_YELLOW_RED';
    }

    return normalized;
  }

  Widget _buildEventMarker(String type, IconData icon, Color color) {
    final normalizedType = _normalizeEventType(type);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: normalizedType == 'DOUBLE_YELLOW_RED'
          ? SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 3,
                    child: _buildCardIcon(Colors.amber),
                  ),
                  Positioned(
                    left: 6,
                    top: 5,
                    child: _buildCardIcon(Colors.amber),
                  ),
                  Positioned(
                    left: 12,
                    top: 7,
                    child: _buildCardIcon(Colors.redAccent),
                  ),
                ],
              ),
            )
          : Icon(icon, color: color),
    );
  }

  Widget _buildCardIcon(Color color) {
    return Container(
      width: 8,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  bool _isPlayingHalf(String? status) {
    final normalized = (status ?? '').toUpperCase();
    return normalized == 'PLAYING_FIRST_HALF' ||
        normalized == 'PLAYING_SECOND_HALF';
  }

  String _statusLabelEs(String status) {
    switch (status.toUpperCase()) {
      case 'PLAYING_FIRST_HALF':
        return 'JUGANDO PRIMER TIEMPO';
      case 'PLAYING_SECOND_HALF':
        return 'JUGANDO SEGUNDO TIEMPO';
      case 'HALF_TIME':
        return 'DESCANSO';
      case 'PLAYED':
        return 'TERMINADO';
      case 'SCHEDULED':
        return 'POR JUGAR';
      case 'CANCELED':
        return 'CANCELADO';
      default:
        return status;
    }
  }

  Color _statusTextColor(String status) {
    final normalized = status.toUpperCase();
    if (normalized == 'PLAYING_FIRST_HALF' ||
        normalized == 'PLAYING_SECOND_HALF') {
      return Colors.greenAccent;
    }
    if (normalized == 'HALF_TIME') return Colors.amber;
    if (normalized == 'PLAYED') return Colors.blueAccent;
    if (normalized == 'CANCELED') return Colors.redAccent;
    return Colors.white70;
  }

  String _formatMinuteLabel(String? minute) {
    final value = (minute ?? '').trim();
    if (value.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(value)) return "$value'";
    return value;
  }
}
