
import 'package:flutter/material.dart';

class ControlVacunasScreen extends StatefulWidget {
  const ControlVacunasScreen({super.key});

  @override
  State<ControlVacunasScreen> createState() =>
      _ControlVacunasScreenState();
}

class _ControlVacunasScreenState extends State<ControlVacunasScreen> {
  final mascotaController = TextEditingController();
  final vacunaController = TextEditingController();

  DateTime? fechaAplicada;
  DateTime? proximaFecha;

  final List<Map<String, String>> vacunas = [];

  String formatoFecha(DateTime? fecha) {
    if (fecha == null) return 'Seleccionar fecha';

    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  Future<void> seleccionarFecha(bool esProxima) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() {
        if (esProxima) {
          proximaFecha = fecha;
        } else {
          fechaAplicada = fecha;
        }
      });
    }
  }

  void guardarVacuna() {
    if (mascotaController.text.trim().isEmpty ||
        vacunaController.text.trim().isEmpty ||
        fechaAplicada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa los campos obligatorios'),
        ),
      );
      return;
    }

    setState(() {
      vacunas.add({
        'mascota': mascotaController.text.trim(),
        'vacuna': vacunaController.text.trim(),
        'fecha': formatoFecha(fechaAplicada),
        'proxima': proximaFecha == null
            ? ''
            : formatoFecha(proximaFecha),
      });
    });

    mascotaController.clear();
    vacunaController.clear();

    setState(() {
      fechaAplicada = null;
      proximaFecha = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vacuna registrada correctamente'),
      ),
    );
  }

  void eliminarVacuna(int index) {
    setState(() {
      vacunas.removeAt(index);
    });
  }

  @override
  void dispose() {
    mascotaController.dispose();
    vacunaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de vacunas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Control de vacunas 💉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registra las vacunas y las próximas fechas '
              'recomendadas para tu mascota.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar vacuna',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: mascotaController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la mascota',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: vacunaController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la vacuna',
                        hintText: 'Ej. Antirrábica',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Fecha aplicada'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => seleccionarFecha(false),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(formatoFecha(fechaAplicada)),
                    ),
                    const SizedBox(height: 12),

                    const Text('Próxima fecha (opcional)'),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => seleccionarFecha(true),
                      icon: const Icon(Icons.event),
                      label: Text(formatoFecha(proximaFecha)),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: guardarVacuna,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar vacuna'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Registro de vacunación',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            if (vacunas.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.vaccines,
                          size: 45,
                          color: Colors.green,
                        ),
                        SizedBox(height: 10),
                        Text('Aún no hay vacunas registradas'),
                      ],
                    ),
                  ),
                ),
              ),

            ...vacunas.asMap().entries.map((entry) {
              final index = entry.key;
              final vacuna = entry.value;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.vaccines),
                  ),
                  title: Text(
                    '${vacuna['vacuna']} · ${vacuna['mascota']}',
                  ),
                  subtitle: Text(
                    'Aplicada: ${vacuna['fecha']}\n'
                    '${vacuna['proxima']!.isEmpty ? 'Sin próxima fecha' : 'Próxima: ${vacuna['proxima']}'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => eliminarVacuna(index),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
