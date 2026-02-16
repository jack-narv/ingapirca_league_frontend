import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/seasons_service.dart';
import '../../../core/widgets/primary_gradient_button.dart';



class CreateSeasonScreen extends StatefulWidget {
  final String leagueId;

  const CreateSeasonScreen({
    super.key,
    required this.leagueId,
  });

  @override
  State<CreateSeasonScreen> createState() =>
      _CreateSeasonScreenState();
}

class _CreateSeasonScreenState
    extends State<CreateSeasonScreen> {
  final _nameController = TextEditingController();
  final SeasonsService _service = SeasonsService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  final _formatter = DateFormat('yyyy/MM/dd');

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
    if (_nameController.text.isEmpty ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa todos los campos"),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _service.createSeason(
        leagueId: widget.leagueId,
        name: _nameController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error creando temporada"),
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
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
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
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
                date == null
                    ? label
                    : _formatter.format(date),
                style: TextStyle(
                  fontSize: 15,
                  color: date == null
                      ? Colors.white70
                      : Colors.white,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00C853),
            Color(0xFF22D3EE),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: _loading ? null : _createSeason,
        child: _loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Crear Temporada",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Temporada"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              "Nueva Temporada",
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Define el período de competencia.",
              style: TextStyle(
                color: Colors.white70,
              ),
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
