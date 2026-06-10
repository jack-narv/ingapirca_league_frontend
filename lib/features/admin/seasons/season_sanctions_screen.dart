import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/cards_summary.dart';
import '../../../models/season.dart';
import '../../../models/season_category.dart';
import '../../../models/suspension_summary.dart';
import '../../../models/team.dart';
import '../../../services/sanctions_service.dart';

class SeasonSanctionsScreen extends StatefulWidget {
  final Season season;

  const SeasonSanctionsScreen({
    super.key,
    required this.season,
  });

  @override
  State<SeasonSanctionsScreen> createState() => _SeasonSanctionsScreenState();
}

class _SeasonSanctionsScreenState extends State<SeasonSanctionsScreen> {
  final SanctionsService _sanctionsService = SanctionsService();

  late Future<void> _initialLoadFuture;
  List<SeasonCategory> _categories = <SeasonCategory>[];
  List<Team> _teams = <Team>[];
  List<CardsSummary> _cardsSummary = <CardsSummary>[];
  List<SuspensionSummary> _suspensionsSummary = <SuspensionSummary>[];
  bool _cardsLoading = false;
  bool _suspensionsLoading = false;

  String? _cardsCategoryId;
  String? _cardsTeamId;

  String? _suspensionsCategoryId;
  String? _suspensionsTeamId;

  @override
  void initState() {
    super.initState();
    _initialLoadFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final overview = await _sanctionsService.getSeasonOverview(
      seasonId: widget.season.id,
    );

    _categories = overview.categories;
    _teams = overview.teams;
    _cardsSummary = overview.cardsSummary;
    _suspensionsSummary = overview.suspensionsSummary;
  }

  Future<List<SuspensionSummary>> _loadSuspensionsSummary() {
    return _sanctionsService.getSuspensionsSummaryBySeason(
      seasonId: widget.season.id,
      categoryId: _suspensionsCategoryId,
      teamId: _suspensionsTeamId,
    );
  }

  Future<List<CardsSummary>> _loadCardsSummary() {
    return _sanctionsService.getCardsSummaryBySeason(
      seasonId: widget.season.id,
      categoryId: _cardsCategoryId,
      teamId: _cardsTeamId,
    );
  }

  Future<void> _refreshCardsSummary() async {
    setState(() {
      _cardsLoading = true;
    });

    try {
      final summary = await _loadCardsSummary();
      if (!mounted) return;
      setState(() {
        _cardsSummary = summary;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _cardsLoading = false;
      });
    }
  }

  Future<void> _refreshSuspensionsSummary() async {
    setState(() {
      _suspensionsLoading = true;
    });

    try {
      final summary = await _loadSuspensionsSummary();
      if (!mounted) return;
      setState(() {
        _suspensionsSummary = summary;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _suspensionsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Sanciones - ${widget.season.name}",
      currentIndex: 0,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 0,
        seasonId: widget.season.id,
        seasonName: widget.season.name,
      ),
      body: FutureBuilder<void>(
        future: _initialLoadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No se pudieron cargar las sanciones",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initialLoadFuture = _loadInitialData();
                        });
                      },
                      child: const Text("Reintentar"),
                    ),
                  ],
                ),
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2332),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(text: "SUSPENSIONES"),
                      Tab(text: "TARJETAS"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSuspensionsTab(),
                      _buildCardsTab(),
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

  Widget _buildCardsTab() {
    final availableTeams = _availableTeams(
      _teams,
      selectedCategoryId: _cardsCategoryId,
    );
    final safeTeamId =
        availableTeams.any((t) => t.id == _cardsTeamId) ? _cardsTeamId : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de tarjetas",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _cardsCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ..._categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  final stillValid = _availableTeams(
                    _teams,
                    selectedCategoryId: value,
                  ).any((t) => t.id == _cardsTeamId);
                  setState(() {
                    _cardsCategoryId = value;
                    if (!stillValid) {
                      _cardsTeamId = null;
                    }
                  });
                  _refreshCardsSummary();
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("cards-team-${_cardsCategoryId ?? 'all'}"),
                initialValue: safeTeamId,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _cardsTeamId = value;
                  });
                  _refreshCardsSummary();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_cardsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildCardsContent(_cardsSummary),
      ],
    );
  }

  Widget _buildCardsContent(List<CardsSummary> rows) {
    final tableRows = rows
        .map(
          (item) => _CardsSummaryRow(
            playerId: item.playerId,
            playerName: item.fullName.isEmpty ? item.playerId : item.fullName,
            teamName: (item.teamName ?? '').trim().isNotEmpty
                ? (item.teamName ?? '').trim()
                : 'Sin equipo',
            shirtNumber: item.shirtNumber,
            yellowCards: item.yellowCards,
            redDirectCards: item.redDirectCards,
          ),
        )
        .toList();
    final yellowCount =
        rows.fold<int>(0, (acc, item) => acc + item.yellowCards);
    final redDirectCount = rows.fold<int>(
      0,
      (acc, item) => acc + item.redDirectCards,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              label: "Jugadores con tarjetas",
              value: "${rows.length}",
              icon: Icons.style,
            ),
            _MetricCard(
              label: "Amarillas",
              value: "$yellowCount",
              icon: Icons.square_rounded,
            ),
            _MetricCard(
              label: "Rojas directas",
              value: "$redDirectCount",
              icon: Icons.stop_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle(title: "Registro de tarjetas"),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _ChartCard(
            child: Text(
              "No hay tarjetas para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          _ModernTableCard(
            title: "Resumen de tarjetas",
            subtitle: "Suma de amarilla y roja directa por jugador",
            child: _CardsSummaryTable(entries: tableRows),
          ),
      ],
    );
  }

  Widget _buildSuspensionsTab() {
    final availableTeams = _availableTeams(
      _teams,
      selectedCategoryId: _suspensionsCategoryId,
    );
    final safeTeamId = availableTeams.any((t) => t.id == _suspensionsTeamId)
        ? _suspensionsTeamId
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FilterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filtros de suspensiones",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: _suspensionsCategoryId,
                decoration: const InputDecoration(labelText: "Categoria"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todas las categorias"),
                  ),
                  ..._categories.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  final stillValid = _availableTeams(
                    _teams,
                    selectedCategoryId: value,
                  ).any((t) => t.id == _suspensionsTeamId);
                  setState(() {
                    _suspensionsCategoryId = value;
                    if (!stillValid) {
                      _suspensionsTeamId = null;
                    }
                  });
                  _refreshSuspensionsSummary();
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey("susp-team-${_suspensionsCategoryId ?? 'all'}"),
                initialValue: safeTeamId,
                decoration: const InputDecoration(labelText: "Equipo"),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Todos los equipos"),
                  ),
                  ...availableTeams.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _suspensionsTeamId = value;
                  });
                  _refreshSuspensionsSummary();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_suspensionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _buildSuspensionsContent(_suspensionsSummary),
      ],
    );
  }

  Widget _buildSuspensionsContent(List<SuspensionSummary> summary) {
    final rows = summary
        .map(
          (s) => _SuspensionSummaryRow(
            playerId: s.playerId,
            playerName: s.fullName.isEmpty ? s.playerId : s.fullName,
            teamName: (s.teamName ?? '').trim().isNotEmpty
                ? (s.teamName ?? '').trim()
                : 'Sin equipo',
            shirtNumber: s.shirtNumber,
            totalMatchesSuspended: s.pendingMatchesSuspended,
          ),
        )
        .toList();

    final totalMatchesAffected = rows.fold<int>(
      0,
      (acc, item) => acc + item.totalMatchesSuspended,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              label: "Jugadores suspendidos",
              value: "${rows.length}",
              icon: Icons.gavel,
            ),
            _MetricCard(
              label: "Partidos pendientes",
              value: "$totalMatchesAffected",
              icon: Icons.confirmation_number,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle(title: "Registro de suspensiones"),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _ChartCard(
            child: Text(
              "No hay suspensiones para los filtros seleccionados",
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          _ModernTableCard(
            title: "Resumen de suspensiones",
            subtitle: "Partidos pendientes por cumplir por jugador",
            child: _SuspensionsSummaryTable(entries: rows),
          ),
      ],
    );
  }

  List<Team> _availableTeams(
    List<Team> teams, {
    required String? selectedCategoryId,
  }) {
    if (selectedCategoryId == null) {
      return teams;
    }

    return teams.where((t) => t.categoryId == selectedCategoryId).toList();
  }

}

class _SuspensionSummaryRow {
  final String playerId;
  final String playerName;
  final String teamName;
  final int? shirtNumber;
  final int totalMatchesSuspended;

  _SuspensionSummaryRow({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.shirtNumber,
    required this.totalMatchesSuspended,
  });
}

class _CardsSummaryRow {
  final String playerId;
  final String playerName;
  final String teamName;
  final int? shirtNumber;
  final int yellowCards;
  final int redDirectCards;

  _CardsSummaryRow({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.shirtNumber,
    required this.yellowCards,
    required this.redDirectCards,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final Widget child;

  const _FilterCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A2332),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0F172A),
      ),
      child: child,
    );
  }
}

class _ModernTableCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ModernTableCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CardsSummaryTable extends StatelessWidget {
  final List<_CardsSummaryRow> entries;

  const _CardsSummaryTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CompactTableHeader(
          children: [
            _CompactCell(text: "Jugador", flex: 30, isHeader: true),
            _CompactCell(text: "Equipo", flex: 22, isHeader: true),
            _CompactCell(text: "Dorsal", flex: 14, isHeader: true, align: TextAlign.center),
            _CompactCell(text: "Amarilla", flex: 18, isHeader: true, align: TextAlign.center),
            _CompactCell(text: "Roja", flex: 16, isHeader: true, align: TextAlign.center),
          ],
        ),
        ...entries.map(
          (entry) => _CompactTableRow(
            children: [
              _CompactCell(text: entry.playerName, flex: 30),
              _CompactCell(text: entry.teamName, flex: 22),
              _CompactCell(
                text: entry.shirtNumber?.toString() ?? "--",
                flex: 14,
                align: TextAlign.center,
              ),
              _CompactCell(
                text: '${entry.yellowCards}',
                flex: 18,
                align: TextAlign.center,
              ),
              _CompactCell(
                text: '${entry.redDirectCards}',
                flex: 16,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuspensionsSummaryTable extends StatelessWidget {
  final List<_SuspensionSummaryRow> entries;

  const _SuspensionsSummaryTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CompactTableHeader(
          children: [
            _CompactCell(text: "Jugador", flex: 34, isHeader: true),
            _CompactCell(text: "Equipo", flex: 22, isHeader: true),
            _CompactCell(text: "Dorsal", flex: 14, isHeader: true, align: TextAlign.center),
            _CompactCell(text: "Pendientes", flex: 30, isHeader: true, align: TextAlign.center),
          ],
        ),
        ...entries.map(
          (entry) => _CompactTableRow(
            children: [
              _CompactCell(text: entry.playerName, flex: 34),
              _CompactCell(text: entry.teamName, flex: 22),
              _CompactCell(
                text: entry.shirtNumber?.toString() ?? "--",
                flex: 14,
                align: TextAlign.center,
              ),
              _CompactCell(
                text: "${entry.totalMatchesSuspended}",
                flex: 30,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactTableHeader extends StatelessWidget {
  final List<Widget> children;

  const _CompactTableHeader({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white70, width: 1),
        ),
      ),
      child: Row(children: children),
    );
  }
}

class _CompactTableRow extends StatelessWidget {
  final List<Widget> children;

  const _CompactTableRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white24, width: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _CompactCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isHeader;
  final TextAlign align;

  const _CompactCell({
    required this.text,
    required this.flex,
    this.isHeader = false,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          textAlign: align,
          softWrap: true,
          style: TextStyle(
            fontSize: isHeader ? 9.5 : 9.5,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
            color: isHeader ? Colors.white : Colors.white.withValues(alpha: 0.92),
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
