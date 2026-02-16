import 'package:flutter/material.dart';
import '../../../services/leagues_service.dart';
import '../../../core/widgets/primary_gradient_button.dart';

class CreateLeagueScreen extends StatefulWidget{
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() =>
    _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen>{
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _service = LeaguesService();

  bool _loading = false;

  void _createLeague() async{
    setState(() => _loading = true);

    try{
      await _service.createLeague(
        _nameController.text.trim(),
        _countryController.text.trim(),
        _cityController.text.trim(),
      );

      Navigator.pop(context);
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al crear la liga")),
      );
    }finally{
      setState(()=> _loading = false);
    }
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
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
        onPressed: _loading ? null : _createLeague,
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
                "Crear Liga",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Campeonato"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Nueva Liga",
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Completa la información para crear un nuevo campeonato.",
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 30),

            _buildInput(
              controller: _nameController,
              label: "Nombre del campeonato",
              icon: Icons.emoji_events_outlined,
            ),
            _buildInput(
              controller: _countryController,
              label: "País",
              icon: Icons.public,
            ),
            _buildInput(
              controller: _cityController,
              label: "Ciudad",
              icon: Icons.location_city,
            ),

            const SizedBox(height: 20),

            PrimaryGradientButton(
              text: "Crear Campeonato",
              loading: _loading,
              onPressed: _createLeague,
            ),
          ],
        ),
      ),
    );
  }
}