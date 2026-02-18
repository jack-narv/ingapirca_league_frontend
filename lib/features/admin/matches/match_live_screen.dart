import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../../services/live_match_service.dart';
import '../../../../services/auth_service.dart';

class LiveMatchScreen extends StatefulWidget {
  final String matchId;

  const LiveMatchScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final LiveMatchSocketService _socketService;

  bool _connected = false;

  int _homeScore = 0;
  int _awayScore = 0;

  // Very simple event list for now (we’ll refine to typed model later)
  final List<Map<String, dynamic>> _events = [];

  StreamSubscription? _connSub;
  StreamSubscription? _scoreSub;
  StreamSubscription? _eventSub;
  StreamSubscription? _finishSub;

  @override
  void initState() {
    super.initState();
    _socketService = LiveMatchSocketService(authService: AuthService());
    _initSocket();
  }

  Future<void> _initSocket() async {
    await _socketService.connect();
    _socketService.joinMatch(widget.matchId);

    _connSub = _socketService.connected$.listen((ok) {
      if (!mounted) return;
      setState(() => _connected = ok);
    });

    _scoreSub = _socketService.score$.listen((data) {
      if (!mounted) return;

      // the backend can send any shape, so be tolerant:
      final hs = data['homeScore'] ?? data['home_score'] ?? data['home'];
      final as = data['awayScore'] ?? data['away_score'] ?? data['away'];

      setState(() {
        if (hs is int) _homeScore = hs;
        if (as is int) _awayScore = as;
      });
    });

    _eventSub = _socketService.event$.listen((event) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, event); // newest on top
      });
    });

    _finishSub = _socketService.finished$.listen((data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partido finalizado")),
      );
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _socketService.leaveMatch(widget.matchId);
    _connSub?.cancel();
    _scoreSub?.cancel();
    _eventSub?.cancel();
    _finishSub?.cancel();
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "En Vivo",
      currentIndex: 0,
      onNavTap: (_) {},
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildConnectionCard(),
          const SizedBox(height: 18),
          _buildScoreboard(),
          const SizedBox(height: 18),
          _buildEventsHeader(),
          const SizedBox(height: 10),
          _buildEventsList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A2332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _connected ? Icons.wifi : Icons.wifi_off,
            color: _connected ? Colors.greenAccent : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _connected ? "Conectado en vivo" : "Reconectando…",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: (_connected ? Colors.green : Colors.orange).withOpacity(0.15),
            ),
            child: Text(
              _connected ? "LIVE" : "OFF",
              style: TextStyle(
                color: _connected ? Colors.greenAccent : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
            color: Colors.black.withOpacity(0.5),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Marcador",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "$_homeScore  -  $_awayScore",
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: _connected ? Colors.greenAccent : Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Match ID: ${widget.matchId}",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsHeader() {
    return Row(
      children: [
        const Icon(Icons.bolt, color: Colors.white70),
        const SizedBox(width: 10),
        const Text(
          "Eventos en vivo",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          "${_events.length}",
          style: const TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    if (_events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(
          child: Text(
            "Aún no hay eventos",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      children: _events.map(_buildEventTile).toList(),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e) {
    // Be flexible with server fields
    final type = (e['type'] ?? e['event_type'] ?? 'EVENT').toString();
    final minute = e['minute']?.toString();
    final desc = (e['description'] ?? e['detail'] ?? '').toString();

    final icon = _eventIcon(type);
    final color = _eventColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A2332),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  minute == null ? type : "$type • ${minute}'",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type.toUpperCase()) {
      case 'GOAL':
        return Icons.sports_soccer;
      case 'YELLOW_CARD':
        return Icons.square;
      case 'RED_CARD':
        return Icons.block;
      case 'SUBSTITUTION':
        return Icons.swap_horiz;
      default:
        return Icons.bolt;
    }
  }

  Color _eventColor(String type) {
    switch (type.toUpperCase()) {
      case 'GOAL':
        return Colors.greenAccent;
      case 'YELLOW_CARD':
        return Colors.amber;
      case 'RED_CARD':
        return Colors.redAccent;
      case 'SUBSTITUTION':
        return Colors.cyanAccent;
      default:
        return Colors.blueGrey;
    }
  }
}
