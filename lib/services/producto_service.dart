import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto.dart';

class ProductoService {
  final db = Supabase.instance.client;

  Future<List<Producto>> obtenerProductos() async {
    final filas = await db
        .from('productos')
        .select()
        .eq('activo', true);

    return filas
        .map<Producto>((f) => Producto.fromMap(f))
        .toList();
  }
}