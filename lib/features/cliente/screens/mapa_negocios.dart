import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MapaNegociosScreen extends StatefulWidget {
  const MapaNegociosScreen({super.key});

  @override
  State<MapaNegociosScreen> createState() => _MapaNegociosScreenState();
}

class _MapaNegociosScreenState extends State<MapaNegociosScreen> {
  static const Color verde = Color(0xFF17623F);

  late Future<List<Map<String, dynamic>>> _negociosFuture;

  Map<String, dynamic>? _negocioSeleccionado;

  @override
  void initState() {
    super.initState();
    _negociosFuture = _cargarNegocios();
  }

  Future<List<Map<String, dynamic>>> _cargarNegocios() async {
    final respuesta = await Supabase.instance.client
        .from('negocios')
        .select(
          'id, nombre, descripcion, direccion, telefono, latitud, longitud',
        )
        .eq('activo', true)
        .order('nombre');

    return List<Map<String, dynamic>>.from(respuesta);
  }

  Future<void> _abrirWhatsApp(Map<String, dynamic> negocio) async {
    final telefono = negocio['telefono']?.toString() ?? '';

    if (telefono.isEmpty) return;

    final numero = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final mensaje = Uri.encodeComponent(
      'Hola, estoy interesado en los servicios de ${negocio['nombre']}.',
    );

    final uri = Uri.parse('https://wa.me/$numero?text=$mensaje');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _llamarNegocio(Map<String, dynamic> negocio) async {
    final telefono = negocio['telefono']?.toString() ?? '';

    if (telefono.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: telefono);

    if (!await launchUrl(uri)) {
      debugPrint('No se pudo abrir el marcador telefónico');
    }
  }

  Future<void> _comoLlegar(Map<String, dynamic> negocio) async {
    final latitud = negocio['latitud'];
    final longitud = negocio['longitud'];

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitud,$longitud',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir Google Maps');
    }
  }

  void _reintentar() {
    setState(() {
      _negocioSeleccionado = null;
      _negociosFuture = _cargarNegocios();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de veterinarias'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _negociosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: verde));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 55, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar las veterinarias.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _reintentar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final negocios = snapshot.data ?? [];

          if (negocios.isEmpty) {
            return const Center(
              child: Text('No hay establecimientos registrados.'),
            );
          }

          final marcadores = negocios.map((negocio) {
            final latitud = (negocio['latitud'] as num).toDouble();
            final longitud = (negocio['longitud'] as num).toDouble();

            return Marker(
              point: LatLng(latitud, longitud),
              width: 50,
              height: 55,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _negocioSeleccionado = negocio;
                  });
                },
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 43,
                ),
              ),
            );
          }).toList();

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(-17.7833, -63.1821),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.petcare_santa_cruz',
                    ),
                    MarkerLayer(markers: marcadores),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),

              if (_negocioSeleccionado != null)
                _construirDetalle(_negocioSeleccionado!),
            ],
          );
        },
      ),
    );
  }

  Widget _construirDetalle(Map<String, dynamic> negocio) {
    final telefono = negocio['telefono'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital, color: verde),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  negocio['nombre']?.toString() ?? 'Veterinaria',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _negocioSeleccionado = null;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (negocio['descripcion'] != null)
            Text(negocio['descripcion'].toString()),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  negocio['direccion']?.toString() ?? 'Sin dirección',
                ),
              ),
            ],
          ),
          if (telefono != null && telefono.isNotEmpty)
            Text('Teléfono: $telefono'),

          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: telefono != null && telefono.isNotEmpty
                    ? () => _abrirWhatsApp(negocio)
                    : null,
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: telefono != null && telefono.isNotEmpty
                    ? () => _llamarNegocio(negocio)
                    : null,
                icon: const Icon(Icons.call),
                label: const Text('Llamar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _comoLlegar(negocio),
                icon: const Icon(Icons.directions),
                label: const Text('Cómo llegar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
