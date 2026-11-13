
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_santa_cruz/main.dart';

void main() {
  testWidgets('PetCare Santa Cruz inicia correctamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PetCareApp());

    expect(find.text('PetCare Santa Cruz'), findsOneWidget);
    expect(find.text('Mascotas'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Citas'), findsOneWidget);
  });
}
