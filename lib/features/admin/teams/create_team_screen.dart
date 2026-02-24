import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/season_category.dart';
import '../../../services/seasons_service.dart';
import '../../../services/teams_service.dart';
import '../../home/home_screen.dart';

class CreateTeamScreen extends StatefulWidget {
  final String seasonId;

  const CreateTeamScreen({
    super.key,
    required this.seasonId,
  });

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameController = TextEditingController();
  final _foundedController = TextEditingController();
  final _logoController = TextEditingController();
  final TeamsService _service = TeamsService();
  final SeasonsService _seasonsService =
      SeasonsService();
  late Future<List<SeasonCategory>>
      _categoriesFuture;
  SeasonCategory? _selectedCategory;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture =
        _seasonsService.getCategoriesBySeason(
      widget.seasonId,
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 1)),
      (route) => false,
    );
  }

  void _createTeam() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El nombre es obligatorio"),
        ),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecciona una categoria"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.createTeam(
        seasonId: widget.seasonId,
        categoryId: _selectedCategory!.id,
        name: _nameController.text.trim(),
        foundedYear: _foundedController.text.isEmpty
            ? null
            : int.parse(_foundedController.text.trim()),
        logoUrl: _logoController.text.isEmpty ? null : _logoController.text.trim(),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error creando equipo"),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? type,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Equipo",
      currentIndex: 0,
      onNavTap: _handleBottomNavTap,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nuevo Equipo",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Agrega un equipo a la temporada.",
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),
            FutureBuilder<List<SeasonCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding:
                        EdgeInsets.only(bottom: 20),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  );
                }

                final categories =
                    snapshot.data!;

                return Container(
                  margin: const EdgeInsets.only(
                      bottom: 20),
                  child:
                      DropdownButtonFormField<SeasonCategory>(
                    initialValue: _selectedCategory,
                    decoration:
                        const InputDecoration(
                      labelText: "Categoria",
                      prefixIcon:
                          Icon(Icons.category),
                    ),
                    items: categories
                        .map((category) =>
                            DropdownMenuItem<
                                SeasonCategory>(
                              value: category,
                              child:
                                  Text(category.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory =
                            value;
                      });
                    },
                  ),
                );
              },
            ),
            _buildInput(
              controller: _nameController,
              label: "Nombre del equipo",
              icon: Icons.shield,
            ),
            _buildInput(
              controller: _foundedController,
              label: "Anio de fundacion (opcional)",
              icon: Icons.calendar_today,
              type: TextInputType.number,
            ),
            _buildInput(
              controller: _logoController,
              label: "URL del logo (opcional)",
              icon: Icons.image,
            ),
            const SizedBox(height: 10),
            PrimaryGradientButton(
              text: "Crear Equipo",
              loading: _loading,
              onPressed: _createTeam,
            ),
          ],
        ),
      ),
    );
  }
}
