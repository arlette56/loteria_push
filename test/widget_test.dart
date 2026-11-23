import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_push/dominio/almacen.dart';
import 'package:loteria_push/dominio/controlador.dart';
import 'package:loteria_push/main.dart';

import 'falsos.dart';

void main() {
  testWidgets('muestra pantalla de ingreso y entra a la sala con el tablero de 16 cartas', (tester) async {
    final ctrl = ControladorJuego(
      api: ApiFalsa(),
      push: PuertoPushFalso(),
      almacen: AlmacenMemoria(),
    );
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(LoteriaApp(controlador: ctrl));
    expect(find.text('Entrar a la sala'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Ana');
    await tester.tap(find.text('Entrar a la sala'));
    await tester.pumpAndSettle();

    expect(find.text('Sala ABCDE — Ana'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('¡LOTERÍA!'), findsOneWidget);
  });

  testWidgets('al llegar una carta por push se marca en el tablero y habilita Lotería al completar fila1', (tester) async {
    final api = ApiFalsa()..tabla = List<int>.generate(16, (i) => i + 1);
    final push = PuertoPushFalso();
    final ctrl = ControladorJuego(
      api: api,
      push: push,
      almacen: AlmacenMemoria(),
    );
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(LoteriaApp(controlador: ctrl));
    await tester.enterText(find.byType(TextField).last, 'Ana');
    await tester.tap(find.text('Entrar a la sala'));
    await tester.pumpAndSettle();

    final botonLoteria = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '¡LOTERÍA!'));
    expect(botonLoteria.onPressed, isNull);

    for (var i = 1; i <= 4; i++) {
      push.emitirEnPrimerPlano(mensajeCarta(i, i));
      await tester.pump();
    }
    await tester.pump();

    expect(find.text('Carta #4: Carta 4 — Pista 4'), findsOneWidget);
    final botonHabilitado = tester.widget<FilledButton>(find.widgetWithText(FilledButton, '¡LOTERÍA!'));
    expect(botonHabilitado.onPressed, isNotNull);
  });
}