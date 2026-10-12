// lib/features/driver/driver_signup_screen.dart
// Registro de conductor, en una sola página por secciones: tú, tu servicio,
// tu vehículo y cómo te pagan. Los documentos se suben después, en la
// pantalla del conductor, uno por uno (con mala señal es más fácil).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_errors.dart';
import '../../models/driver_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/app_router.dart';
import '../../services/driver_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_choice_plates.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../safety/emergency_contacts_screen.dart' show validateColombianMobile;

class DriverSignupScreen extends ConsumerStatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  ConsumerState<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends ConsumerState<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cedula = TextEditingController();
  final _phone = TextEditingController();
  final _license = TextEditingController();
  final _plate = TextEditingController();
  final _brand = TextEditingController();
  final _color = TextEditingController();
  final _payoutKey = TextEditingController();

  String _service = 'mototaxi';
  String _zone = 'riohacha';
  String? _payoutKind;
  int _seats = 4;
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    for (final c in [
      _name, _cedula, _phone, _license, _plate, _brand, _color, _payoutKey,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rellena con lo que ya se sabe: el registro anterior o el perfil.
  void _prefill(DriverProfile? d) {
    if (_prefilled) return;
    _prefilled = true;
    final p = ref.read(profileProvider).valueOrNull;
    _name.text = d?.fullName ?? p?.name ?? '';
    _cedula.text = d?.cedula ?? p?.cedula ?? '';
    _phone.text = (d?.phone ?? p?.phone ?? '').replaceFirst('+57', '');
    _license.text = d?.licenseNumber ?? '';
    _plate.text = d?.vehicle?.plate ?? '';
    _brand.text = d?.vehicle?.brand ?? '';
    _color.text = d?.vehicle?.color ?? '';
    _payoutKey.text = d?.payoutKey ?? '';
    if (d != null) {
      _service = d.service;
      _zone = d.zone;
      _payoutKind = d.payoutKind;
      _seats = d.vehicle?.seats ?? _seats;
    }
  }

  bool get _hasSeats => _service == 'colectivo' || _service == 'intermunicipal';

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    try {
      await driverService.saveRegistration(
        userId: user.id,
        fullName: _name.text.trim(),
        cedula: _cedula.text.replaceAll(RegExp(r'\D'), ''),
        phone: normalizeColombianPhone(_phone.text),
        service: _service,
        zone: _zone,
        licenseNumber:
            _license.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''),
        plate: normalizePlate(_plate.text)!,
        brand: _brand.text.trim(),
        color: _color.text.trim(),
        seats: _service == 'mototaxi' ? 1 : (_hasSeats ? _seats : 4),
        payoutKind: _payoutKind,
        payoutKey: _payoutKey.text.trim(),
      );
      ref.invalidate(myDriverProvider);
      GSToast.showWithMessenger(messenger,
          message: 'Datos guardados. Ahora sube tus documentos.',
          type: GSToastType.success);
      router.pushReplacement(AppRoutes.driver);
    } catch (e) {
      final dupPlate = e.toString().contains('vehicles_plate_key');
      GSToast.showWithMessenger(messenger,
          message: dupPlate
              ? 'Esa placa ya está registrada por otro conductor.'
              : 'No pudimos guardar. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(myDriverProvider);
    if (existing.hasValue) _prefill(existing.value);
    final text = Theme.of(context).textTheme;
    final approved = existing.valueOrNull?.status == DriverStatus.approved;

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Ser conductor')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: GSSpacing.s8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
              child: Text(
                approved
                    ? 'Si cambias tu nombre, cédula, servicio o licencia, '
                        'tu cuenta vuelve a revisión.'
                    : 'Revisamos tus datos y documentos antes de que '
                        'recibas viajes. Toma uno o dos días.',
                style: text.bodyMedium,
              ),
            ),
            const GSSectionTitle('Tú'),
            _Pad(GSTextField(
              label: 'Nombre completo (como en la cédula)',
              hint: 'Nombre y apellidos',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().length < 3
                  ? 'Escribe tu nombre completo'
                  : null,
            )),
            _Pad(GSTextField(
              label: 'Cédula',
              hint: 'Solo números',
              controller: _cedula,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  RegExp(r'^[0-9]{5,12}$').hasMatch(v ?? '')
                      ? null
                      : 'Escribe tu cédula sin puntos',
            )),
            _Pad(GSTextField(
              label: 'Celular',
              hint: '300 123 4567',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: validateColombianMobile,
            )),
            const GSSectionTitle('Tu servicio'),
            _Pad(GSChoicePlates<String>(
              options: driverServices,
              selected: _service,
              onChanged: (s) => setState(() => _service = s),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, GSSpacing.s2),
              child: Text('¿Dónde trabajas?', style: text.titleSmall),
            ),
            _Pad(GSChoicePlates<String>(
              options: driverZones,
              selected: _zone,
              onChanged: (z) => setState(() => _zone = z),
            )),
            _Pad(GSTextField(
              label: 'Número de licencia',
              hint: 'Como aparece en la licencia',
              controller: _license,
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                final n = (v ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                return n.length < 5 ? 'Escribe el número de tu licencia' : null;
              },
            )),
            const GSSectionTitle('Tu vehículo'),
            _Pad(GSTextField(
              label: 'Placa',
              hint: _service == 'mototaxi' ? 'ABC12D' : 'ABC123',
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => normalizePlate(v ?? '') == null
                  ? 'Revisa la placa: 3 letras y 3 números (moto: ABC12D)'
                  : null,
            )),
            _Pad(GSTextField(
              label: 'Marca y línea (opcional)',
              hint: 'Bajaj Boxer, Chevrolet Spark…',
              controller: _brand,
            )),
            _Pad(GSTextField(
              label: 'Color (opcional)',
              hint: 'Rojo',
              controller: _color,
            )),
            if (_hasSeats)
              _Pad(Row(
                children: [
                  Expanded(
                    child: Text('Puestos para pasajeros',
                        style: text.bodyLarge),
                  ),
                  IconButton(
                    tooltip: 'Menos puestos',
                    onPressed:
                        _seats > 1 ? () => setState(() => _seats--) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text('$_seats',
                      style: text.titleLarge
                          ?.copyWith(fontFeatures: GSFonts.tabular)),
                  IconButton(
                    tooltip: 'Más puestos',
                    onPressed:
                        _seats < 30 ? () => setState(() => _seats++) : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              )),
            const GSSectionTitle('Cómo te pagan (opcional)'),
            _Pad(GSChoicePlates<String>(
              options: payoutKinds,
              selected: _payoutKind,
              onChanged: (k) => setState(
                  () => _payoutKind = _payoutKind == k ? null : k),
            )),
            if (_payoutKind != null)
              _Pad(GSTextField(
                label: _payoutKind == 'breb'
                    ? 'Tu llave Bre-B'
                    : 'Celular de ${payoutKinds[_payoutKind]}',
                hint: _payoutKind == 'breb' ? '@tullave o celular' : '300 123 4567',
                controller: _payoutKey,
                maxLength: 80,
              )),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
              child: Text(
                'Tus datos solo los ve el equipo que verifica conductores. '
                'Al pasajero le mostramos tu nombre, foto, vehículo y placa.',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s2, GSSpacing.s4,
              GSSpacing.s3 + MediaQuery.of(context).viewInsets.bottom),
          child: GSButton(
            label: 'Guardar y seguir',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s2),
        child: child,
      );
}
