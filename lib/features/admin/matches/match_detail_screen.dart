import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/match_event.dart';
import '../../../models/match_lineup.dart';
import '../../../models/match_observations.dart';
import '../../../models/match_referee_observation.dart';
import '../../../models/referee_ratings.dart';
import '../../../models/referees.dart';
import '../../../models/team.dart';
import '../../../models/venue.dart';
import '../../../services/auth_service.dart';
import '../../../services/live_match_service.dart';
import '../../../services/match_events_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/match_referee_observations_service.dart';
import '../../../services/matches_service.dart';
import '../../../services/referee_ratings_service.dart';
import '../../../services/referees_service.dart';
import '../../../services/teams_service.dart';
import '../../../services/venues_service.dart';
import 'finalize_match_screen.dart';
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
  final VenuesService _venuesService = VenuesService();
  final MatchEventsService _eventsService = MatchEventsService();
  final MatchLineupsService _lineupsService = MatchLineupsService();
  final RefereesService _refereesService = RefereesService();
  final RefereeRatingsService _refereeRatingsService =
      RefereeRatingsService();
  final MatchRefereeObservationsService
      _matchRefereeObservationsService =
      MatchRefereeObservationsService();
  final LiveMatchSocketService _socketService =
      LiveMatchSocketService(authService: AuthService());

  late Match _match;
  Map<String, Team> _teamsById = {};
  Map<String, Venue> _venuesById = {};

  late Future<bool> _isAdminFuture;
  late Future<List<MatchLineupPlayer>> _homeLineupFuture;
  late Future<List<MatchLineupPlayer>> _awayLineupFuture;

  final List<Map<String, dynamic>> _events = [];
  final Map<String, String> _playerNamesById = {};
  final Map<String, int> _shirtByPlayerId = {};
  final Map<String, String> _teamIdByPlayerId = {};
  final List<MatchObservation> _teamObservations = [];
  final List<MatchRefereeAssignment> _matchReferees = [];
  final List<RefereeRating> _refereeRatings = [];
  final List<MatchRefereeObservation> _refereeObservations = [];

  StreamSubscription? _scoreSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _startSub;
  StreamSubscription? _finishSub;

  bool _loading = false;
  bool _eventsLoading = true;
  bool _observationsLoading = true;
  bool _refereesLoading = true;
  bool _refereeRatingsLoading = true;
  bool _refereeObservationsLoading = true;

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
    await _loadVenues();
    await _loadLineupCaches();
    await _loadEvents();
    await _loadMatchReferees();
    await _loadRefereeRatings();
    await _loadRefereeObservations();
    await _loadTeamObservations();
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
          journal: _match.journal,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: 'PLAYING',
          homeScore: _match.homeScore,
          awayScore: _match.awayScore,
          observations: _match.observations,
          bestPlayerId: _match.bestPlayerId,
          bestGoalkeeperId: _match.bestGoalkeeperId,
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
          journal: _match.journal,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: _match.status,
          homeScore: hs is int ? hs : _match.homeScore,
          awayScore:
              awayValue is int ? awayValue : _match.awayScore,
          observations: _match.observations,
          bestPlayerId: _match.bestPlayerId,
          bestGoalkeeperId: _match.bestGoalkeeperId,
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
          journal: _match.journal,
          homeTeamId: _match.homeTeamId,
          awayTeamId: _match.awayTeamId,
          venueId: _match.venueId,
          matchDate: _match.matchDate,
          status: 'PLAYED',
          homeScore: hs is int ? hs : _match.homeScore,
          awayScore:
              awayValue is int ? awayValue : _match.awayScore,
          observations: _match.observations,
          bestPlayerId: _match.bestPlayerId,
          bestGoalkeeperId: _match.bestGoalkeeperId,
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

  Future<void> _loadVenues() async {
    final venues = await _venuesService.getBySeason(_match.seasonId);
    if (!mounted) return;
    setState(() {
      _venuesById = {
        for (final venue in venues) venue.id: venue,
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

      if (!mounted || _events.isEmpty) return;
      setState(() {
        for (var i = 0; i < _events.length; i++) {
          _events[i] = _normalizeEvent(_events[i]);
        }
      });
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

  Future<void> _loadTeamObservations() async {
    setState(() => _observationsLoading = true);
    try {
      final observations =
          await _service.getTeamObservationsByMatch(_match.id);
      if (!mounted) return;
      setState(() {
        _teamObservations
          ..clear()
          ..addAll(observations);
      });
    } finally {
      if (mounted) {
        setState(() => _observationsLoading = false);
      }
    }
  }

  Future<void> _loadMatchReferees() async {
    setState(() => _refereesLoading = true);
    try {
      final assignments =
          await _refereesService.getByMatch(_match.id);
      if (!mounted) return;
      setState(() {
        _matchReferees
          ..clear()
          ..addAll(assignments);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matchReferees.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _refereesLoading = false);
      }
    }
  }

  Future<void> _loadRefereeRatings() async {
    setState(() => _refereeRatingsLoading = true);
    try {
      final ratings =
          await _refereeRatingsService.getByMatch(_match.id);
      if (!mounted) return;
      setState(() {
        _refereeRatings
          ..clear()
          ..addAll(ratings);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refereeRatings.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _refereeRatingsLoading = false);
      }
    }
  }

  Future<void> _loadRefereeObservations() async {
    setState(() => _refereeObservationsLoading = true);
    try {
      final observations =
          await _matchRefereeObservationsService.getByMatch(_match.id);
      if (!mounted) return;
      setState(() {
        _refereeObservations
          ..clear()
          ..addAll(observations);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refereeObservations.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _refereeObservationsLoading = false);
      }
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
    final finalized = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FinalizeMatchScreen(
          match: _match,
          homeTeamName: _teamName(_match.homeTeamId),
          awayTeamName: _teamName(_match.awayTeamId),
        ),
      ),
    );

    if (finalized == true) {
      await _refresh();
    }
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
              if (_showAwardsSummary()) ...[
                const SizedBox(height: 8),
                _buildAwardsSummary(),
              ],
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _statusLabelEs(_match.status),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              if ((_match.journal ?? '').trim().isNotEmpty)
                _journalBadge(_match.journal!),
            ],
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
          const SizedBox(height: 12),
          Text(
            "${_weekdayEs(_match.matchDate)} ${_formatDateTime(_match.matchDate)} • ${_venueName(_match.venueId)}",
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _journalBadge(String journal) {
    final label = _journalLabelEs(journal);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2D55).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF2D55).withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFF7A92),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _journalLabelEs(String journal) {
    final normalized = journal.trim();
    final match = RegExp(r'^JOURNAL\s+(\d+)$', caseSensitive: false)
        .firstMatch(normalized);
    if (match != null) {
      return 'Jornada ${match.group(1)}';
    }

    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return 'Jornada $normalized';
    }

    return normalized.replaceAll('_', ' ').toUpperCase();
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

  bool _showAwardsSummary() {
    final hasBestPlayer =
        (_match.bestPlayerId ?? '').trim().isNotEmpty;
    final hasBestGoalkeeper =
        (_match.bestGoalkeeperId ?? '').trim().isNotEmpty;
    return _match.status == 'PLAYED' &&
        (hasBestPlayer || hasBestGoalkeeper);
  }

  Widget _buildAwardsSummary() {
    final bestPlayerId = (_match.bestPlayerId ?? '').trim();
    final bestGoalkeeperId =
        (_match.bestGoalkeeperId ?? '').trim();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (bestPlayerId.isNotEmpty)
            _awardChip(
              icon: Icons.star_rounded,
              label: 'MVP',
              playerId: bestPlayerId,
            ),
          if (bestGoalkeeperId.isNotEmpty)
            _awardChip(
              icon: Icons.shield_outlined,
              label: 'Arquero',
              playerId: bestGoalkeeperId,
            ),
        ],
      ),
    );
  }

  Widget _awardChip({
    required IconData icon,
    required String label,
    required String playerId,
  }) {
    final playerName = _playerNameOrId(playerId);
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white12,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.amberAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $playerName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _playerNameOrId(String playerId) {
    final fromCache = _playerNamesById[playerId];
    if (fromCache != null && fromCache.trim().isNotEmpty) {
      return fromCache;
    }
    return playerId;
  }

  Widget _buildRefereesSummary() {
    if (_refereesLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Cargando arbitros...',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    if (_matchReferees.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Arbitros: sin asignacion',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    final assignments = [..._matchReferees]
      ..sort((a, b) => a.role.compareTo(b.role));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: assignments.map((a) {
          final refereeName =
              a.referee?.fullName.trim().isNotEmpty == true
                  ? a.referee!.fullName
                  : a.refereeId;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_roleLabel(a.role)}: $refereeName',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'MAIN':
        return 'Principal';
      case 'ASSISTANT_1':
        return 'Asistente 1';
      case 'ASSISTANT_2':
        return 'Asistente 2';
      case 'FOURTH':
        return 'Cuarto';
      default:
        return role;
    }
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
          final typeLabel = _eventLabelEs(type);
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
                _buildEventMarker(type, icon, color),
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
                        typeLabel,
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
          _buildRefereesSummary(),
          const SizedBox(height: 14),
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

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  'Observación del vocal',
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
          const SizedBox(height: 12),
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
                  'Observaciones de equipos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (_observationsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_teamObservations.isEmpty)
                  const Text(
                    'Sin observaciones de equipos registradas.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Column(
                    children: _teamObservations.map((o) {
                      final submittedAt = o.submittedAt;
                      final dateText =
                          '${submittedAt.day.toString().padLeft(2, '0')}/'
                          '${submittedAt.month.toString().padLeft(2, '0')}/'
                          '${submittedAt.year} '
                          '${submittedAt.hour.toString().padLeft(2, '0')}:'
                          '${submittedAt.minute.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.teamName ?? _teamName(o.teamId),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              o.observation,
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reporta: ${o.submittedByName ?? o.submittedBy}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Estado: ${o.status} • $dateText',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  'Calificaciones a arbitros',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (_refereeRatingsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_refereeRatings.isEmpty)
                  const Text(
                    'Sin calificaciones de arbitros registradas.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Column(
                    children: _refereeRatings.map((r) {
                      final role = _matchReferees
                          .where((a) => a.refereeId == r.refereeId)
                          .map((a) => _roleLabel(a.role))
                          .cast<String?>()
                          .firstWhere(
                            (value) => value != null,
                            orElse: () => null,
                          );

                      final submittedAt = r.submittedAt;
                      final dateText = submittedAt == null
                          ? ''
                          : '${submittedAt.day.toString().padLeft(2, '0')}/'
                              '${submittedAt.month.toString().padLeft(2, '0')}/'
                              '${submittedAt.year} '
                              '${submittedAt.hour.toString().padLeft(2, '0')}:'
                              '${submittedAt.minute.toString().padLeft(2, '0')}';

                      final refereeLabel =
                          r.refereeName?.trim().isNotEmpty == true
                              ? r.refereeName!
                              : r.refereeId;

                      final teamLabel = r.teamName?.trim().isNotEmpty == true
                          ? r.teamName!
                          : _teamName(r.teamId);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role == null
                                  ? refereeLabel
                                  : '$refereeLabel ($role)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Equipo: $teamLabel',
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildTenStarRating(r.rating),
                            const SizedBox(height: 4),
                            Text(
                              r.comment?.trim().isNotEmpty == true
                                  ? r.comment!
                                  : 'Sin comentario',
                              style: const TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                            if (dateText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                dateText,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  'Observaciones de arbitros',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (_refereeObservationsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_refereeObservations.isEmpty)
                  const Text(
                    'Sin observaciones de arbitros registradas.',
                    style: TextStyle(color: Colors.white70),
                  )
                else
                  Column(
                    children: _refereeObservations.map((o) {
                      final submittedAt = o.submittedAt;
                      final dateText = submittedAt == null
                          ? ''
                          : '${submittedAt.day.toString().padLeft(2, '0')}/'
                              '${submittedAt.month.toString().padLeft(2, '0')}/'
                              '${submittedAt.year} '
                              '${submittedAt.hour.toString().padLeft(2, '0')}:'
                              '${submittedAt.minute.toString().padLeft(2, '0')}';

                      final role = _matchReferees
                          .where((a) => a.refereeId == o.refereeId)
                          .map((a) => _roleLabel(a.role))
                          .cast<String?>()
                          .firstWhere(
                            (value) => value != null,
                            orElse: () => null,
                          );

                      final refereeLabel =
                          o.refereeName?.trim().isNotEmpty == true
                              ? o.refereeName!
                              : o.refereeId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role == null
                                  ? refereeLabel
                                  : '$refereeLabel ($role)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              o.observation,
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Estado: ${o.status}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (dateText.isNotEmpty)
                              Text(
                                dateText,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildTenStarRating(int rating) {
    final safeRating = rating.clamp(0, 10);

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: List.generate(10, (index) {
        final filled = index < safeRating;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: 16,
          color: filled ? Colors.amber : Colors.white24,
        );
      }),
    );
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "${date.day}/${date.month}/${date.year} $hour:$minute";
  }

  String _weekdayEs(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return '';
    }
  }

  String _venueName(String venueId) {
    final name = _venuesById[venueId]?.name ?? '';
    if (name.trim().isEmpty) {
      return 'Escenario no definido';
    }
    return name;
  }

  String _statusLabelEs(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return 'POR JUGAR';
      case 'PLAYING':
        return 'JUGANDO';
      case 'PLAYED':
        return 'TERMINADO';
      case 'CANCELED':
        return 'CANCELADO';
      default:
        return status;
    }
  }
}
