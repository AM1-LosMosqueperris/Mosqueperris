import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClimaScreen extends StatefulWidget {
  const ClimaScreen({super.key});

  @override
  State<ClimaScreen> createState() => _ClimaScreenState();
}

class _ClimaScreenState extends State<ClimaScreen> {
  Map<String, dynamic>? clima;
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarClima();
  }

  Future<void> cargarClima() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=-17.7833'
        '&longitude=-63.1821'
        '&current=temperature_2m,relative_humidity_2m,'
        'apparent_temperature,is_day,precipitation,weather_code,'
        'wind_speed_10m'
        '&timezone=America%2FLa_Paz',
      );

      final respuesta = await http.get(url);

      if (respuesta.statusCode != 200) {
        throw Exception('No se pudo obtener el clima.');
      }

      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      setState(() {
        clima = datos['current'];
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'No se pudo cargar el clima. Verifica tu conexión.';
        cargando = false;
      });
    }
  }

  String descripcionClima(int codigo) {
    if (codigo == 0) return 'Despejado';
    if ([1, 2, 3].contains(codigo)) return 'Parcialmente nublado';
    if ([45, 48].contains(codigo)) return 'Niebla';
    if ([51, 53, 55, 56, 57].contains(codigo)) return 'Llovizna';
    if ([61, 63, 65, 66, 67].contains(codigo)) return 'Lluvia';
    if ([71, 73, 75, 77].contains(codigo)) return 'Nevada';
    if ([80, 81, 82].contains(codigo)) return 'Chubascos';
    if ([85, 86].contains(codigo)) return 'Nieve intensa';
    if ([95, 96, 99].contains(codigo)) return 'Tormenta';
    return 'Condición desconocida';
  }

  IconData iconoClima(int codigo) {
    if (codigo == 0) return Icons.wb_sunny;
    if ([1, 2, 3, 45, 48].contains(codigo)) {
      return Icons.cloud;
    }
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(codigo)) {
      return Icons.water_drop;
    }
    if ([95, 96, 99].contains(codigo)) {
      return Icons.thunderstorm;
    }
    if ([71, 73, 75, 77, 85, 86].contains(codigo)) {
      return Icons.ac_unit;
    }
    return Icons.cloud_queue;
  }

  Widget datoClima(IconData icono, String titulo, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icono, size: 30, color: Colors.teal),
            const SizedBox(height: 8),
            Text(titulo, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clima en PetCare'),
        actions: [
          IconButton(
            onPressed: cargarClima,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar clima',
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 60),
                  const SizedBox(height: 12),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: cargarClima,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : clima == null
          ? const Center(child: Text('No hay datos disponibles'))
          : _construirContenido(),
    );
  }

  Widget _construirContenido() {
    final codigo = clima!['weather_code'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Santa Cruz de la Sierra',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Icon(iconoClima(codigo), size: 90, color: Colors.orange),
          const SizedBox(height: 12),
          Text(
            '${clima!['temperature_2m']} °C',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
          ),
          Text(descripcionClima(codigo), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              datoClima(
                Icons.thermostat,
                'Sensación térmica',
                '${clima!['apparent_temperature']} °C',
              ),
              datoClima(
                Icons.water_drop,
                'Humedad',
                '${clima!['relative_humidity_2m']} %',
              ),
              datoClima(
                Icons.air,
                'Viento',
                '${clima!['wind_speed_10m']} km/h',
              ),
              datoClima(
                Icons.umbrella,
                'Precipitación',
                '${clima!['precipitation']} mm',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Datos meteorológicos proporcionados por Open-Meteo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
