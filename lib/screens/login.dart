import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _esRegistro = false;
  bool _mostrarPassword = false;
  bool _cargando = false;

  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void dispose() {
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
        title: const Text('Cuenta PetCare'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: verdeClaro,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets, size: 60, color: verde),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'PetCare Santa Cruz',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _esRegistro
                        ? 'Crea tu cuenta para comenzar'
                        : 'Ingresa a tu cuenta',
                    style: const TextStyle(color: Colors.black54, fontSize: 15),
                  ),
                  const SizedBox(height: 30),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_mostrarPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
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

                  const SizedBox(height: 25),

                  if (!_esRegistro) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cargando ? null : _recuperarPassword,
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: verde,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 53,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _autenticar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _cargando
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _esRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () {
                            setState(() {
                              _esRegistro = !_esRegistro;
                              _formKey.currentState?.reset();
                            });
                          },
                    child: Text(
                      _esRegistro
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                      style: const TextStyle(
                        color: verde,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
