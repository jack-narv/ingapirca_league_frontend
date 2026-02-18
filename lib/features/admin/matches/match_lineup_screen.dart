import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/match_lineup.dart';
import '../../../models/team_player.dart';
import '../../../services/auth_service.dart';
import '../../../services/match_lineups_service.dart';
import '../../../services/players_service.dart';

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
  State<MatchLineupScreen> createState() => _MatchLineupScreenState();
}

class _MatchLineupScreenState extends State<MatchLineupScreen> {
  final MatchLineupsService _service = MatchLineupsService();
  final PlayersService _playersService = PlayersService();

  late Future<List<MatchLineupPlayer>> _future;

  List<MatchLineupPlayer> _players = [];

  bool _loading = false;
  bool _canEdit = false;
  bool _isAdmin = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _future = _service.getLineup(widget.matchId, widget.teamId);
    _checkRole();
  }

  void _checkRole() async {
    final isAdmin = await AuthService().isAdmin();
    final canManage = await AuthService().canManageTeams();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _canEdit = canManage;
    });
  }

  int get _startingCount => _players.where((p) => p.isStarting).length;

  void _toggleStarting(int index) {
    if (!_canEdit) return;

    if (!_players[index].isStarting && _startingCount >= 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximo 11 jugadores titulares'),
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
    if (_players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega jugadores a la alineacion'),
        ),
      );
      return;
    }

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
          content: Text('Alineacion enviada'),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error enviando alineacion'),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createLineupFromTeam() async {
    final roster = await _playersService.getByTeam(widget.teamId);

    if (!mounted) return;

    if (roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay jugadores asignados al equipo'),
        ),
      );
      return;
    }

    final selected = await showDialog<List<MatchLineupPlayer>>(
      context: context,
      builder: (_) => _BuildLineupDialog(
        teamName: widget.teamName,
        roster: roster,
      ),
    );

    if (selected == null) return;

    setState(() {
      _players = selected;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: 'Alineacion - ${widget.teamName}',
      currentIndex: 0,
      onNavTap: (_) {},
      body: FutureBuilder<List<MatchLineupPlayer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudo cargar la alineacion',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _initialized = false;
                        _future = _service.getLineup(
                          widget.matchId,
                          widget.teamId,
                        );
                      });
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const SizedBox();
          }

          if (!_initialized) {
            _players = List<MatchLineupPlayer>.from(snapshot.data!);
            _initialized = true;
          }

          if (_players.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No hay alineacion aun',
                    style: TextStyle(color: Colors.white70),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _createLineupFromTeam,
                      child: const Text('Crear Alineacion'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._players.asMap().entries.map(
                    (entry) => _buildPlayerCard(
                      entry.key,
                      entry.value,
                    ),
                  ),
              const SizedBox(height: 20),
              if (_isAdmin)
                OutlinedButton(
                  onPressed: _createLineupFromTeam,
                  child: const Text('Rehacer Alineacion'),
                ),
              const SizedBox(height: 20),
              if (_canEdit)
                PrimaryGradientButton(
                  text: 'Enviar Alineacion',
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
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Titulares',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_startingCount / 11',
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(int index, MatchLineupPlayer player) {
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
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              player.shirtNumber.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
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
              onChanged: (_) => _toggleStarting(index),
              activeThumbColor:
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
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

class _BuildLineupDialog extends StatefulWidget {
  final String teamName;
  final List<TeamPlayer> roster;

  const _BuildLineupDialog({
    required this.teamName,
    required this.roster,
  });

  @override
  State<_BuildLineupDialog> createState() => _BuildLineupDialogState();
}

class _BuildLineupDialogState extends State<_BuildLineupDialog> {
  final Set<String> _selectedPlayerIds = {};
  final Set<String> _startingPlayerIds = {};

  void _toggleSelected(TeamPlayer player, bool selected) {
    setState(() {
      if (selected) {
        _selectedPlayerIds.add(player.playerId);
      } else {
        _selectedPlayerIds.remove(player.playerId);
        _startingPlayerIds.remove(player.playerId);
      }
    });
  }

  void _toggleStarting(TeamPlayer player, bool isStarting) {
    setState(() {
      if (isStarting && !_startingPlayerIds.contains(player.playerId) &&
          _startingPlayerIds.length >= 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximo 11 jugadores titulares'),
          ),
        );
        return;
      }

      if (isStarting) {
        _selectedPlayerIds.add(player.playerId);
        _startingPlayerIds.add(player.playerId);
      } else {
        _startingPlayerIds.remove(player.playerId);
      }
    });
  }

  void _confirm() {
    final selectedPlayers = widget.roster
        .where((p) => _selectedPlayerIds.contains(p.playerId))
        .map(
          (p) => MatchLineupPlayer(
            playerId: p.playerId,
            playerName: '${p.player.firstName} ${p.player.lastName}',
            shirtNumber: p.shirtNumber,
            position: p.position,
            isStarting: _startingPlayerIds.contains(p.playerId),
          ),
        )
        .toList();

    if (selectedPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un jugador'),
        ),
      );
      return;
    }

    Navigator.pop(context, selectedPlayers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text('Crear Alineacion - ${widget.teamName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.roster.length,
          itemBuilder: (context, index) {
            final player = widget.roster[index];
            final selected = _selectedPlayerIds.contains(player.playerId);
            final starting = _startingPlayerIds.contains(player.playerId);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (v) => _toggleSelected(player, v ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player.player.firstName} ${player.player.lastName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '#${player.shirtNumber} - ${player.position}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: starting,
                    onChanged: selected
                        ? (v) => _toggleStarting(player, v)
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          child: const Text('Usar Alineacion'),
        ),
      ],
    );
  }
}
