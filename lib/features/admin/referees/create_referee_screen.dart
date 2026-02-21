import 'package:flutter/material.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/referees_service.dart';

class CreateRefereeScreen extends StatefulWidget {
  final String seasonId;

  const CreateRefereeScreen({
    super.key,
    required this.seasonId,
  });

  @override
  State<CreateRefereeScreen> createState() => _CreateRefereeScreenState();
}

class _CreateRefereeScreenState extends State<CreateRefereeScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _phone = TextEditingController();
  final RefereesService _service = RefereesService();

  bool _isActive = true;
  bool _loading = false;

  Future<void> _create() async {
    if (_firstName.text.trim().isEmpty ||
        _lastName.text.trim().isEmpty ||
        _licenseNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa los campos obligatorios"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.createReferee(
        seasonId: widget.seasonId,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        licenseNumber: _licenseNumber.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        isActive: _isActive,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error creando arbitro"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _licenseNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithNav(
      title: "Crear Arbitro",
      currentIndex: 0,
      onNavTap: (_) {},
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _firstName,
              decoration: const InputDecoration(
                labelText: "Nombre",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastName,
              decoration: const InputDecoration(
                labelText: "Apellido",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _licenseNumber,
              decoration: const InputDecoration(
                labelText: "Numero de licencia",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefono (opcional)",
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isActive,
              title: const Text("Arbitro activo"),
              onChanged: (value) {
                setState(() => _isActive = value);
              },
            ),
            const SizedBox(height: 24),
            PrimaryGradientButton(
              text: "Crear Arbitro",
              loading: _loading,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}
