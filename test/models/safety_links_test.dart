// test/models/safety_links_test.dart
// El texto que recibe un familiar en un SOS no puede fallar.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/safety_links.dart';
import 'package:gosmart/features/safety/emergency_contacts_screen.dart';
import 'package:gosmart/models/emergency_contact.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const riohacha = LatLng(11.544123, -72.907456);

  test('el SOS lleva el punto en Google Maps con 5 decimales', () {
    final m = sosMessage(at: riohacha, name: 'Ana');
    expect(m, contains('Ana necesita ayuda'));
    expect(m, contains('https://maps.google.com/?q=11.54412,-72.90746'));
  });

  test('sin ubicación lo dice en vez de inventar un punto', () {
    final m = sosMessage(at: null, name: '');
    expect(m, contains('Necesito ayuda'));
    expect(m, contains('No pude obtener mi ubicación'));
    expect(m, isNot(contains('maps.google.com')));
  });

  test('WhatsApp codifica espacios como %20 y quita el + del número', () {
    final u = whatsappUri('hola mundo', phone: '+573001234567');
    expect(u.toString(), 'https://wa.me/573001234567?text=hola%20mundo');
    expect(whatsappUri('x').toString(), 'https://wa.me/?text=x');
  });

  test('SMS a varios contactos separados por coma', () {
    final u = smsUri('a b', ['+573001112233', '+573004445566']);
    expect(u.toString(), 'sms:+573001112233,+573004445566?body=a%20b');
  });

  test('el link del viaje va en el fragmento y respeta la barra final', () {
    expect(tripShareLink('', 'abc'), isNull);
    expect(tripShareLink('https://x.github.io/gosmart', 'abc'),
        'https://x.github.io/gosmart/viaje.html#t=abc');
    expect(tripShareLink('https://x.github.io/gosmart/', 'abc'),
        'https://x.github.io/gosmart/viaje.html#t=abc');
  });

  test('mensaje de compartir: con link, hora; sin link, punto de salida', () {
    final withLink = tripShareMessage(
      destination: 'Terminal de Maicao',
      mode: 'Colectivo',
      link: 'https://l',
      until: DateTime(2026, 10, 12, 15, 5),
    );
    expect(withLink,
        'Voy en Colectivo hacia Terminal de Maicao. Sigue mi viaje aquí: '
        'https://l (activo hasta las 3:05 p. m.)');
    final noLink =
        tripShareMessage(destination: 'el muelle', at: riohacha);
    expect(noLink, startsWith('Voy hacia el muelle. Salgo desde aquí: https://maps'));
  });

  test('hora en 12 h', () {
    expect(clock12(DateTime(2026, 1, 1, 0, 7)), '12:07 a. m.');
    expect(clock12(DateTime(2026, 1, 1, 12, 0)), '12:00 p. m.');
    expect(clock12(DateTime(2026, 1, 1, 23, 59)), '11:59 p. m.');
  });

  test('celular colombiano válido con o sin +57', () {
    expect(validateColombianMobile('300 123 4567'), isNull);
    expect(validateColombianMobile('+57 300 123 4567'), isNull);
    expect(validateColombianMobile('6057281234'), isNotNull); // fijo
    expect(validateColombianMobile('300123'), isNotNull);
  });

  test('el contacto se lee en grupos de 3-3-4', () {
    const c = EmergencyContact(id: '1', name: 'Mamá', phone: '+573001234567');
    expect(c.displayPhone, '300 123 4567');
  });
}
