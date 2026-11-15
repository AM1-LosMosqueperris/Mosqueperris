import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color fondo = Color(0xFFF7FAF6);

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  bool _esRegistro = false;
  bool _mostrarPassword = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _autenticar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_esRegistro) {
        final respuesta = await supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'petcare://confirm-email',
          data: {'full_name': _nombreController.text.trim()},
        );

        if (!mounted) return;

        if (respuesta.session == null) {
          _mensaje(
            'Registro realizado. Revisa tu correo y confirma tu cuenta.',
          );
        } else {
          _entrar();
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (!mounted) return;
        _entrar();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _mensaje(e.message);
    } catch (e) {
      debugPrint('ERROR DE AUTENTICACIÓN: $e');

      if (!mounted) return;
      _mensaje('Ocurrió un error. Comprueba tu conexión.');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _entrar() {
    Navigator.pushNamedAndRemoveUntil(context, '/app', (route) => false);
  }

  Future<void> _recuperarPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _mensaje('Primero ingresa un correo electrónico válido.');
      return;
    }

    setState(() => _cargando = true);

    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'petcare://reset-password',
      );

      if (!mounted) return;

      _mensaje(
        'Si el correo está registrado, recibirás instrucciones '
        'para recuperar tu contraseña.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _mensaje(e.message);
    } catch (e) {
      if (!mounted) return;
      _mensaje('No se pudo enviar el correo. Comprueba tu conexión.');
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

  void _cambiarModo() {
    setState(() {
      _esRegistro = !_esRegistro;
      _mostrarPassword = false;
      _formKey.currentState?.reset();
    });
  }

  InputDecoration _decoracionCampo({
    required String etiqueta,
    required IconData icono,
    Widget? sufijo,
  }) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
      prefixIcon: Icon(icono, color: verde, size: 21),
      suffixIcon: sufijo,
      filled: true,
      fillColor: fondo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE5ECE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: verde, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 30, 25, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [verde, Color(0xFF258456)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.white,
              size: 47,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'PetCare Santa Cruz',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Cuidamos de quienes llenan tu vida de alegría',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFEDF1ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _esRegistro ? 'Crear una cuenta' : '¡Bienvenido de nuevo!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF26372C),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              _esRegistro
                  ? 'Regístrate para disfrutar de nuestros servicios.'
                  : 'Ingresa tus datos para continuar.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 27),

            if (_esRegistro) ...[
              const Text(
                'Nombre completo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37483C),
                ),
              ),
              const SizedBox(height: 9),

              TextFormField(
                controller: _nombreController,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _decoracionCampo(
                  etiqueta: 'Ej. Juan Pérez',
                  icono: Icons.person_outline_rounded,
                ),
                validator: (value) {
                  if (_esRegistro && (value == null || value.trim().isEmpty)) {
                    return 'Ingresa tu nombre completo';
                  }

                  if (_esRegistro && value!.trim().length < 3) {
                    return 'Ingresa un nombre válido';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),
            ],

            const Text(
              'Correo electrónico',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37483C),
              ),
            ),
            const SizedBox(height: 9),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              decoration: _decoracionCampo(
                etiqueta: 'ejemplo@correo.com',
                icono: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu correo electrónico';
                }

                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(value.trim())) {
                  return 'Ingresa un correo válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            const Text(
              'Contraseña',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37483C),
              ),
            ),
            const SizedBox(height: 9),

            TextFormField(
              controller: _passwordController,
              obscureText: !_mostrarPassword,
              textInputAction: TextInputAction.done,
              autofillHints: _esRegistro
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_cargando) _autenticar();
              },
              decoration: _decoracionCampo(
                etiqueta: 'Ingresa tu contraseña',
                icono: Icons.lock_outline_rounded,
                sufijo: IconButton(
                  onPressed: () {
                    setState(() {
                      _mostrarPassword = !_mostrarPassword;
                    });
                  },
                  icon: Icon(
                    _mostrarPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.black45,
                  ),
                  tooltip: _mostrarPassword
                      ? 'Ocultar contraseña'
                      : 'Mostrar contraseña',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña';
                }

                if (value.length < 6) {
                  return 'Mínimo 6 caracteres';
                }

                return null;
              },
            ),

            if (!_esRegistro) ...[
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _cargando ? null : _recuperarPassword,
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 25),

            const SizedBox(height: 12),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _cargando ? null : _autenticar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: verde.withValues(alpha: 0.6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _esRegistro
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _esRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 19),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _esRegistro
                        ? '¿Ya tienes una cuenta?'
                        : '¿No tienes una cuenta?',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _cargando ? null : _cambiarModo,
                  child: Text(
                    _esRegistro ? 'Inicia sesión' : 'Regístrate',
                    style: const TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    _encabezado(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: _formulario(),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        'PETCARE SANTA CRUZ  •  CUIDADO Y BIENESTAR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
