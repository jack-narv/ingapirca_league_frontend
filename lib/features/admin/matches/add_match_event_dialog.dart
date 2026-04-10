import 'package:flutter/material.dart';
import '../../../models/match_lineup.dart';
import '../../../services/match_events_service.dart';

class AddMatchEventDialog extends StatefulWidget {
  final String matchId;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final List<MatchLineupPlayer> homeLineup;
  final List<MatchLineupPlayer> awayLineup;

  const AddMatchEventDialog({
    super.key,
    required this.matchId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeLineup,
    required this.awayLineup,
  });

  @override
  State<AddMatchEventDialog> createState() =>
      _AddMatchEventDialogState();
}

class _AddMatchEventDialogState
    extends State<AddMatchEventDialog> {
  final MatchEventsService _service =
      MatchEventsService();

  int _minute = 0;
  String _type = 'GOAL';
  bool _loading = false;

  late String _teamId;
  String? _playerId;
  String? _relatedPlayerId;

  List<MatchLineupPlayer> get _currentLineup =>
      _teamId == widget.homeTeamId
          ? widget.homeLineup
          : widget.awayLineup;

  @override
  void initState() {
    super.initState();
    _teamId = widget.homeTeamId;
    _hydratePlayers();
  }

  void _hydratePlayers() {
    final lineup = _currentLineup;
    _playerId =
        lineup.isNotEmpty ? lineup.first.playerId : null;
    _relatedPlayerId = null;
  }

  Future<void> _submit() async {
    if (_minute < 0 || _minute > 130) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Minuto invalido"),
        ),
      );
      return;
    }

    if (_playerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecciona un jugador"),
        ),
      );
      return;
    }

    final needsRelated =
        _type == 'SUB_IN' || _type == 'SUB_OUT';
    if (needsRelated && _relatedPlayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecciona jugador relacionado"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.createEvent(
        matchId: widget.matchId,
        teamId: _teamId,
        playerId: _playerId!,
        minute: _minute,
        eventType: _type,
        relatedPlayerId: _relatedPlayerId,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context, false);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _playerLabel(MatchLineupPlayer player) {
    return "${player.playerName} (#${player.shirtNumber})";
  }

  Widget _ellipsisText(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  Widget _menuItemText(String value) {
    return Text(
      value,
      maxLines: 3,
      softWrap: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLineup = _currentLineup;
    final relatedPlayers = currentLineup
        .where((p) => p.playerId != _playerId)
        .toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Anadir Evento"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Minuto"),
                onChanged: (v) =>
                    _minute = int.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _teamId,
                items: [
                  DropdownMenuItem(
                    value: widget.homeTeamId,
                    child: _ellipsisText(widget.homeTeamName),
                  ),
                  DropdownMenuItem(
                    value: widget.awayTeamId,
                    child: _ellipsisText(widget.awayTeamName),
                  ),
                ],
                selectedItemBuilder: (_) => [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ellipsisText(widget.homeTeamName),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ellipsisText(widget.awayTeamName),
                  ),
                ],
                decoration:
                    const InputDecoration(labelText: "Equipo"),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _teamId = value;
                    _hydratePlayers();
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                menuMaxHeight: 420,
                initialValue: _playerId,
                items: currentLineup
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.playerId,
                        child: _menuItemText(_playerLabel(p)),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (_) => currentLineup
                    .map(
                      (p) => Align(
                        alignment: Alignment.centerLeft,
                        child: _ellipsisText(_playerLabel(p)),
                      ),
                    )
                    .toList(),
                decoration:
                    const InputDecoration(labelText: "Jugador"),
                onChanged: (v) =>
                    setState(() => _playerId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _type,
                items: const [
                  DropdownMenuItem(
                      value: 'GOAL', child: Text('Gol')),
                  DropdownMenuItem(
                      value: 'YELLOW',
                      child: Text('Amarilla')),
                  DropdownMenuItem(
                      value: 'RED_DIRECT',
                      child: Text('Roja Directa')),
                  DropdownMenuItem(
                      value: 'DOBLE_YELLOW_RED',
                      child: Text('Roja por 2 Amarillas')),
                  DropdownMenuItem(
                      value: 'OWN_GOAL',
                      child: Text('Autogol')),
                  DropdownMenuItem(
                      value: 'SUB_IN',
                      child: Text('Sustitucion (Entra)')),
                  DropdownMenuItem(
                      value: 'SUB_OUT',
                      child: Text('Sustitucion (Sale)')),
                ],
                decoration:
                    const InputDecoration(labelText: "Tipo"),
                onChanged: (v) => setState(() {
                  _type = v ?? 'GOAL';
                  if (_type != 'SUB_IN' &&
                      _type != 'SUB_OUT') {
                    _relatedPlayerId = null;
                  }
                }),
              ),
              if (_type == 'SUB_IN' || _type == 'SUB_OUT') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  menuMaxHeight: 420,
                  initialValue: _relatedPlayerId,
                  items: relatedPlayers
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.playerId,
                          child: _menuItemText(_playerLabel(p)),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (_) => relatedPlayers
                      .map(
                        (p) => Align(
                          alignment: Alignment.centerLeft,
                          child: _ellipsisText(_playerLabel(p)),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: "Jugador relacionado",
                  ),
                  onChanged: (v) => setState(
                      () => _relatedPlayerId = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, false),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}
