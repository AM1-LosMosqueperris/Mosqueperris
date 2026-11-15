import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key});

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen> {
  static const Color verde = Color(0xFF17623F);
  final supabase = Supabase.instance.client;

  bool cargando = true;
  String? error;

  int totalUsuarios = 0;
  int totalAtenciones = 0;

  List<Map<String, dynamic>> mascotasPorEspecie = [];
  List<Map<String, dynamic>> reservasPorEstado = [];
  List<Map<String, dynamic>> serviciosSolicitados = [];

  final List<Color> colores = [
    const Color(0xFF17623F),
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.red,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    cargarReportes();
  }

  Future<void> cargarReportes() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final respuesta = await supabase.rpc('obtener_reportes_admin');

      final datos = Map<String, dynamic>.from(respuesta as Map);

      if (!mounted) return;

      setState(() {
        totalUsuarios = (datos['total_usuarios'] as num?)?.toInt() ?? 0;

        totalAtenciones = (datos['total_atenciones'] as num?)?.toInt() ?? 0;

        mascotasPorEspecie = convertirLista(datos['mascotas_por_especie']);

        reservasPorEstado = convertirLista(datos['reservas_por_estado']);

        serviciosSolicitados = convertirLista(datos['servicios_solicitados']);

        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR AL CARGAR REPORTES: $e');

      if (!mounted) return;

      setState(() {
        error = 'No se pudieron cargar los reportes.';
        cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> convertirLista(dynamic datos) {
    if (datos == null) return [];

    return (datos as List)
        .map((elemento) => Map<String, dynamic>.from(elemento as Map))
        .toList();
  }

  int cantidad(dynamic valor) {
    return (valor as num?)?.toInt() ?? 0;
  }

  int get totalMascotas => mascotasPorEspecie.fold(
    0,
    (total, elemento) => total + cantidad(elemento['cantidad']),
  );

  int get totalReservas => reservasPorEstado.fold(
    0,
    (total, elemento) => total + cantidad(elemento['cantidad']),
  );

  Widget tarjetaResumen(String titulo, int valor, IconData icono, Color color) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              valor.toString(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              titulo,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget tituloSeccion(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, color: verde),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tarjetaGrafico({
    required String titulo,
    required IconData icono,
    required Widget contenido,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [tituloSeccion(titulo, icono), contenido],
        ),
      ),
    );
  }

  Widget graficoCircular(List<Map<String, dynamic>> datos, String campoNombre) {
    if (datos.isEmpty || totalDe(datos) == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No hay datos disponibles.'),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            size: const Size(190, 190),
            painter: GraficoCircularPainter(
              valores: datos.map((e) => cantidad(e['cantidad'])).toList(),
              colores: colores,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...datos.asMap().entries.map((entrada) {
          final elemento = entrada.value;
          final color = colores[entrada.key % colores.length];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    elemento[campoNombre]?.toString() ?? 'Sin especificar',
                  ),
                ),
                Text(
                  '${cantidad(elemento['cantidad'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  int totalDe(List<Map<String, dynamic>> datos) {
    return datos.fold(
      0,
      (total, elemento) => total + cantidad(elemento['cantidad']),
    );
  }

  Widget graficoBarras() {
    if (serviciosSolicitados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('No hay servicios registrados.')),
      );
    }

    final maximo = serviciosSolicitados.fold<int>(0, (mayor, elemento) {
      final valor = cantidad(elemento['cantidad']);
      return valor > mayor ? valor : mayor;
    });

    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: serviciosSolicitados.asMap().entries.map((entrada) {
          final elemento = entrada.value;
          final valor = cantidad(elemento['cantidad']);
          final altura = maximo == 0 ? 0.0 : (valor / maximo) * 125.0;
          final color = colores[entrada.key % colores.length];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$valor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: altura,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 65,
                    child: Text(
                      elemento['servicio']?.toString() ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'Reportes y estadísticas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: verde,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: cargarReportes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar reportes',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 45,
                    ),
                    const SizedBox(height: 12),
                    Text(error!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: cargarReportes,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: cargarReportes,
              color: verde,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: verde,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.analytics, color: Colors.white, size: 42),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Resumen general de PetCare',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Indicadores generales',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      tarjetaResumen(
                        'Usuarios',
                        totalUsuarios,
                        Icons.people,
                        Colors.blue,
                      ),
                      tarjetaResumen(
                        'Mascotas',
                        totalMascotas,
                        Icons.pets,
                        Colors.teal,
                      ),
                      tarjetaResumen(
                        'Reservas',
                        totalReservas,
                        Icons.calendar_month,
                        Colors.orange,
                      ),
                      tarjetaResumen(
                        'Atenciones médicas',
                        totalAtenciones,
                        Icons.medical_services,
                        Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  tarjetaGrafico(
                    titulo: 'Mascotas por especie',
                    icono: Icons.pets,
                    contenido: graficoCircular(mascotasPorEspecie, 'especie'),
                  ),

                  tarjetaGrafico(
                    titulo: 'Reservas por estado',
                    icono: Icons.calendar_month,
                    contenido: graficoCircular(reservasPorEstado, 'estado'),
                  ),

                  tarjetaGrafico(
                    titulo: 'Servicios más solicitados',
                    icono: Icons.medical_services,
                    contenido: graficoBarras(),
                  ),

                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Datos actualizados desde Supabase',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class GraficoCircularPainter extends CustomPainter {
  final List<int> valores;
  final List<Color> colores;

  GraficoCircularPainter({required this.valores, required this.colores});

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<int>(0, (a, b) => a + b);

    if (total == 0) return;

    final centro = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2 - 8;

    final rect = Rect.fromCircle(center: centro, radius: radio);

    double inicio = -math.pi / 2;

    for (int i = 0; i < valores.length; i++) {
      final barrido = (valores[i] / total) * 2 * math.pi;

      final pintura = Paint()
        ..color = colores[i % colores.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, inicio, barrido, true, pintura);

      inicio += barrido;
    }

    final pinturaCentro = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(centro, radio * 0.55, pinturaCentro);

    final texto = TextPainter(
      text: TextSpan(
        text: '$total',
        style: const TextStyle(
          color: Color(0xFF17623F),
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    texto.layout();

    texto.paint(
      canvas,
      Offset(centro.dx - texto.width / 2, centro.dy - texto.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GraficoCircularPainter oldDelegate) {
    return oldDelegate.valores != valores || oldDelegate.colores != colores;
  }
}
