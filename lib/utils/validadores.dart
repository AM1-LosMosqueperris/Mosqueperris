class Validadores {
  static String? nombre(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese su nombre';
    }
    return null;
  }

  static String? telefono(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese su teléfono';
    }

    if (!RegExp(r'^[67][0-9]{7}$').hasMatch(valor.trim())) {
      return 'Debe tener 8 dígitos y comenzar con 6 o 7';
    }

    return null;
  }

  static String? mensaje(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese un mensaje';
    }

    if (valor.trim().length < 10) {
      return 'El mensaje debe tener al menos 10 caracteres';
    }

    return null;
  }
}