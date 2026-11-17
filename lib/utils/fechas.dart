/// Utilidades centralizadas de formato de fechas y horas de PetCare Santa Cruz.
///
/// **Contexto de negocio:** la clínica opera en Santa Cruz de la Sierra, Bolivia
/// (zona IANA `America/La_Paz`, UTC-4, sin horario de verano desde 2010).
///
/// **Por qué existe:** antes de esta clase cada pantalla implementaba su propio
/// formateo de `fecha` (`date`) y `hora` (`time WITHOUT TIME ZONE`), lo que produjo
/// cuatro formatos distintos para el mismo dato y dos puntos donde un valor
/// inválido tumbaba una lista completa.
///
/// **Nota sobre zonas horarias:** la columna `reservas.hora` es `time WITHOUT TIME
/// ZONE`, es decir, guarda el **reloj de pared local** que el cliente eligió.
/// Por eso todos los métodos de esta clase devuelven fechas en hora local del
/// dispositivo y nunca aplican `toUtc()`: hacerlo desplazaría la cita 4 horas.
library;

class Fechas {
  const Fechas._();

  /// Zona horaria IANA del negocio (Santa Cruz de la Sierra, Bolivia).
  static const String zonaNegocio = 'America/La_Paz';

  /// Convierte la fecha civil de la base de datos (`YYYY-MM-DD`) en un
  /// [DateTime] local.
  ///
  /// Devuelve `null` en lugar de lanzar cuando el valor es nulo o tiene un
  /// formato inesperado, de modo que una fila corrupta no impida cargar el
  /// resto de la lista.
  static DateTime? tryParseFecha(dynamic valor) {
    if (valor == null) return null;

    if (valor is DateTime) return valor;

    final texto = valor.toString().trim();

    if (texto.isEmpty) return null;

    final partes = texto.split('-');

    if (partes.length == 3) {
      final anio = int.tryParse(partes[0]);
      final mes = int.tryParse(partes[1]);
      final dia = int.tryParse(partes[2]);

      if (anio != null &&
          mes != null &&
          dia != null &&
          mes >= 1 &&
          mes <= 12 &&
          dia >= 1 &&
          dia <= 31) {
        return DateTime(anio, mes, dia);
      }
    }

    return DateTime.tryParse(texto);
  }

  /// Convierte la hora de la base de datos (`HH:MM:SS`) en `HH:MM`.
  static String formatearHora(dynamic valor) {
    if (valor == null) return '';

    final texto = valor.toString().trim();

    if (texto.length < 5) return texto;

    return texto.substring(0, 5);
  }

  /// Formatea una fecha como `dd/MM/yyyy`.
  static String formatearFecha(dynamic valor) {
    final fecha = tryParseFecha(valor);

    if (fecha == null) return '';

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year}';
  }

  /// Formatea fecha y hora juntas como `dd/MM/yyyy · HH:MM`.
  static String formatearFechaHora(dynamic fecha, dynamic hora) {
    final fechaTexto = formatearFecha(fecha);
    final horaTexto = formatearHora(hora);

    if (fechaTexto.isEmpty) return horaTexto;
    if (horaTexto.isEmpty) return fechaTexto;

    return '$fechaTexto · $horaTexto';
  }

  /// Compone la fecha civil y la hora de la base de datos en un único
  /// [DateTime] **local**, equivalente a `DateTime.parse('$fechaT$hora')` pero
  /// sin lanzar excepciones ante valores inesperados.
  static DateTime? tryParseFechaHora(dynamic fecha, dynamic hora) {
    final base = tryParseFecha(fecha);

    if (base == null) return null;

    final texto = hora?.toString().trim() ?? '';

    if (texto.isEmpty) return base;

    final partes = texto.split(':');
    final h = int.tryParse(partes[0]);

    if (h == null || h < 0 || h > 23) return base;

    final m = partes.length > 1 ? (int.tryParse(partes[1]) ?? 0) : 0;

    return DateTime(base.year, base.month, base.day, h, m);
  }
}
