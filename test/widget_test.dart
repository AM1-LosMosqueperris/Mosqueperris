import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petcare_santa_cruz/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://chnvnhqpticyokjeaiht.supabase.co',
      publishableKey: 'TU_CLAVE_PUBLICA',
    );
  });

  testWidgets('PetCare Santa Cruz inicia correctamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PetCareApp());

    // Comprobar pantalla de bienvenida
    expect(find.text('PetCare Santa Cruz'), findsOneWidget);
    expect(find.text('Cuidamos a quienes más quieres'), findsOneWidget);
    expect(find.text('¡Bienvenido!'), findsOneWidget);
    expect(find.text('Ver servicios'), findsOneWidget);
    expect(find.text('Iniciar sesión / Registrarse'), findsOneWidget);

    // Probar navegación
    await tester.tap(find.text('Ver servicios'));
    await tester.pumpAndSettle();

    expect(find.text('Servicios'), findsOneWidget);
  });
}
