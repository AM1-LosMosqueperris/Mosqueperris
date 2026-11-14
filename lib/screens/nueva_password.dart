import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NuevaPasswordScreen extends StatefulWidget {
  const NuevaPasswordScreen({super.key});

  @override
  State<NuevaPasswordScreen> createState() => _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends State<NuevaPasswordScreen> {
  static const Color verde = Color(0xFF17623F);

  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _cargando = false;
  bool _mostrarPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _actualizarPassword() async {
    final password = _passwordController.text;
    final confirmar = _confirmarController.text;

    if (password.length < 6) {
      _mensaje('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    if (password != confirmar) {
      _mensaje('Las contraseñas no coinciden.');
      return;
    }

    setState(() => _cargando = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      _mensaje('Contraseña actualizada correctamente.');

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/app', (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return;
      _mensaje(e.message);
    } catch (e) {
      if (!mounted) return;
      _mensaje('No se pudo actualizar la contraseña.');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: verde));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Text('Nueva contraseña'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const Icon(Icons.lock_reset, size: 75, color: verde),
                const SizedBox(height: 20),
                const Text(
                  'Restablecer contraseña',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ingresa tu nueva contraseña para continuar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _passwordController,
                  obscureText: !_mostrarPassword,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _mostrarPassword = !_mostrarPassword;
                        });
                      },
                      icon: Icon(
                        _mostrarPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _confirmarController,
                  obscureText: !_mostrarPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 53,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _actualizarPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _cargando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Guardar nueva contraseña',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
