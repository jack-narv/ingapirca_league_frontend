import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../models/venue.dart';
import '../../../services/venues_service.dart';
import '../../../services/auth_service.dart';
import 'create_venue_screen.dart';

class VenuesListScreen extends StatefulWidget{
  final String seasonId;
  final String seasonName;

  const VenuesListScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<VenuesListScreen> createState() =>
    _VenuesListScreenState();

}

class _VenuesListScreenState
  extends State<VenuesListScreen>{
    final  VenuesService _service = VenuesService();
    late Future<List<Venue>> _future;

    @override
    void initState(){
      super.initState();
      _future = _service.getBySeason(widget.seasonId);
    }

    void _refresh(){
      setState(() {
        _future = _service.getBySeason(widget.seasonId);
      });
    }

    @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Escenarios - ${widget.seasonName}",
      currentIndex: 0,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 0,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
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
                  builder: (_) =>
                      CreateVenueScreen(
                        seasonId: widget.seasonId,
                        seasonName: widget.seasonName,
                      ),
                ),
              );
              _refresh();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      body: FutureBuilder<List<Venue>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final venues = snapshot.data!;

          if (venues.isEmpty) {
            return const Center(
              child: Text(
                "No hay escenarios aún",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: venues.length,
            itemBuilder: (context, index) {
              final venue = venues[index];

              return Container(
                margin:
                    const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(20),
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset:
                          const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    if (venue.address != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                                top: 6),
                        child: Text(
                          venue.address!,
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

