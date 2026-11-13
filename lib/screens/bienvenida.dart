
import 'package:flutter/material.dart';

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  static const Color verde = Color(0xFF17623F);
  static const Color verdeClaro = Color(0xFFE8F5ED);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 25),

                Container(
                  width: 145,
                  height: 145,
                  decoration: const BoxDecoration(
                    color: verdeClaro,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 85,
                    color: verde,
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'PetCare Santa Cruz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: verde,
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Cuidamos a quienes más quieres',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '¡Bienvenido!',
                        style: TextStyle(
                          color: verde,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Todo lo que necesitas para cuidar '
                        'la salud y el bienestar de tu mascota '
                        'está en un solo lugar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/app',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verde,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ver servicios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'El bienestar de tu mascota comienza aquí 🐾',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black45,
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
