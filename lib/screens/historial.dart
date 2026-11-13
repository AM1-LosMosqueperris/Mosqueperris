
import 'package:flutter/material.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historial de atención',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta las actividades y cuidados registrados para tus mascotas.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 22),

            _filtro(),

            const SizedBox(height: 20),

            _elementoHistorial(
              icono: Icons.calendar_month,
              titulo: 'Citas veterinarias',
              descripcion: 'Aquí aparecerán las citas realizadas.',
              color: Colors.blue,
            ),

            _elementoHistorial(
              icono: Icons.vaccines,
              titulo: 'Vacunaciones',
              descripcion: 'Aquí aparecerán las vacunas registradas.',
              color: verde,
            ),

            _elementoHistorial(
              icono: Icons.medical_services,
              titulo: 'Otros cuidados',
              descripcion: 'Aquí aparecerán otros servicios recibidos.',
              color: Colors.orange,
            ),

            const SizedBox(height: 15),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                children: [
                  Icon(Icons.history, size: 38, color: verde),
                  SizedBox(height: 10),
                  Text(
                    'Todavía no hay registros',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: verde,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Cuando registres citas o vacunas, '
                    'podrás consultar aquí su historial.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtro() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: 'Todos',
        decoration: const InputDecoration(
          labelText: 'Filtrar historial',
          border: InputBorder.none,
        ),
        items: const [
          DropdownMenuItem(value: 'Todos', child: Text('Todos')),
          DropdownMenuItem(value: 'Citas', child: Text('Citas')),
          DropdownMenuItem(value: 'Vacunas', child: Text('Vacunas')),
          DropdownMenuItem(value: 'Otros', child: Text('Otros cuidados')),
        ],
        onChanged: (value) {},
      ),
    );
  }

  Widget _elementoHistorial({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icono, color: color),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
