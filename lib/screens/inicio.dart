import 'package:flutter/material.dart';

class InicioScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const InicioScreen({
    super.key,
    required this.onNavigate,
  });

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.pets),
            SizedBox(width: 10),
            Text('PetCare Santa Cruz'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuidamos a quienes más quieres',
              style: TextStyle(
                color: verde,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: verde,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Bienvenido a PetCare! 🐾',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La salud de tu mascota es nuestra prioridad. '
                    'Organiza sus cuidados, consulta nuestros servicios '
                    'y reserva una cita desde un solo lugar.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => onNavigate(2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: verde,
                    ),
                    child: const Text('Ver servicios'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Resumen general',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _estadistica(
                  'Mascotas',
                  '0',
                  Icons.pets,
                ),
                const SizedBox(width: 10),
                _estadistica(
                  'Citas',
                  '0',
                  Icons.calendar_month,
                ),
                const SizedBox(width: 10),
                _estadistica(
                  'Vacunas',
                  '0',
                  Icons.vaccines,
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Accesos rápidos',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),

            const SizedBox(height: 12),

            _acceso(
              'Registrar mascota',
              'Agrega una nueva mascota',
              Icons.add_circle_outline,
              () => onNavigate(1),
            ),

            _acceso(
              'Agendar consulta',
              'Reserva una atención veterinaria',
              Icons.calendar_month,
              () => onNavigate(3),
            ),

            _acceso(
              'Control de vacunas',
              'Registra las vacunas aplicadas',
              Icons.vaccines,
              () => onNavigate(4),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximas citas',
                    style: TextStyle(
                      color: verde,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Todavía no tienes citas registradas.',
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

  Widget _estadistica(String titulo, String cantidad, IconData icono) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icono, color: verde, size: 25),
            const SizedBox(height: 8),
            Text(
              cantidad,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _acceso(
    String titulo,
    String descripcion,
    IconData icono,
    VoidCallback accion,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: verdeClaro,
          child: Icon(icono, color: verde),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(descripcion),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: accion,
      ),
    );
  }
}