import 'package:flutter/material.dart';

import '../models/servicio.dart';
import '../services/servicio_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, this.onSolicitarServicio, this.onOpenMenu});

  final Function(String)? onSolicitarServicio;
  final VoidCallback? onOpenMenu;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  static const Color fondo = Color(0xFFF7FAF6);

  final ServicioService _servicio = ServicioService();

  late Future<List<Servicio>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.obtenerServicios();
  }

  IconData obtenerIcono(String nombre) {
    final nombreLower = nombre.toLowerCase();

    if (nombreLower.contains('consulta')) {
      return Icons.medical_services_outlined;
    } else if (nombreLower.contains('vacun')) {
      return Icons.vaccines_outlined;
    } else if (nombreLower.contains('desparasit')) {
      return Icons.health_and_safety_outlined;
    } else if (nombreLower.contains('baño') ||
        nombreLower.contains('peluquer')) {
      return Icons.content_cut;
    } else if (nombreLower.contains('control')) {
      return Icons.monitor_heart_outlined;
    } else if (nombreLower.contains('laboratorio')) {
      return Icons.biotech_outlined;
    }

    return Icons.pets_outlined;
  }

  void reintentar() {
    setState(() {
      _futuro = _servicio.obtenerServicios();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenMenu,
              ),
        title: const Row(
          children: [
            Icon(Icons.pets, size: 25),
            SizedBox(width: 10),
            Text(
              'PetCare Santa Cruz',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: verde,
        onRefresh: () async {
          reintentar();
          await _futuro;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _encabezado(),
                  const SizedBox(height: 25),
                  _tituloSeccion(),
                  const SizedBox(height: 14),
                  FutureBuilder<List<Servicio>>(
                    future: _futuro,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(45),
                          child: Center(
                            child: CircularProgressIndicator(color: verde),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _estadoError();
                      }

                      final servicios = snapshot.data ?? [];

                      if (servicios.isEmpty) {
                        return _estadoVacio();
                      }

                      return Column(
                        children: servicios.map((servicio) {
                          return _tarjetaServicio(servicio);
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  _notaInformativa(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17623F), Color(0xFF248454)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: verde.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuidado y bienestar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Descubre nuestros servicios veterinarios '
                  'para mantener saludable a tu mascota.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tu mascota merece lo mejor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 43),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion() {
    return const Row(
      children: [
        Icon(Icons.medical_services_outlined, color: verde, size: 23),
        SizedBox(width: 9),
        Text(
          'Nuestros servicios',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Color(0xFF26352B),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaServicio(Servicio servicio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEE9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: verdeClaro,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    obtenerIcono(servicio.nombre),
                    color: verde,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servicio.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF26352B),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        servicio.descripcion?.trim().isNotEmpty == true
                            ? servicio.descripcion!
                            : 'Servicio veterinario para tu mascota.',
                        style: const TextStyle(
                          color: Color(0xFF78827A),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            const Divider(color: Color(0xFFEDF1ED), height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Precio del servicio',
                      style: TextStyle(color: Color(0xFF89928B), fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bs. ${servicio.precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: verde,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final supabase = Supabase.instance.client;
                      final usuario = supabase.auth.currentUser;

                      // No hay sesión: ir al Login.
                      if (usuario == null) {
                        Navigator.pushNamed(context, '/login');
                        return;
                      }

                      try {
                        final perfil = await supabase
                            .from('perfiles')
                            .select('rol')
                            .eq('id', usuario.id)
                            .maybeSingle();

                        if (!mounted) return;

                        final rol = perfil?['rol']?.toString();

                        // No tiene perfil o no es cliente.
                        if (rol != 'cliente') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Esta opción está disponible únicamente para clientes.',
                              ),
                            ),
                          );
                          return;
                        }

                        // Si viene del catálogo público, entrar al área del cliente.
                        if (widget.onSolicitarServicio == null) {
                          Navigator.pushReplacementNamed(context, '/app');
                          return;
                        }

                        // Si ya está en el área del cliente, continuar con la reserva.
                        widget.onSolicitarServicio!(servicio.nombre);
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo verificar tu perfil: $e'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Solicitar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _estadoError() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Colors.redAccent,
            size: 45,
          ),
          const SizedBox(height: 12),
          const Text(
            'No se pudieron cargar los servicios.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.medical_services_outlined, color: verde, size: 45),
          SizedBox(height: 12),
          Text(
            'No hay servicios disponibles.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 5),
          Text(
            'Vuelve a consultar más tarde.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _notaInformativa() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: verdeClaro,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: verde, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Los precios indicados son referenciales. '
              'El costo final puede variar según las '
              'necesidades de cada mascota.',
              style: TextStyle(
                color: Color(0xFF42634E),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
