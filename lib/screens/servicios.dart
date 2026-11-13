
import 'package:flutter/material.dart';
import '../models/servicio.dart';
import '../services/servicio_service.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({
    super.key,
    required this.onSolicitarServicio,
  });

  final Function(String) onSolicitarServicio;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  final ServicioService _servicio = ServicioService();

  late Future<List<Servicio>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.obtenerServicios();
  }

  // Asignar un icono dependiendo del nombre del servicio.
  IconData obtenerIcono(String nombre) {
    final nombreLower = nombre.toLowerCase();

    if (nombreLower.contains('consulta')) {
      return Icons.medical_services;
    } else if (nombreLower.contains('vacun')) {
      return Icons.vaccines;
    } else if (nombreLower.contains('desparasit')) {
      return Icons.health_and_safety;
    } else if (nombreLower.contains('baño') ||
        nombreLower.contains('peluquer')) {
      return Icons.content_cut;
    } else if (nombreLower.contains('control')) {
      return Icons.monitor_heart;
    } else if (nombreLower.contains('laboratorio')) {
      return Icons.biotech;
    }

    return Icons.pets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Text(
          'Servicios veterinarios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.pets,
                  size: 65,
                  color: verde,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nuestros servicios',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuidamos la salud y bienestar de tu mascota.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 25),

                // Cargar servicios desde Supabase.
                FutureBuilder<List<Servicio>>(
                  future: _futuro,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: verde,
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 45,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No se pudieron cargar los servicios.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _futuro =
                                    _servicio.obtenerServicios();
                              });
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      );
                    }

                    final servicios = snapshot.data ?? [];

                    if (servicios.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay servicios disponibles.',
                        ),
                      );
                    }

                    return Column(
                      children: servicios.map((servicio) {
                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: verdeClaro,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        obtenerIcono(servicio.nombre),
                                        color: verde,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            servicio.nombre,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            servicio.descripcion ?? '',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Bs. ${servicio.precio.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: verde,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      widget.onSolicitarServicio(
                                        servicio.nombre,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.calendar_month,
                                    ),
                                    label: const Text(
                                      'Solicitar servicio',
                                    ),
                                    style:
                                        ElevatedButton.styleFrom(
                                      backgroundColor: verde,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 10),
                const Text(
                  '* Los precios indicados son referenciales. '
                  'Los servicios pueden variar según las '
                  'necesidades de cada mascota.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
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
