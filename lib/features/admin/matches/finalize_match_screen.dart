import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/match.dart';
import '../../../models/match_lineup.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/matches_service.dart';

class FinalizeMatchScreen extends StatefulWidget {
  final Match match;
  final String homeTeamName;
  final String awayTeamName;

  const FinalizeMatchScreen({
    super.key,
    required this.match,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  State<FinalizeMatchScreen> createState() =>
      _FinalizeMatchScreenState();
}

class _FinalizeMatchScreenState
    extends State<FinalizeMatchScreen> {
  final MatchesService _matchesService = MatchesService();
  final MatchLineupsService _lineupsService =
      MatchLineupsService();

  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;
  late final TextEditingController _adminObservationController;
  late final TextEditingController _homeObservationController;
  late final TextEditingController _awayObservationController;

  List<MatchLineupPlayer> _homeLineup = [];
  List<MatchLineupPlayer> _awayLineup = [];

  String? _homeSubmittedBy;
  String? _awaySubmittedBy;

  bool _loading = false;
  bool _lineupsLoading = true;

  @override
  void initState() {
    super.initState();
    _homeScoreController = TextEditingController(
      text: widget.match.homeScore.toString(),
    );
    _awayScoreController = TextEditingController(
      text: widget.match.awayScore.toString(),
    );
    _adminObservationController = TextEditingController(
      text: widget.match.observations ?? '',
    );
    _homeObservationController = TextEditingController();
    _awayObservationController = TextEditingController();
    _loadLineups();
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    _adminObservationController.dispose();
    _homeObservationController.dispose();
    _awayObservationController.dispose();
    super.dispose();
  }

  Future<void> _loadLineups() async {
    setState(() => _lineupsLoading = true);
    try {
      final home = await _lineupsService.getLineup(
        widget.match.id,
        widget.match.homeTeamId,
      );
      final away = await _lineupsService.getLineup(
        widget.match.id,
        widget.match.awayTeamId,
      );
      if (!mounted) return;
      setState(() {
        _homeLineup = home;
        _awayLineup = away;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cargar la alineacion. Puedes finalizar sin observaciones de equipos.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _lineupsLoading = false);
    }
  }

  Future<void> _finalize() async {
    final homeScore = int.tryParse(_homeScoreController.text.trim());
    final awayScore = int.tryParse(_awayScoreController.text.trim());

    if (homeScore == null || awayScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un marcador valido'),
        ),
      );
      return;
    }

    if (homeScore < 0 || awayScore < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El marcador no puede ser negativo'),
        ),
      );
      return;
    }

    final adminObservation =
        _adminObservationController.text.trim();
    final homeObservation =
        _homeObservationController.text.trim();
    final awayObservation =
        _awayObservationController.text.trim();

    if (homeObservation.isNotEmpty && _homeSubmittedBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona el jugador del equipo local',
          ),
        ),
      );
      return;
    }

    if (awayObservation.isNotEmpty && _awaySubmittedBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona el jugador del equipo visitante',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _matchesService.finishMatch(
        widget.match.id,
        homeScore,
        awayScore,
        adminObservation.isEmpty ? null : adminObservation,
      );

      if (homeObservation.isNotEmpty) {
        await _matchesService.submitTeamObservation(
          matchId: widget.match.id,
          teamId: widget.match.homeTeamId,
          submittedBy: _homeSubmittedBy!,
          observation: homeObservation,
        );
      }

      if (awayObservation.isNotEmpty) {
        await _matchesService.submitTeamObservation(
          matchId: widget.match.id,
          teamId: widget.match.awayTeamId,
          submittedBy: _awaySubmittedBy!,
          observation: awayObservation,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partido finalizado'),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error finalizando partido'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: 'Finalizar Partido',
      currentIndex: 0,
      onNavTap: (_) {},
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildScoreSection(),
          const SizedBox(height: 12),
          _buildAdminObservationSection(),
          const SizedBox(height: 12),
          _buildTeamObservationSection(
            title: widget.homeTeamName,
            players: _homeLineup,
            selectedPlayerId: _homeSubmittedBy,
            onPlayerChanged: (value) {
              setState(() => _homeSubmittedBy = value);
            },
            controller: _homeObservationController,
            loading: _lineupsLoading,
          ),
          const SizedBox(height: 12),
          _buildTeamObservationSection(
            title: widget.awayTeamName,
            players: _awayLineup,
            selectedPlayerId: _awaySubmittedBy,
            onPlayerChanged: (value) {
              setState(() => _awaySubmittedBy = value);
            },
            controller: _awayObservationController,
            loading: _lineupsLoading,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _finalize,
                  child: Text(
                    _loading ? 'Finalizando...' : 'Finalizar',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildScoreSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2332),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resultado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _homeScoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Goles ${widget.homeTeamName}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _awayScoreController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Goles ${widget.awayTeamName}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminObservationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2332),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observacion del vocal',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Opcional',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminObservationController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ej: incidencias, notas finales, etc.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamObservationSection({
    required String title,
    required List<MatchLineupPlayer> players,
    required String? selectedPlayerId,
    required ValueChanged<String?> onPlayerChanged,
    required TextEditingController controller,
    required bool loading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A2332),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observacion de $title',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Opcional',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedPlayerId,
            isExpanded: true,
            items: players.map((p) {
              final role = p.isStarting ? 'Titular' : 'Suplente';
              return DropdownMenuItem<String>(
                value: p.playerId,
                child: Text(
                  '${p.playerName} (#${p.shirtNumber}) - $role',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: loading || players.isEmpty ? null : onPlayerChanged,
            decoration: InputDecoration(
              labelText: loading
                  ? 'Cargando jugadores...'
                  : players.isEmpty
                      ? 'Sin alineacion registrada'
                      : 'Jugador que reporta',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe la observacion del equipo',
            ),
          ),
        ],
      ),
    );
  }
}
