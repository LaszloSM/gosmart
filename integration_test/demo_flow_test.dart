// integration_test/demo_flow_test.dart
// Recorre la demo del MVP en un Android de verdad (emulador de CI, workflow
// android-emulator.yml) contra el Supabase real: mapa de Google, mapa
// alternativo, buscar destino, entrar como pasajera demo, pedir un mototaxi
// que acepta el conductor de demo, pagar y ver la billetera.
// El workflow toma capturas con adb mientras corre; cada paso imprime
// "STEP <nombre> <epoch ms>" para ubicarlas. Un paso que falla se anota y la
// prueba sigue: el resultado es el registro de pasos y las capturas.
//
// Local: flutter test integration_test/demo_flow_test.dart -d <emulador> \
//          --dart-define=DEMO_PASSWORD=...
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _password = String.fromEnvironment('DEMO_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo del MVP', (tester) async {
    final failed = <String>[];

    void step(String name) =>
        // ignore: avoid_print
        print('STEP $name ${DateTime.now().millisecondsSinceEpoch}');

    Future<void> wait(int seconds) async {
      for (var i = 0; i < seconds * 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<bool> waitFor(Finder f, {int seconds = 20}) async {
      for (var i = 0; i < seconds * 4; i++) {
        if (f.evaluate().isNotEmpty) return true;
        await tester.pump(const Duration(milliseconds: 250));
      }
      return f.evaluate().isNotEmpty;
    }

    Future<bool> tap(Finder f, String what, {int seconds = 20}) async {
      if (!await waitFor(f, seconds: seconds)) {
        failed.add('no apareció: $what');
        step('FAIL-$what');
        return false;
      }
      await tester.ensureVisible(f.first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(f.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.remove('map_provider');

    app.main();
    if (!await waitFor(find.text('¿A dónde vas?'), seconds: 60)) {
      failed.add('no cargó el inicio');
    }
    // Tiempo para que Google baje las teselas del mapa.
    await wait(25);
    step('inicio-google');

    if (await tap(find.byTooltip('Tipo de mapa'), 'botón de capas')) {
      await wait(2);
      step('elegir-mapa');
      await tap(find.text('Mapa alternativo'), 'opción mapa alternativo');
      await wait(15);
      step('inicio-osm');
      await tap(find.byTooltip('Tipo de mapa'), 'botón de capas');
      await wait(2);
      await tap(find.text('Google Maps'), 'opción Google Maps');
      await wait(8);
    }

    // Entrar como pasajera demo.
    if (_password.isNotEmpty && await tap(find.text('Perfil'), 'pestaña Perfil')) {
      if (await waitFor(find.text('Entra a GoSmart'))) {
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'pasajero@example.com');
        await tester.enterText(fields.at(1), _password);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await wait(1);
        step('login');
        await tap(find.text('Iniciar sesión'), 'botón Iniciar sesión');
        await wait(10);
        step('despues-login');
      } else {
        failed.add('no abrió el login');
      }
      await tap(find.text('Inicio'), 'pestaña Inicio');
      await wait(10);
      step('inicio-con-cuenta');
    }

    // Planear: Parque Padilla (GPS del emulador) → Universidad de La Guajira.
    if (await tap(find.text('¿A dónde vas?'), 'buscador ¿A dónde vas?')) {
      await wait(4);
      step('planificador');
      final field = find.widgetWithText(TextField, '¿A dónde vas?');
      if (await waitFor(field)) {
        await tester.enterText(field.first, 'Universidad');
        await wait(6);
        step('sugerencias');
        if (await tap(find.text('Universidad de La Guajira'), 'sugerencia Uniguajira')) {
          await wait(4);
          step('opciones');
          await tap(find.text('Mototaxi'), 'opción Mototaxi');
          await wait(1);
          if (await tap(find.text('Ver ruta'), 'botón Ver ruta')) {
            await wait(8);
            step('detalle-ruta');
            if (await tap(find.text('Iniciar viaje'), 'botón Iniciar viaje')) {
              await wait(6);
              step('viaje');
              if (await tap(find.textContaining('Pedir '), 'botón Pedir mototaxi')) {
                await wait(3);
                step('pedido');
                if (await waitFor(find.textContaining('viene por ti'), seconds: 45)) {
                  await wait(2);
                  step('conductor-en-camino');
                } else {
                  failed.add('nadie aceptó el mototaxi');
                }
                if (await waitFor(find.textContaining('Vas con'), seconds: 60)) {
                  await wait(2);
                  step('en-viaje');
                  if (await tap(find.textContaining('con saldo de prueba'), 'pagar con saldo')) {
                    await wait(5);
                    step('pagado');
                  }
                } else {
                  failed.add('no pasó a "en viaje"');
                }
                await wait(70);
                step('final-viaje');
              }
            }
          }
        }
      } else {
        failed.add('no apareció el campo de destino');
      }
    }

    if (_password.isNotEmpty && await tap(find.text('Billetera'), 'pestaña Billetera')) {
      await wait(6);
      step('billetera');
    }
    if (await tap(find.text('Inicio'), 'pestaña Inicio')) {
      await wait(8);
      step('inicio-final');
    }

    // ignore: avoid_print
    print('RESULT ${failed.isEmpty ? 'OK' : failed.join(' | ')}');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
