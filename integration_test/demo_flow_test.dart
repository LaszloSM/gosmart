// integration_test/demo_flow_test.dart
// Recorre la demo del MVP en un Android de verdad (emulador de CI, workflow
// android-emulator.yml) contra el Supabase real: mapa de Google, buscar destino, entrar como pasajera demo, pedir un mototaxi
// que acepta el conductor de demo, pagar y ver la billetera.
// El workflow toma capturas con adb mientras corre; cada paso imprime
// "STEP <nombre> <epoch ms>" para ubicarlas. Un paso que falla se anota y la
// prueba sigue hasta el final (para tener todas las capturas), pero al terminar
// falla si hubo algún paso fallido: un verde con pasos rotos no prueba nada.
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

    app.main();
    if (!await waitFor(find.text('¿A dónde vas?'), seconds: 60)) {
      failed.add('no cargó el inicio');
    }
    // Tiempo para que Google baje las teselas del mapa.
    await wait(25);
    step('inicio-google');

    /// Entra con una cuenta demo desde donde esté (abre el login si hace falta).
    Future<bool> login(String email, String tag) async {
      if (find.text('Entra a GoSmart').evaluate().isEmpty) {
        await tap(find.text('Perfil'), 'pestaña Perfil ($tag)');
      }
      if (!await waitFor(find.text('Entra a GoSmart'))) {
        failed.add('no abrió el login ($tag)');
        return false;
      }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), _password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await wait(1);
      step('login-$tag');
      await tap(find.text('Iniciar sesión'), 'botón Iniciar sesión ($tag)');
      await wait(10);
      step('despues-login-$tag');
      return true;
    }

    // Entrar como pasajera demo.
    if (_password.isNotEmpty && await login('pasajero@example.com', 'pasajera')) {
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
        // El punto se confirma en el mapa (pin fijo al centro); la captura
        // muestra si Google lo dejó en la universidad.
        Future<bool> confirmPoint() async {
          final button = find.text('Confirmar destino');
          if (!await waitFor(button)) {
            failed.add('no apareció: confirmar el punto');
            step('FAIL-confirmar el punto');
            return false;
          }
          await wait(6);
          step('confirmar-punto');
          return tap(button, 'botón Confirmar destino');
        }

        if (await tap(find.text('Universidad de La Guajira'), 'sugerencia Uniguajira') &&
            await confirmPoint()) {
          await wait(4);
          step('opciones');
          await tap(find.text('Mototaxi'), 'opción Mototaxi');
          await wait(1);
          if (await tap(find.text('Ver ruta'), 'botón Ver ruta')) {
            await wait(8);
            step('ruta-en-mapa');
            // Mototaxi y taxi vuelven al mapa con el resumen: "Ver viaje" abre el detalle.
            if (find.text('Iniciar viaje').evaluate().isEmpty) {
              await tap(find.text('Ver viaje'), 'botón Ver viaje');
              await wait(4);
            }
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
      step('inicio-alertas');
    }

    // Alertas como Waze: el botón ámbar del mapa, elegir y confirmar.
    if (_password.isNotEmpty &&
        await tap(find.byTooltip('Reportar en la vía'), 'botón Reportar')) {
      await wait(3);
      step('reportar-hoja');
      if (await tap(find.text('Trancón'), 'tipo Trancón')) {
        await wait(1);
        step('reportar-elegido');
        if (await tap(find.text('Reportar trancón'), 'confirmar reporte')) {
          if (await waitFor(find.textContaining('Gracias'), seconds: 15)) {
            step('reportar-gracias');
          } else {
            failed.add('el reporte no se confirmó');
          }
          await wait(4);
        }
      }
    }

    // Configuración: tema oscuro, preferencias de alertas y de vuelta a Sistema.
    if (await tap(find.text('Perfil'), 'pestaña Perfil (config)')) {
      await wait(3);
      step('perfil');
      if (await tap(find.byTooltip('Configuración'), 'engranaje Configuración')) {
        await wait(3);
        step('configuracion');
        if (await tap(find.text('Oscuro'), 'tema Oscuro')) {
          await wait(3);
          step('tema-oscuro');
        }
        if (await tap(find.text('Alertas en el mapa'), 'Alertas en el mapa')) {
          await wait(3);
          step('alertas-config');
          await tap(find.byType(BackButton).last, 'atrás desde Alertas');
          await wait(2);
        }
        // Al volver de Alertas la lista quedó abajo: subir hasta el tema.
        try {
          await tester.scrollUntilVisible(find.text('Sistema'), -300,
              scrollable: find.byType(Scrollable).first);
        } catch (_) {}
        if (await tap(find.text('Sistema'), 'tema Sistema')) {
          await wait(3);
          step('tema-sistema');
        }
        // Salir para entrar como conductor.
        if (_password.isNotEmpty &&
            await tap(find.text('Cerrar sesión'), 'Cerrar sesión')) {
          await wait(6);
          step('sesion-cerrada');
        }
      }
    }

    // Modo conductor (interruptor como InDrive) con el mototaxista demo.
    if (_password.isNotEmpty && await login('conductor@example.com', 'conductor')) {
      if (find.text('Modo conductor').evaluate().isEmpty) {
        await tap(find.text('Perfil'), 'pestaña Perfil (conductor)');
        await wait(4);
      }
      step('perfil-conductor');
      if (await tap(find.text('Modo conductor'), 'interruptor Modo conductor')) {
        await wait(10);
        step('consola-conductor');
        if (await waitFor(find.text('Conectado')) || await waitFor(find.text('Conectarme'))) {
          if (find.text('Conectarme').evaluate().isNotEmpty) {
            await tap(find.text('Conectarme'), 'Conectarme');
            await wait(8);
            step('conductor-conectado');
          }
        } else {
          failed.add('no abrió la consola del conductor');
        }
        if (await tap(find.byTooltip('Menú del conductor'), 'menú del conductor')) {
          await wait(2);
          step('menu-conductor');
          if (await tap(find.text('Hoy y los últimos 7 días'), 'Ganancias')) {
            await wait(4);
            step('ganancias');
            await tester.tapAt(const Offset(200, 120)); // cierra la hoja
            await wait(2);
          }
          if (await tap(find.byTooltip('Menú del conductor'), 'menú del conductor 2')) {
            await wait(2);
            if (await tap(find.text('Cambiar a modo pasajero'), 'volver a pasajero')) {
              await wait(8);
              step('de-vuelta-pasajero');
              await wait(6);
            }
          }
        }
      }
    }

    // ignore: avoid_print
    print('RESULT ${failed.isEmpty ? 'OK' : failed.join(' | ')}');
    expect(failed, isEmpty, reason: 'pasos de la demo que fallaron');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
