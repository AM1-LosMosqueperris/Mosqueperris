import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NuevaPasswordScreen extends StatefulWidget {
  const NuevaPasswordScreen({super.key});

  @override
  State<NuevaPasswordScreen> createState() => _NuevaPasswordScreenState();
}

class _NuevaPasswordScreenState extends State<NuevaPasswordScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _cargando = false;
  bool _mostrarPassword = false;
  bool _mostrarConfirmacion = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _actualizarPassword() async {
    FocusScope.of(context).unfocus();

    final password = _passwordController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (password.isEmpty || confirmar.isEmpty) {
      _mensaje('Completa ambos campos de contraseña.');
      return;
    }

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

      _mensaje('¡Contraseña actualizada correctamente!');

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _campoPassword({
    required TextEditingController controller,
    required String etiqueta,
    required bool mostrar,
    required VoidCallback alternar,
  }) {
    return TextField(
      controller: controller,
      obscureText: !mostrar,
      enabled: !_cargando,
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const Icon(Icons.lock_outline, color: verde),
        suffixIcon: IconButton(
          onPressed: alternar,
          icon: Icon(
            mostrar ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
          ),
        ),
        filled: true,
        fillColor: fondo,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: verde, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nueva contraseña',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 85,
                        height: 85,
                        decoration: const BoxDecoration(
                          color: verdeClaro,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: verde,
                          size: 45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Restablecer contraseña',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Crea una nueva contraseña para proteger tu cuenta de PetCare.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Nueva contraseña',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _campoPassword(
                      controller: _passwordController,
                      etiqueta: 'Ingresa tu contraseña',
                      mostrar: _mostrarPassword,
                      alternar: () {
                        setState(() {
                          _mostrarPassword = !_mostrarPassword;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Confirmar contraseña',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _campoPassword(
                      controller: _confirmarController,
                      etiqueta: 'Repite tu contraseña',
                      mostrar: _mostrarConfirmacion,
                      alternar: () {
                        setState(() {
                          _mostrarConfirmacion = !_mostrarConfirmacion;
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: verde, size: 17),
                        const SizedBox(width: 7),
                        Text(
                          'Mínimo 6 caracteres',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _actualizarPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verde,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: verde.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 23,
                                height: 23,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Guardar nueva contraseña',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'PetCare · Cuidamos a quienes te acompañan',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
