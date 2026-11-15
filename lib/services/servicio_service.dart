import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare_santa_cruz/models/servicio.dart';

class ServicioService {
  final db = Supabase.instance.client;

  Future<List<Servicio>> obtenerServicios() async {
    final filas = await db
    .from('servicios')
    .select()
    .eq('activo', true);

    return filas
        .map<Servicio>((f) => Servicio.fromMap(f))
        .toList();
  }
}