import 'package:comboio/design/theme.dart';
import 'package:comboio/design/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BigButton respeita o alvo de toque de 72 dp', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: BigButton(label: 'Criar sala', onPressed: () => taps++),
        ),
      ),
    );
    expect(find.text('CRIAR SALA'), findsOneWidget);
    expect(tester.getSize(find.byType(BigButton)).height, 72);
    await tester.tap(find.byType(BigButton));
    expect(taps, 1);
  });
}
