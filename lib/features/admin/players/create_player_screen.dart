import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/players_service.dart';

class CreatePlayerScreen extends StatefulWidget {
  final String teamId;

  const CreatePlayerScreen({
    super.key,
    required this.teamId,
  });

  @override
  State<CreatePlayerScreen> createState() =>
      _CreatePlayerScreenState();
}

class _CreatePlayerScreenState
    extends State<CreatePlayerScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nationality = TextEditingController();
  final _photoUrl = TextEditingController();
  final _shirtNumber = TextEditingController();

  final PlayersService _service = PlayersService();

  DateTime? _birthDate;
  String _position = 'MF';
  bool _loading = false;

  final _formatter = DateFormat('yyyy/MM/dd');

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  Future<void> _create() async {
    if (_firstName.text.isEmpty ||
        _lastName.text.isEmpty ||
        _nationality.text.isEmpty ||
        _shirtNumber.text.isEmpty ||
        _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa todos los campos"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Create Player
      final player = await _service.createPlayer(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        nationality: _nationality.text.trim(),
        birthDate: _birthDate!,
        photoUrl: _photoUrl.text.trim().isEmpty
            ? null
            : _photoUrl.text.trim(),
      );

      // Assign to Team
      await _service.assignPlayer(
        playerId: player.id,
        teamId: widget.teamId,
        shirtNumber: int.parse(_shirtNumber.text),
        position: _position,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error creando jugador"),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nationality.dispose();
    _photoUrl.dispose();
    _shirtNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Jugador",
      currentIndex: 0,
      onNavTap: (_) {},
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _firstName,
              decoration:
                  const InputDecoration(labelText: "Nombre"),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _lastName,
              decoration:
                  const InputDecoration(labelText: "Apellido"),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nationality,
              decoration:
                  const InputDecoration(labelText: "Nacionalidad"),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _photoUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: "URL de foto (opcional)",
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _shirtNumber,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: "Número de camiseta"),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _position,
              decoration:
                  const InputDecoration(labelText: "Posición"),
              items: const [
                DropdownMenuItem(
                    value: 'GK', child: Text('Portero')),
                DropdownMenuItem(
                    value: 'DF', child: Text('Defensa')),
                DropdownMenuItem(
                    value: 'MF', child: Text('Mediocampo')),
                DropdownMenuItem(
                    value: 'FW', child: Text('Delantero')),
              ],
              onChanged: (value) {
                setState(() {
                  _position = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF1A2332),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake),
                    const SizedBox(width: 12),
                    Text(
                      _birthDate == null
                          ? "Fecha de nacimiento"
                          : _formatter.format(_birthDate!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            PrimaryGradientButton(
              text: "Crear Jugador",
              loading: _loading,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}
