import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/players_service.dart';

class CreatePlayerScreen extends StatefulWidget {
  final String teamId;
  final String seasonId;
  final String seasonName;

  const CreatePlayerScreen({
    super.key,
    required this.teamId,
    required this.seasonId,
    required this.seasonName,
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
  final _identityCard = TextEditingController();
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
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  Future<void> _create() async {
    final identityCard = _identityCard.text.trim();

    if (_firstName.text.isEmpty ||
        _lastName.text.isEmpty ||
        _nationality.text.isEmpty ||
        identityCard.isEmpty ||
        _shirtNumber.text.isEmpty ||
        _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa todos los campos"),
        ),
      );
      return;
    }

    if (identityCard.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La cédula debe tener 10 dígitos"),
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
        identityCard: identityCard,
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
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? "Error creando jugador" : message,
          ),
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
    _identityCard.dispose();
    _photoUrl.dispose();
    _shirtNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Jugador",
      currentIndex: 2,
      navItems: seasonNavItems,
      onNavTap: (index) => handleSeasonNavTap(
        context,
        tappedIndex: index,
        currentIndex: 2,
        seasonId: widget.seasonId,
        seasonName: widget.seasonName,
      ),
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
              controller: _identityCard,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: "Cédula de Identidad",
              ),
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
