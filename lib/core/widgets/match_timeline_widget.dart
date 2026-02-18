import 'package:flutter/material.dart';
import '../../../../models/match_event.dart';

class MatchTimelineWidget extends StatelessWidget {
  final List<MatchEvent> events;

  const MatchTimelineWidget({
    super.key,
    required this.events,
  });

  IconData _icon(String type) {
    switch (type) {
      case 'GOAL':
        return Icons.sports_soccer;
      case 'OWN_GOAL':
        return Icons.warning;
      case 'YELLOW':
        return Icons.square;
      case 'RED':
        return Icons.stop;
      case 'SUB_IN':
        return Icons.arrow_downward;
      case 'SUB_OUT':
        return Icons.arrow_upward;
      default:
        return Icons.circle;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'GOAL':
        return Colors.green;
      case 'OWN_GOAL':
        return Colors.orange;
      case 'YELLOW':
        return Colors.yellow;
      case 'RED':
        return Colors.red;
      case 'SUB_IN':
        return Colors.blue;
      case 'SUB_OUT':
        return Colors.purple;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          "Sin eventos aún",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
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
              Text(
                "${event.minute}'",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                _icon(event.eventType),
                color: _color(event.eventType),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.eventType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
