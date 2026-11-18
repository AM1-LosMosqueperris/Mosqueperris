import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactoScreen extends StatelessWidget {
  final VoidCallback? onOpenMenu;

  const ContactoScreen({super.key, this.onOpenMenu});

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);
  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('No se pudo abrir: $url');
    }
  }

  Future<void> _abrirMapa() async {
    await _abrirEnlace('https://maps.app.goo.gl/jwGQBucKy2rHhfDG8');
  }

  Future<void> _llamar() async {
    await _abrirEnlace('tel:+59167731820');
  }

  Future<void> _whatsapp() async {
    await _abrirEnlace(
      'https://wa.me/59167731820?text=Hola%20PetCare%20Santa%20Cruz',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        leading: onOpenMenu == null
            ? null
            : IconButton(
                tooltip: 'Abrir menú',
                icon: const Icon(Icons.menu),
                onPressed: onOpenMenu,
              ),
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
                    child: Icon(Icons.pets, color: verde, size: 45),
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
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
              'Universidad Privada Domingo Savio (UPDS), Santa Cruz de la Sierra',
            ),

            _informacion(Icons.phone_outlined, 'Teléfono', '+591 67731820'),

            _informacion(
              Icons.access_time,
              'Horario de atención',
              'Lunes a sábado\n08:00 a 18:00',
            ),

            _informacion(
              Icons.email_outlined,
              'Correo electrónico',
              'leoncarballo354@gmail.com',
            ),
            const Text(
              'Contáctanos',
              style: TextStyle(
                color: verde,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _llamar,
                icon: const Icon(Icons.phone),
                label: const Text('Llamar a PetCare'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _whatsapp,
                icon: const Icon(Icons.chat),
                label: const Text('Contactar por WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _abrirMapa,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver ubicación en Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: verde,
                  padding: const EdgeInsets.all(15),
                ),
              ),
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
                    style: TextStyle(color: Colors.black87, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'PetCare Santa Cruz © 2026',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _informacion(IconData icono, String titulo, String descripcion) {
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
