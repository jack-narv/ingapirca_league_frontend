import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/season_category.dart';
import '../../../models/team.dart';
import '../../../models/venue.dart';
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

  List<SeasonCategory> _categories = [];
  SeasonCategory? _selectedCategory;
  late Future<List<Team>> _teamsFuture;
  late Future<List<Venue>> _venuesFuture;

  Team? _homeTeam;
  Team? _awayTeam;
  Venue? _venue;
  DateTime? _matchDate;
  final _observationsController =
      TextEditingController();

  bool _loading = false;

  final _formatter =
      DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    _teamsFuture = Future.value([]);
    _venuesFuture =
        _venuesService.getAll();
    _loadCategories();
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
      await _matchesService.createMatch(
        seasonId: widget.seasonId,
        categoryId: _selectedCategory!.id,
        homeTeamId: _homeTeam!.id,
        awayTeamId: _awayTeam!.id,
        venueId: _venue!.id,
        matchDate: _matchDate!,
        observations:
            _observationsController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Error creando partido"),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

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
        value: value,
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
}
