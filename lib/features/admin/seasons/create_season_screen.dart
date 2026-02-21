import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/seasons_service.dart';
import '../../home/home_screen.dart';

class _CategoryDraft {
  final TextEditingController nameController;

  _CategoryDraft()
      : nameController = TextEditingController();

  void dispose() {
    nameController.dispose();
  }
}

class CreateSeasonScreen extends StatefulWidget {
  final String leagueId;

  const CreateSeasonScreen({
    super.key,
    required this.leagueId,
  });

  @override
  State<CreateSeasonScreen> createState() => _CreateSeasonScreenState();
}

class _CreateSeasonScreenState extends State<CreateSeasonScreen> {
  final _nameController = TextEditingController();
  final SeasonsService _service = SeasonsService();
  final AuthService _authService = AuthService();
  final _formatter = DateFormat("yyyy/MM/dd");

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isAdmin = false;
  bool _checkingRole = true;
  bool _loading = false;
  final List<_CategoryDraft> _categoryDrafts = [];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final draft in _categoryDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRole() async {
    final isAdmin = await _authService.isAdmin();
    if (!mounted) return;

    setState(() {
      _isAdmin = isAdmin;
      _checkingRole = false;
      if (_isAdmin && _categoryDrafts.isEmpty) {
        _categoryDrafts.add(_CategoryDraft());
      }
    });
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

  Future<void> _pickDate({
    required bool isStart,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  void _createSeason() async {
    if (_nameController.text.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos")),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La fecha fin debe ser posterior al inicio")),
      );
      return;
    }

    final categoryNames = _categoryDrafts
        .map((d) => d.nameController.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (categoryNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes agregar al menos 1 categoria"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final season = await _service.createSeason(
        leagueId: widget.leagueId,
        name: _nameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (_isAdmin && categoryNames.isNotEmpty) {
        await Future.wait(
          List.generate(
            categoryNames.length,
            (index) => _service.createCategory(
              seasonId: season.id,
              name: categoryNames[index],
              sortOrder: index + 1,
            ),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error creando temporada")),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addCategory() {
    setState(() {
      _categoryDrafts.add(_CategoryDraft());
    });
  }

  void _removeCategory(int index) {
    setState(() {
      final removed = _categoryDrafts.removeAt(index);
      removed.dispose();
    });
  }

  Widget _buildInput() {
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
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: "Nombre de la temporada",
          prefixIcon: Icon(Icons.event_note),
        ),
      ),
    );
  }

  Widget _buildDateCard({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF1A2332),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date == null ? label : _formatter.format(date),
                style: TextStyle(
                  fontSize: 15,
                  color: date == null ? Colors.white70 : Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Temporada",
      currentIndex: 0,
      onNavTap: _handleBottomNavTap,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nueva Temporada",
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Define el periodo de competencia.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            _buildInput(),
            _buildDateCard(
              label: "Selecciona fecha de inicio",
              date: _startDate,
              onTap: () => _pickDate(isStart: true),
            ),
            _buildDateCard(
              label: "Selecciona fecha de fin",
              date: _endDate,
              onTap: () => _pickDate(isStart: false),
            ),
            if (_checkingRole)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_checkingRole && _isAdmin) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Categorias de temporada",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text("Agregar"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_categoryDrafts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Text(
                    "No hay categorias agregadas.",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ...List.generate(_categoryDrafts.length, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
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
                    controller: _categoryDrafts[index].nameController,
                    decoration: InputDecoration(
                      labelText: "Categoria ${index + 1}",
                      prefixIcon: const Icon(Icons.category),
                      suffixIcon: _categoryDrafts.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeCategory(index),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
            PrimaryGradientButton(
              text: "Crear Temporada",
              loading: _loading,
              onPressed: _createSeason,
            ),
          ],
        ),
      ),
    );
  }
}
