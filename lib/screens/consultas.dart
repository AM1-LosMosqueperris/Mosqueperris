import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/validadores.dart';

class ConsultasScreen extends StatefulWidget {
  const ConsultasScreen({super.key});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _mensaje = TextEditingController();

  bool _enviando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviarConsulta() async {
    if (_enviando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
    });

    try {
      final usuario = Supabase.instance.client.auth.currentUser;

      if (usuario == null) {
        if (!mounted) return;

        setState(() {
          _enviando = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Inicia sesión'),
            content: const Text(
              'Para enviar una consulta necesitas iniciar sesión '
              'o crear una cuenta en PetCare.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF17623F),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );

        return;
      }

      await Supabase.instance.client.from('consultas').insert({
        'usuario_id': usuario.id,
        'nombre': _nombre.text.trim(),
        'telefono': _telefono.text.trim(),
        'mensaje': _mensaje.text.trim(),
      });

      if (!mounted) return;

      _nombre.clear();
      _telefono.clear();
      _mensaje.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta enviada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar consulta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Formulario de consulta'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Tienes alguna consulta?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Completa los siguientes datos para contactarnos.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 25),

              TextFormField(
                controller: _nombre,
                validator: Validadores.nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                validator: Validadores.telefono,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Ej. 71234567',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller: _mensaje,
                maxLines: 4,
                validator: Validadores.mensaje,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.message_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _enviarConsulta,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Enviando...' : 'Enviar consulta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: verdeClaro,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'El teléfono debe tener 8 dígitos y comenzar con 6 o 7.',
                  style: TextStyle(color: verde),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
