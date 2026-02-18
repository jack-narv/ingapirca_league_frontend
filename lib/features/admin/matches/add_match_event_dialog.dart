import 'package:flutter/material.dart';
import '../../../../services/match_events_service.dart';

class AddMatchEventDialog extends StatefulWidget {
  final String matchId;
  final String teamId;
  final String playerId;

  const AddMatchEventDialog({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.playerId,
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

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      await _service.createEvent(
        matchId: widget.matchId,
        teamId: widget.teamId,
        playerId: widget.playerId,
        minute: _minute,
        eventType: _type,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Añadir Evento"),
      content: Column(
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
            value: _type,
            items: const [
              DropdownMenuItem(
                  value: 'GOAL',
                  child: Text('Gol')),
              DropdownMenuItem(
                  value: 'YELLOW',
                  child: Text('Amarilla')),
              DropdownMenuItem(
                  value: 'RED',
                  child: Text('Roja')),
              DropdownMenuItem(
                  value: 'OWN_GOAL',
                  child: Text('Autogol')),
            ],
            onChanged: (v) =>
                setState(() => _type = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
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
