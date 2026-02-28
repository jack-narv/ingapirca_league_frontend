import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/team.dart';
import '../../../models/venue.dart';
import '../../../services/matches_service.dart';
import '../../../services/teams_service.dart';
import '../../../services/venues_service.dart';
import '../matches/match_detail_screen.dart';

class TeamMatchesScreen extends StatefulWidget {
  final Team team;
  final String seasonId;
  final String seasonName;

  const TeamMatchesScreen({
    super.key,
    required this.team,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<TeamMatchesScreen> createState() =>
      _TeamMatchesScreenState();
}

class _TeamMatchesScreenState
    extends State<TeamMatchesScreen> {
  final MatchesService _matchesService = MatchesService();
  final TeamsService _teamsService = TeamsService();
  final VenuesService _venuesService = VenuesService();
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );

  late Future<List<Match>> _future;
  late Future<List<Team>> _teamsFuture;
  late Future<List<Venue>> _venuesFuture;
  Map<String, Team> _teamsById = {};
  Map<String, Venue> _venuesById = {};
  String? _selectedJournal;
  bool _didAutoSelectJournal = false;

  @override
  void initState() {
    super.initState();
    _future = _loadTeamMatches();
    _teamsFuture = _teamsService.getBySeason(
      widget.seasonId,
      categoryId: widget.team.categoryId,
    );
    _venuesFuture = _venuesService.getBySeason(
      widget.seasonId,
    );
    _loadTeams();
    _loadVenues();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Match>> _loadTeamMatches() async {
    final matches = await _matchesService.getBySeason(
      widget.seasonId,
      categoryId: widget.team.categoryId,
    );

    final teamMatches = matches.where((match) {
      return match.homeTeamId == widget.team.id ||
          match.awayTeamId == widget.team.id;
    }).toList();

    teamMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
    return teamMatches;
  }

  Future<void> _loadTeams() async {
    final teams = await _teamsFuture;
    if (!mounted) return;
    setState(() {
      _teamsById = {for (final team in teams) team.id: team};
    });
  }

  Future<void> _loadVenues() async {
    final venues = await _venuesFuture;
    if (!mounted) return;
    setState(() {
      _venuesById = {for (final venue in venues) venue.id: venue};
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
  }

  void _refresh() {
    setState(() {
      _future = _loadTeamMatches();
      _teamsFuture = _teamsService.getBySeason(
        widget.seasonId,
        categoryId: widget.team.categoryId,
      );
      _venuesFuture = _venuesService.getBySeason(
        widget.seasonId,
      );
    });
    _scrollToTop();
    _loadTeams();
    _loadVenues();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Partidos - ${widget.team.name}",
      currentIndex: 2,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 2,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
      body: FutureBuilder<List<Match>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final matches = snapshot.data!;
          final journals = _extractJournals(matches);
          _tryAutoSelectJournal(matches, journals);
          final filteredMatches = _selectedJournal == null
              ? matches
              : matches
                  .where((m) => m.journal == _selectedJournal)
                  .toList();

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              if (journals.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text("Todas"),
                          selected: _selectedJournal == null,
                          onSelected: (_) {
                            setState(() => _selectedJournal = null);
                            _scrollToTop();
                          },
                        ),
                      ),
                      ...journals.map((journal) {
                        final selected = _selectedJournal == journal;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_journalLabelEs(journal)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() {
                                _selectedJournal =
                                    selected ? null : journal;
                              });
                              _scrollToTop();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (filteredMatches.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: Text(
                      "No hay partidos de este equipo",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ...filteredMatches.map(_buildMatchCard),
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
            builder: (_) => MatchDetailScreen(
              match: match,
              seasonName: widget.seasonName,
            ),
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
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusBadge(match.status),
                if ((match.journal ?? '').trim().isNotEmpty)
                  _journalBadge(match.journal!),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                const Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${_weekdayEs(match.matchDate)} ${_formatDateTime(match.matchDate)} • ${_venueName(match.venueId)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabelEs(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

  Widget _journalBadge(String journal) {
    final label = _journalLabelEs(journal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    final match = RegExp(
      r'^JOURNAL\s+(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match != null) {
      return 'Jornada ${match.group(1)}';
    }

    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return 'Jornada $normalized';
    }

    return normalized.replaceAll('_', ' ').toUpperCase();
  }

  List<String> _extractJournals(List<Match> matches) {
    final journals = matches
        .map((m) => (m.journal ?? '').trim())
        .where((j) => j.isNotEmpty)
        .toSet()
        .toList();

    journals.sort((a, b) {
      final aNum = RegExp(
        r'^JOURNAL\s+(\d+)$',
        caseSensitive: false,
      ).firstMatch(a);
      final bNum = RegExp(
        r'^JOURNAL\s+(\d+)$',
        caseSensitive: false,
      ).firstMatch(b);

      if (aNum != null && bNum != null) {
        final aValue = int.parse(aNum.group(1)!);
        final bValue = int.parse(bNum.group(1)!);
        return aValue.compareTo(bValue);
      }

      if (aNum != null) return -1;
      if (bNum != null) return 1;
      return a.compareTo(b);
    });

    return journals;
  }

  void _tryAutoSelectJournal(
    List<Match> matches,
    List<String> journals,
  ) {
    if (_didAutoSelectJournal || _selectedJournal != null) {
      return;
    }
    if (matches.isEmpty || journals.isEmpty) {
      _didAutoSelectJournal = true;
      return;
    }

    final suggested = _suggestJournalForCurrentWeek(matches, journals);
    _didAutoSelectJournal = true;

    if (suggested == null || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedJournal = suggested;
      });
    });
  }

  String? _suggestJournalForCurrentWeek(
    List<Match> matches,
    List<String> journals,
  ) {
    final now = _ecuadorNow();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final endOfWeekExclusive = startOfWeek.add(const Duration(days: 7));

    final weekMatches = matches.where((match) {
      final journal = (match.journal ?? '').trim();
      if (journal.isEmpty || !journals.contains(journal)) {
        return false;
      }
      final date = match.matchDate;
      return !date.isBefore(startOfWeek) && date.isBefore(endOfWeekExclusive);
    }).toList();

    if (weekMatches.isNotEmpty) {
      weekMatches.sort(
        (a, b) => a.matchDate
            .difference(now)
            .abs()
            .compareTo(b.matchDate.difference(now).abs()),
      );
      return (weekMatches.first.journal ?? '').trim();
    }

    final upcoming = matches.where((match) {
      final journal = (match.journal ?? '').trim();
      return journal.isNotEmpty &&
          journals.contains(journal) &&
          !match.matchDate.isBefore(now);
    }).toList()
      ..sort((a, b) => a.matchDate.compareTo(b.matchDate));

    if (upcoming.isNotEmpty) {
      return (upcoming.first.journal ?? '').trim();
    }

    final latestPast = matches.where((match) {
      final journal = (match.journal ?? '').trim();
      return journal.isNotEmpty && journals.contains(journal);
    }).toList()
      ..sort((a, b) => b.matchDate.compareTo(a.matchDate));

    if (latestPast.isNotEmpty) {
      return (latestPast.first.journal ?? '').trim();
    }

    return null;
  }

  DateTime _ecuadorNow() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 5));
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
