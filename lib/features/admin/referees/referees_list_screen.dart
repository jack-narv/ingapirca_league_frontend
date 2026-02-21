import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/referees.dart';
import '../../../services/auth_service.dart';
import '../../../services/referees_service.dart';
import 'create_referee_screen.dart';

class RefereesListScreen extends StatefulWidget {
  final String seasonId;
  final String seasonName;

  const RefereesListScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<RefereesListScreen> createState() => _RefereesListScreenState();
}

class _RefereesListScreenState extends State<RefereesListScreen> {
  final RefereesService _service = RefereesService();
  late Future<List<Referee>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getBySeason(widget.seasonId);
  }

  void _refresh() {
    setState(() {
      _future = _service.getBySeason(widget.seasonId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Arbitros - ${widget.seasonName}",
      currentIndex: 0,
      onNavTap: (_) {},
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService().isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!) {
            return const SizedBox();
          }

          return FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRefereeScreen(
                    seasonId: widget.seasonId,
                  ),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<Referee>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "No se pudieron cargar los arbitros.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text(
                "Sin datos de arbitros",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          final referees = snapshot.data!;

          if (referees.isEmpty) {
            return const Center(
              child: Text(
                "No hay arbitros en esta temporada",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: referees.length,
            itemBuilder: (context, index) {
              final referee = referees[index];
              final initial =
                  referee.firstName.isNotEmpty ? referee.firstName[0] : "?";

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      child: Text(
                        initial.toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            referee.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Licencia: ${referee.licenseNumber}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          if ((referee.phone ?? '').trim().isNotEmpty)
                            Text(
                              "Telefono: ${referee.phone}",
                              style: const TextStyle(color: Colors.white60),
                            ),
                        ],
                      ),
                    ),
                    _statusChip(referee.isActive),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(bool isActive) {
    final color = isActive ? Colors.green : Colors.orange;
    final label = isActive ? "Activo" : "Inactivo";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
