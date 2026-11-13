
import 'package:flutter/material.dart';

class TiendaScreen extends StatelessWidget {
  const TiendaScreen({super.key});

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      appBar: AppBar(
        title: const Text('Tienda'),
        backgroundColor: verde,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Todo para tu mascota 🐾',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Descubre productos para cuidar y consentir a tus mascotas.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                prefixIcon: const Icon(Icons.search, color: verde),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Nuestros productos',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),

            const SizedBox(height: 15),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.77,
              children: const [
                _Producto(
                  icono: Icons.pets,
                  nombre: 'Alimento para perros',
                  precio: 'Bs. 85',
                  categoria: 'Alimentación',
                  color: Color(0xFFE8F5ED),
                ),
                _Producto(
                  icono: Icons.ramen_dining,
                  nombre: 'Alimento para gatos',
                  precio: 'Bs. 65',
                  categoria: 'Alimentación',
                  color: Color(0xFFFFF0D9),
                ),
                _Producto(
                  icono: Icons.toys,
                  nombre: 'Juguetes para mascotas',
                  precio: 'Bs. 35',
                  categoria: 'Accesorios',
                  color: Color(0xFFE8EDFF),
                ),
                _Producto(
                  icono: Icons.cleaning_services,
                  nombre: 'Productos de higiene',
                  precio: 'Bs. 45',
                  categoria: 'Higiene',
                  color: Color(0xFFFCE8ED),
                ),
                _Producto(
                  icono: Icons.bed,
                  nombre: 'Cama para mascotas',
                  precio: 'Bs. 120',
                  categoria: 'Accesorios',
                  color: Color(0xFFE8F5ED),
                ),
                _Producto(
                  icono: Icons.pets_outlined,
                  nombre: 'Collares y correas',
                  precio: 'Bs. 40',
                  categoria: 'Accesorios',
                  color: Color(0xFFFFF0D9),
                ),
              ],
            ),

            const SizedBox(height: 15),

            const Center(
              child: Text(
                'Precios referenciales. Consulta disponibilidad.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Producto extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String precio;
  final String categoria;
  final Color color;

  const _Producto({
    required this.icono,
    required this.nombre,
    required this.precio,
    required this.categoria,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icono,
                  size: 55,
                  color: const Color(0xFF17623F),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              categoria,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              precio,
              style: const TextStyle(
                color: Color(0xFF17623F),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
