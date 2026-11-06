// lib/features/legal/legal_texts.dart
// Política de tratamiento de datos (Ley 1581 de 2012, Decreto 1377 de 2013)
// y términos de uso del MVP. Responsable: Laszlo Sierra (persona natural),
// Riohacha. Antes de publicar en tiendas conviene que lo revise un abogado.

/// Cambia cuando cambie el texto: queda guardado con cada autorización.
const legalVersion = '2026-11-06';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

class LegalDoc {
  const LegalDoc({required this.title, required this.sections});
  final String title;
  final List<LegalSection> sections;
}

const privacyPolicy = LegalDoc(
  title: 'Tratamiento de datos',
  sections: [
    LegalSection('Quién responde por tus datos',
        'GoSmart, proyecto en piloto para Riohacha, Maicao y la Troncal del '
            'Caribe. Responsable del tratamiento: Laszlo Sierra, Riohacha '
            '(La Guajira, Colombia). Contacto para consultas y reclamos sobre '
            'tus datos: laszlosierra2@gmail.com. Respondemos consultas en '
            'máximo 10 días hábiles y reclamos en máximo 15 (Ley 1581).'),
    LegalSection('Qué datos usamos',
        '• Cuenta: nombre, correo, celular, cédula, ciudad y fecha de nacimiento.\n'
            '• Ubicación: solo cuando usas el mapa, planeas una ruta, pides ayuda '
            'o compartes un viaje.\n'
            '• Seguridad: tus contactos de emergencia y el registro de cada aviso de ayuda.\n'
            '• Viajes y pagos: origen, destino, tarifa acordada, forma de pago '
            'y motivo si cancelas.\n'
            '• Conductores: documentos, vehículo y llave de pago.'),
    LegalSection('Para qué',
        'Para tu cuenta, planear tus rutas, avisar a tus contactos cuando lo '
            'pides, verificar conductores y registrar pagos. No vendemos tus '
            'datos ni los usamos para publicidad.'),
    LegalSection('Datos sensibles',
        'Tu ubicación y tus documentos son sensibles. Darlos es opcional: '
            'sin ubicación puedes escribir el origen a mano, y solo los '
            'conductores suben documentos.'),
    LegalSection('Con quién se comparten',
        '• Supabase (servidores de la base de datos).\n'
            '• Google (mapa y búsqueda de direcciones) y Groq (asistente), '
            'solo con lo necesario para responder.\n'
            '• Las personas que tú eliges: tus contactos en un SOS y quien '
            'reciba el link de tu viaje (ve tu primer nombre, el destino y tu '
            'última ubicación hasta que el link venza).\n'
            '• Autoridades, solo si la ley lo exige.'),
    LegalSection('Tus derechos',
        'Conocer, actualizar, rectificar y suprimir tus datos, y revocar esta '
            'autorización. Desde la app: en Perfil, "Tus datos" para corregir, y '
            '"Eliminar mi cuenta" para borrarlo todo. También puedes '
            'quejarte ante la Superintendencia de Industria y Comercio.'),
    LegalSection('Cuánto tiempo',
        'Mientras tengas cuenta. Al eliminarla se borran tus datos; los '
            'registros que la ley obliga a guardar (por ejemplo, pagos) se '
            'conservan solo el tiempo exigido.'),
  ],
);

const termsOfUse = LegalDoc(
  title: 'Términos de uso',
  sections: [
    LegalSection('Qué es GoSmart',
        'Una app para saber cómo está la vía, planear cómo moverte y pedir '
            'viajes con conductores verificados de la región.'),
    LegalSection('Información de referencia',
        'Tiempos, tarifas y estado de la vía son estimados o reportes de otros '
            'usuarios. Pueden no coincidir con lo que encuentres. Decide con '
            'cuidado y sigue a las autoridades.'),
    LegalSection('Pagos',
        'Por ahora los viajes se pagan en efectivo directamente al conductor; '
            'GoSmart no recibe ni guarda tu dinero. Te avisaremos en la app '
            'antes de activar pagos con saldo.'),
    LegalSection('Cancelaciones',
        'Puedes cancelar antes de que un conductor acepte. Si ya aceptó, '
            'debes indicar el motivo. Las cancelaciones repetidas sin motivo '
            'real pueden limitar tu cuenta.'),
    LegalSection('Ayuda y emergencias',
        'El botón Ayuda abre la llamada al 123 y tus mensajes desde tu '
            'teléfono. GoSmart no es un servicio de emergencias ni garantiza '
            'que el mensaje llegue: depende de tu señal y de tu operador.'),
    LegalSection('Reportes y respeto',
        'No publiques datos de personas ni señales a comunidades. Los reportes '
            'falsos o que pongan a alguien en riesgo se eliminan y pueden '
            'cerrar tu cuenta.'),
    LegalSection('Conductores',
        'Cada conductor responde por sus documentos, su vehículo y el servicio '
            'que presta. GoSmart verifica los documentos, pero no es la empresa '
            'de transporte.'),
    LegalSection('Cambios',
        'Si cambian estos términos, te lo diremos en la app antes de aplicarlos.'),
  ],
);
