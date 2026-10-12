// lib/features/legal/legal_texts.dart
// Política de tratamiento de datos (Ley 1581 de 2012, Decreto 1377 de 2013)
// y términos de uso. BORRADOR del MVP: falta que el responsable ponga su
// nombre o razón social y un correo de contacto, y que lo revise un abogado.
// Los huecos se marcan con [PENDIENTE] a la vista, a propósito.

/// Cambia cuando cambie el texto: queda guardado con cada autorización.
const legalVersion = '2026-10-12-borrador';

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
            'Caribe. Responsable: [PENDIENTE: nombre o razón social]. '
            'Contacto: [PENDIENTE: correo].'),
    LegalSection('Qué datos usamos',
        '• Cuenta: nombre, correo, celular, cédula, ciudad y fecha de nacimiento.\n'
            '• Ubicación: solo cuando usas el mapa, planeas una ruta, pides ayuda '
            'o compartes un viaje.\n'
            '• Seguridad: tus contactos de emergencia y el registro de cada aviso de ayuda.\n'
            '• Billetera: saldo y movimientos (hoy de prueba).\n'
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
        'Una app para saber cómo está la vía, planear cómo moverte y, en las '
            'próximas versiones, pedir y pagar viajes con conductores de la región.'),
    LegalSection('Información de referencia',
        'Tiempos, tarifas y estado de la vía son estimados o reportes de otros '
            'usuarios. Pueden no coincidir con lo que encuentres. Decide con '
            'cuidado y sigue a las autoridades.'),
    LegalSection('La billetera hoy',
        'El saldo es de prueba: las recargas son simuladas y no son dinero '
            'real. Te avisaremos antes de que eso cambie.'),
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
