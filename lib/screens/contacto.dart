
import 'package:flutter/material.dart';

class ContactoScreen extends StatelessWidget {
  const ContactoScreen({super.key});

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Contacto'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: verde,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.pets,
                      color: verde,
                      size: 45,
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'PetCare Santa Cruz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Cuidamos a quienes más quieres',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Información de contacto',
              style: TextStyle(
                color: verde,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            _informacion(
              Icons.location_on_outlined,
              'Ubicación',
              'Santa Cruz de la Sierra, Bolivia',
            ),

            _informacion(
              Icons.phone_outlined,
              'Teléfono',
              'Número de contacto por confirmar',
            ),

            _informacion(
              Icons.access_time,
              'Horario de atención',
              'Lunes a sábado\n08:00 a 18:00',
            ),

            _informacion(
              Icons.email_outlined,
              'Correo electrónico',
              'Información por confirmar',
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Necesitas ayuda?',
                    style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Estamos aquí para ayudarte con el cuidado '
                    'y bienestar de tu mascota. Consulta nuestros '
                    'servicios o solicita una cita veterinaria.',
                    style: TextStyle(
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'PetCare Santa Cruz © 2026',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _informacion(
    IconData icono,
    String titulo,
    String descripcion,
  ) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
    );
  }
}
