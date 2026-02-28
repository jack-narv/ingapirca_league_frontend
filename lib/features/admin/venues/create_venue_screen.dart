import 'package:flutter/material.dart';
import '../../../core/navigation/season_bottom_nav.dart';
import '../../../core/widgets/app_scaffold_with_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../services/venues_service.dart';

class CreateVenueScreen extends StatefulWidget{
  final String seasonId;
  final String seasonName;

  const CreateVenueScreen({
    super.key,
    required this.seasonId,
    required this.seasonName,
  });

  @override
  State<CreateVenueScreen> createState() =>
    _CreateVenueScreenState();
}

class _CreateVenueScreenState
  extends State<CreateVenueScreen>{
    final _name = TextEditingController();
    final _address = TextEditingController();
    final VenuesService _service = VenuesService();

    bool _loading = false;

    Future<void> _create() async{
      if(_name.text.isEmpty){
        ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
            content:
              Text("El nombre es obligatorio")
            ),
          );
          return; 
      }

      setState(() {
        _loading = true;
      });

      try{
        await _service.create(
          seasonId: widget.seasonId,
          name: _name.text.trim(),
          address:
            _address.text.trim().isEmpty
              ? null: _address.text.trim(),
        );

        if(!mounted) return;
        Navigator.pop(context);
      }catch(e){
        ScaffoldMessenger.of(context)
          .showSnackBar(
            const SnackBar(
              content: 
                Text("Error creando excenario")
            ),
          );
      }finally{
        setState(() {
          _loading = false;
        });

      }
    }

    @override
    Widget build(BuildContext context) {
      return AppScaffoldWithNav(
        title: "Crear Escenario",
        currentIndex: 0,
        navItems: seasonNavItems,
        onNavTap: (index) => handleSeasonNavTap(
          context,
          tappedIndex: index,
          currentIndex: 0,
          seasonId: widget.seasonId,
          seasonName: widget.seasonName,
        ),
        body: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Nombre del escenario",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _address,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Dirección (opcional)",
                ),
              ),
              const SizedBox(height: 30),
              PrimaryGradientButton(
                text: "Crear Escenario",
                loading: _loading,
                onPressed: _create,
              ),
            ],
          ),
        ),
      );
    }
}
  
