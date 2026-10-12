// lib/core/safety_links.dart
// Mensajes y enlaces del SOS y de compartir viaje. Lógica pura (sin Flutter)
// para poder probarla: el texto que recibe un familiar no puede fallar.
import 'package:latlong2/latlong.dart';

/// Punto en Google Maps: abre en cualquier teléfono, con o sin la app.
String mapsLink(LatLng p) =>
    'https://maps.google.com/?q=${p.latitude.toStringAsFixed(5)},'
    '${p.longitude.toStringAsFixed(5)}';

/// Link de la página pública del viaje; null si no hay página configurada.
/// El token va en el fragmento (#) para que no quede en logs de servidores.
String? tripShareLink(String baseUrl, String token) {
  final base = baseUrl.trim();
  if (base.isEmpty) return null;
  final withSlash = base.endsWith('/') ? base : '$base/';
  return '${withSlash}viaje.html#t=$token';
}

/// Texto del SOS. Sin ubicación lo dice, en vez de mandar un punto falso.
String sosMessage({LatLng? at, String? name}) {
  final who = (name ?? '').trim().isEmpty ? 'Necesito ayuda' : '${name!.trim()} necesita ayuda';
  final where = at == null
      ? 'No pude obtener mi ubicación.'
      : 'Estoy aquí: ${mapsLink(at)}';
  return '🆘 $who. $where Mensaje enviado desde GoSmart.';
}

/// Texto para compartir el viaje por WhatsApp.
String tripShareMessage({
  required String destination,
  String? mode,
  String? link,
  LatLng? at,
  DateTime? until,
}) {
  final how = (mode ?? '').trim().isEmpty ? '' : ' en $mode';
  final b = StringBuffer('Voy$how hacia $destination.');
  if (link != null) {
    b.write(' Sigue mi viaje aquí: $link');
    if (until != null) b.write(' (activo hasta las ${clock12(until)})');
  } else if (at != null) {
    b.write(' Salgo desde aquí: ${mapsLink(at)}');
  }
  return b.toString();
}

/// Hora corta en 12 h como se dice en la región: "3:05 p. m.".
String clock12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// WhatsApp a un número (+57…) o, sin número, al selector de chats.
Uri whatsappUri(String text, {String? phone}) {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  // encodeComponent (%20) y no queryParameters (+): algunos clientes muestran el +.
  return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
}

/// SMS a uno o varios números. Android separa destinatarios con coma.
Uri smsUri(String text, List<String> phones) =>
    Uri.parse('sms:${phones.join(',')}?body=${Uri.encodeComponent(text)}');

/// Línea única de emergencias de Colombia.
final Uri emergencyCallUri = Uri(scheme: 'tel', path: '123');
