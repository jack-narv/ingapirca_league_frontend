import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/referees.dart';
import '../../../models/season_category.dart';
import '../../../models/team.dart';
import '../../../models/venue.dart';
import '../../../services/referees_service.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';
import '../../../services/venues_service.dart';
import '../../../services/matches_service.dart';

class CreateMatchScreen extends StatefulWidget {
  final String seasonId;

  const CreateMatchScreen({
    super.key,
    required this.seasonId,
  });

  @override
  State<CreateMatchScreen> createState() =>
      _CreateMatchScreenState();
}

class _CreateMatchScreenState
    extends State<CreateMatchScreen> {
  final MatchesService _matchesService =
      MatchesService();
  final TeamsService _teamsService =
      TeamsService();
  final SeasonsService _seasonsService =
      SeasonsService();
  final VenuesService _venuesService =
      VenuesService();
  final RefereesService _refereesService =
      RefereesService();

  List<SeasonCategory> _categories = [];
  SeasonCategory? _selectedCategory;
  late Future<List<Team>> _teamsFuture;
  late Future<List<Venue>> _venuesFuture;
  late Future<List<Referee>> _refereesFuture;

  Team? _homeTeam;
  Team? _awayTeam;
  Venue? _venue;
  String? _selectedLeagueJournal;
  String? _selectedKnockoutJournal;
  Referee? _mainReferee;
  Referee? _assistant1Referee;
  Referee? _assistant2Referee;
  Referee? _fourthReferee;
  DateTime? _matchDate;
  final _observationsController =
      TextEditingController();

  bool _loading = false;

  final _formatter =
      DateFormat('yyyy/MM/dd HH:mm');
  static const List<String> _knockoutJournalOptions = [
    'ROUND OF 32',
    'ROUND OF 8',
    'QUARTERFINALS',
    'SEMIFINAL',
    'FINAL',
  ];

  @override
  void initState() {
    super.initState();
    _teamsFuture = Future.value([]);
    _venuesFuture =
        _venuesService.getBySeason(widget.seasonId);
    _refereesFuture =
        _loadActiveReferees();
    _loadCategories();
  }

  Future<List<Referee>> _loadActiveReferees() async {
    final all = await _refereesService.getBySeason(
      widget.seasonId,
    );
    return all.where((r) => r.isActive).toList();
  }

  Future<void> _loadCategories() async {
    final categories = await _seasonsService
        .getCategoriesBySeason(widget.seasonId);
    if (!mounted) return;

    setState(() {
      _categories = categories;
      _selectedCategory = categories.isNotEmpty
          ? categories.first
          : null;
      _teamsFuture = _teamsService.getBySeason(
        widget.seasonId,
        categoryId: _selectedCategory?.id,
      );
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      _matchDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _createMatch() async {
    final selectedJournal =
        _selectedKnockoutJournal ?? _selectedLeagueJournal;

    if (_homeTeam == null ||
        _awayTeam == null ||
        _venue == null ||
        _matchDate == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Completa todos los campos"),
        ),
      );
      return;
    }

    if (selectedJournal == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
              "Selecciona un journal de liga o de eliminacion"),
        ),
      );
      return;
    }

    if (_homeTeam!.id ==
        _awayTeam!.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
              "Local y visitante deben ser diferentes"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      if (_mainReferee == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
                "Debes seleccionar un arbitro principal (MAIN)"),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      final assignments =
          _buildRefereeAssignments();

      final matchId =
          await _matchesService.createMatch(
        seasonId: widget.seasonId,
        categoryId: _selectedCategory!.id,
        journal: selectedJournal,
        homeTeamId: _homeTeam!.id,
        awayTeamId: _awayTeam!.id,
        venueId: _venue!.id,
        matchDate: _matchDate!,
        observations:
            _observationsController.text.trim(),
      );

      if (matchId == null || matchId.isEmpty) {
        throw Exception(
          "No se pudo obtener el id del partido",
        );
      }
      if (!mounted) return;

      try {
        await _matchesService.addRefereesToMatch(
          matchId: matchId,
          assignments: assignments,
        );

        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        final message = _formatErrorMessage(e);
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              "Partido creado, pero no se pudieron asignar arbitros: $message",
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      final message = _formatErrorMessage(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Error creando partido: $message",
          ),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  List<MatchRefereeAssignmentInput>
      _buildRefereeAssignments() {
    final Map<String, String> selectedByRole = {
      "MAIN": _mainReferee?.id ?? "",
      "ASSISTANT_1":
          _assistant1Referee?.id ?? "",
      "ASSISTANT_2":
          _assistant2Referee?.id ?? "",
      "FOURTH": _fourthReferee?.id ?? "",
    };

    final selectedIds = selectedByRole.values
        .where((id) => id.isNotEmpty)
        .toList();
    final hasDuplicates = selectedIds.length !=
        selectedIds.toSet().length;

    if (hasDuplicates) {
      throw Exception(
        "Un arbitro no puede repetirse en multiples roles",
      );
    }

    return selectedByRole.entries
        .where((entry) =>
            entry.value.isNotEmpty)
        .map(
          (entry) =>
              MatchRefereeAssignmentInput(
            refereeId: entry.value,
            role: entry.key,
          ),
        )
        .toList();
  }

  List<Referee> _availableForRole(
    Referee? currentValue,
  ) {
    final selectedIds = [
      _mainReferee?.id,
      _assistant1Referee?.id,
      _assistant2Referee?.id,
      _fourthReferee?.id,
    ].whereType<String>().toSet();

    return _activeRefereesCache
        .where((referee) =>
            referee.id == currentValue?.id ||
            !selectedIds.contains(referee.id))
        .toList();
  }

  List<Referee> _activeRefereesCache = [];

  Widget _buildDropdownCard<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) getLabel,
    required void Function(T?) onChanged,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 18),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        dropdownColor:
            const Color(0xFF1E293B),
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
        items: items
            .map((item) =>
                DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    getLabel(item),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Partido",
      currentIndex: 0,
      onNavTap: (_) {},
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildDropdownCard<SeasonCategory>(
              label: "Categoria",
              value: _selectedCategory,
              items: _categories,
              getLabel: (c) => c.name,
              onChanged: (v) {
                setState(() {
                  _selectedCategory = v;
                  _homeTeam = null;
                  _awayTeam = null;
                  _selectedLeagueJournal = null;
                  _selectedKnockoutJournal = null;
                  _teamsFuture =
                      _teamsService.getBySeason(
                    widget.seasonId,
                    categoryId: v?.id,
                  );
                });
              },
            ),
            FutureBuilder<List<Team>>(
              future: _teamsFuture,
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final teams =
                    snapshot.data!;
                final leagueJournalOptions =
                    _buildLeagueJournalOptions(teams.length);

                return Column(
                  children: [
                    _buildDropdownCard<Team>(
                      label:
                          "Equipo Local",
                      value:
                          _homeTeam,
                      items: teams,
                      getLabel:
                          (t) => t.name,
                      onChanged: (v) =>
                          setState(
                        () => _homeTeam =
                            v,
                      ),
                    ),
                    _buildDropdownCard<Team>(
                      label:
                          "Equipo Visitante",
                      value:
                          _awayTeam,
                      items: teams,
                      getLabel:
                          (t) => t.name,
                      onChanged: (v) =>
                          setState(
                        () => _awayTeam =
                            v,
                      ),
                    ),
                    _buildDropdownCard<String?>(
                      label: "Jornada de Liga",
                      value: _selectedLeagueJournal,
                      items: [null, ...leagueJournalOptions],
                      getLabel: (journal) => journal == null
                          ? "Sin seleccionar"
                          : _leagueJournalDisplayLabel(journal),
                      onChanged: (value) {
                        setState(() {
                          _selectedLeagueJournal = value;
                          if (value != null) {
                            _selectedKnockoutJournal = null;
                          }
                        });
                      },
                    ),
                    _buildDropdownCard<String?>(
                      label: "Jornada de Eliminación",
                      value: _selectedKnockoutJournal,
                      items: [null, ..._knockoutJournalOptions],
                      getLabel: (journal) => journal ?? "Sin seleccionar",
                      onChanged: (value) {
                        setState(() {
                          _selectedKnockoutJournal = value;
                          if (value != null) {
                            _selectedLeagueJournal = null;
                          }
                        });
                      },
                    ),
                  ],
                );
              },
            ),

            FutureBuilder<List<Venue>>(
              future: _venuesFuture,
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final venues =
                    snapshot.data!;

                return _buildDropdownCard<Venue>(
                  label: "Estadio",
                  value: _venue,
                  items: venues,
                  getLabel:
                      (v) => v.name,
                  onChanged: (v) =>
                      setState(
                          () =>
                              _venue =
                                  v),
                );
              },
            ),
            FutureBuilder<List<Referee>>(
              future: _refereesFuture,
              builder:
                  (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(
                            bottom: 18),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(
                            bottom: 18),
                    child: Text(
                      "Error cargando arbitros: ${snapshot.error}",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  );
                }

                _activeRefereesCache =
                    snapshot.data ?? [];

                if (_activeRefereesCache
                    .isEmpty) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(
                            bottom: 18),
                    child: Text(
                      "No hay arbitros activos para esta temporada",
                      style: TextStyle(
                          color:
                              Colors.white70),
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildDropdownCard<
                        Referee?>(
                      label:
                          "Arbitro Principal (MAIN) *",
                      value: _mainReferee,
                      items: [
                        null,
                        ..._availableForRole(
                            _mainReferee),
                      ],
                      getLabel: (r) => r == null
                          ? "Sin asignar"
                          : r.fullName,
                      onChanged: (v) =>
                          setState(
                        () => _mainReferee =
                            v,
                      ),
                    ),
                    _buildDropdownCard<
                        Referee?>(
                      label:
                          "Asistente 1 (ASSISTANT_1)",
                      value:
                          _assistant1Referee,
                      items: [
                        null,
                        ..._availableForRole(
                            _assistant1Referee),
                      ],
                      getLabel: (r) => r == null
                          ? "Sin asignar"
                          : r.fullName,
                      onChanged: (v) =>
                          setState(
                        () =>
                            _assistant1Referee =
                                v,
                      ),
                    ),
                    _buildDropdownCard<
                        Referee?>(
                      label:
                          "Asistente 2 (ASSISTANT_2)",
                      value:
                          _assistant2Referee,
                      items: [
                        null,
                        ..._availableForRole(
                            _assistant2Referee),
                      ],
                      getLabel: (r) => r == null
                          ? "Sin asignar"
                          : r.fullName,
                      onChanged: (v) =>
                          setState(
                        () =>
                            _assistant2Referee =
                                v,
                      ),
                    ),
                    _buildDropdownCard<
                        Referee?>(
                      label:
                          "Cuarto Arbitro (FOURTH)",
                      value: _fourthReferee,
                      items: [
                        null,
                        ..._availableForRole(
                            _fourthReferee),
                      ],
                      getLabel: (r) => r == null
                          ? "Sin asignar"
                          : r.fullName,
                      onChanged: (v) =>
                          setState(
                        () =>
                            _fourthReferee =
                                v,
                      ),
                    ),
                  ],
                );
              },
            ),

            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.only(
                        bottom: 18),
                padding:
                    const EdgeInsets.all(
                        18),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius
                          .circular(20),
                  color: const Color(
                      0xFF1A2332),
                ),
                child: Row(
                  children: [
                    const Icon(
                        Icons
                            .calendar_month),
                    const SizedBox(
                        width: 12),
                    Text(
                      _matchDate ==
                              null
                          ? "Selecciona fecha y hora"
                          : _formatter
                              .format(
                                  _matchDate!),
                    ),
                  ],
                ),
              ),
            ),

            TextField(
              controller:
                  _observationsController,
              decoration:
                  const InputDecoration(
                labelText:
                    "Observaciones",
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 30),

            PrimaryGradientButton(
              text:
                  "Crear Partido",
              loading: _loading,
              onPressed:
                  _createMatch,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  List<String> _buildLeagueJournalOptions(int teamsCount) {
    if (teamsCount < 2) return [];
    final totalJournals = (teamsCount * 2) - 2;
    return List.generate(
      totalJournals,
      (index) => "JOURNAL ${index + 1}",
    );
  }

  String _leagueJournalDisplayLabel(String journal) {
    final normalized = journal.trim();
    final match = RegExp(
      r'^JOURNAL\s+(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match != null) {
      return 'JORNADA ${match.group(1)}';
    }
    return normalized;
  }

  String _formatErrorMessage(Object error) {
    final text = error.toString().trim();
    return text.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
}
