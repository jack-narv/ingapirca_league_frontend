import 'package:flutter/material.dart';
import '../../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../../models/match_lineup.dart';
import '../../../../services/match_lineups_service.dart';
import '../../../../services/auth_service.dart';

class MatchLineupScreen extends StatefulWidget {
  final String matchId;
  final String teamId;
  final String teamName;

  const MatchLineupScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<MatchLineupScreen> createState() =>
      _MatchLineupScreenState();
}

class _MatchLineupScreenState
    extends State<MatchLineupScreen> {
  final MatchLineupsService _service =
      MatchLineupsService();

  late Future<List<MatchLineupPlayer>> _future;

  List<MatchLineupPlayer> _players = [];

  bool _loading = false;
  bool _canEdit = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getLineup(
        widget.matchId, widget.teamId);

    _checkRole();
  }

  void _checkRole() async {
    final canManage =
        await AuthService().canManageTeams();
    if (!mounted) return;
    setState(() => _canEdit = canManage);
  }

  int get _startingCount =>
      _players.where((p) => p.isStarting).length;

  void _toggleStarting(int index) {
    if (!_canEdit) return;

    if (!_players[index].isStarting &&
        _startingCount >= 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Máximo 11 jugadores titulares"),
        ),
      );
      return;
    }

    setState(() {
      final p = _players[index];
      _players[index] = MatchLineupPlayer(
        playerId: p.playerId,
        playerName: p.playerName,
        shirtNumber: p.shirtNumber,
        position: p.position,
        isStarting: !p.isStarting,
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      await _service.submitLineup(
        matchId: widget.matchId,
        teamId: widget.teamId,
        players: _players,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Alineación enviada"),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error enviando alineación"),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Alineación - ${widget.teamName}",
      currentIndex: 0,
      onNavTap: (_) {},
      body: FutureBuilder<List<MatchLineupPlayer>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          _players = snapshot.data!;

          if (_players.isEmpty) {
            return const Center(
              child: Text(
                "No hay alineación aún",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._players
                  .asMap()
                  .entries
                  .map((entry) => _buildPlayerCard(
                        entry.key,
                        entry.value,
                      )),
              const SizedBox(height: 40),
              if (_canEdit)
                PrimaryGradientButton(
                  text: "Enviar Alineación",
                  loading: _loading,
                  onPressed: _submit,
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Titulares",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$_startingCount / 11",
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
      int index, MatchLineupPlayer player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.2),
            child: Text(
              player.shirtNumber.toString(),
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              player.playerName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _positionBadge(player.position),
          const SizedBox(width: 12),
          if (_canEdit)
            Switch(
              value: player.isStarting,
              onChanged: (_) =>
                  _toggleStarting(index),
              activeColor:
                  Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _positionBadge(String pos) {
    Color color;

    switch (pos) {
      case 'GK':
        color = Colors.orange;
        break;
      case 'DF':
        color = Colors.blue;
        break;
      case 'MF':
        color = Colors.green;
        break;
      case 'FW':
        color = Colors.red;
        break;
      default:
        color = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        pos,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
