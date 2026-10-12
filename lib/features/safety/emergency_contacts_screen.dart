// lib/features/safety/emergency_contacts_screen.dart
// Hasta 5 personas que reciben tu SOS. Se guardan en tu cuenta; nadie más
// las ve (RLS de `emergency_contacts`).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_errors.dart';
import '../../models/emergency_contact.dart';
import '../../providers/auth_provider.dart';
import '../../providers/safety_provider.dart';
import '../../services/safety_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';

const kMaxEmergencyContacts = 5;

/// Celular colombiano: 10 dígitos que empiezan por 3 (con o sin +57).
String? validateColombianMobile(String? v) {
  final n = normalizeColombianPhone(v ?? '');
  if (!RegExp(r'^\+573[0-9]{9}$').hasMatch(n)) {
    return 'Escribe un celular de 10 dígitos, por ejemplo 300 123 4567';
  }
  return null;
}

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  Future<void> _delete(
      BuildContext context, WidgetRef ref, EmergencyContact c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar a ${c.name}?'),
        content: const Text('Ya no recibirá tus avisos de SOS.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await safetyService.deleteContact(c.id);
      ref.invalidate(emergencyContactsProvider);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos quitarlo. Revisa tu conexión.',
          type: GSToastType.error);
    }
  }

  void _add(BuildContext context) {
    GSBottomSheet.show(
      context: context,
      title: 'Nuevo contacto',
      initialChildSize: 0.8,
      child: const _ContactForm(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);
    final count = contacts.valueOrNull?.length ?? 0;
    final canAdd = contacts.hasValue && count < kMaxEmergencyContacts;

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Contactos de emergencia')),
      body: contacts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(GSSpacing.s4),
          child: GSInlineError(
            message: 'No pudimos cargar tus contactos',
            onRetry: () => ref.invalidate(emergencyContactsProvider),
          ),
        ),
        data: (list) => list.isEmpty
            ? ListView(children: [
                GSEmptyState(
                  icon: Icons.group_outlined,
                  title: 'Nadie todavía',
                  subtitle: 'Agrega a quien deba saber si algo pasa en el '
                      'camino. Recibe tu ubicación por WhatsApp o SMS.',
                  actionLabel: 'Agregar contacto',
                  onAction: () => _add(context),
                ),
              ])
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, GSSpacing.s2),
                    child: Text(
                      'Reciben tu ubicación cuando tocas Ayuda. '
                      '$count de $kMaxEmergencyContacts.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  for (final c in list) ...[
                    GSListRow(
                      icon: Icons.person_outline_rounded,
                      title: c.name,
                      subtitle: [
                        c.displayPhone,
                        if ((c.relation ?? '').isNotEmpty) c.relation!,
                      ].join(' · '),
                      trailing: IconButton(
                        tooltip: 'Quitar a ${c.name}',
                        icon: Icon(Icons.delete_outline_rounded,
                            color: GSColors.textMuted),
                        onPressed: () => _delete(context, ref, c),
                      ),
                    ),
                    const Divider(indent: GSSpacing.s4),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: canAdd && count > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s3),
                child: GSButton(
                  label: 'Agregar contacto',
                  leadingIcon: Icons.person_add_alt_rounded,
                  onPressed: () => _add(context),
                ),
              ),
            )
          : null,
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm();

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await safetyService.addContact(
        userId: user.id,
        name: _name.text.trim(),
        phone: normalizeColombianPhone(_phone.text),
        relation: _relation.text.trim(),
      );
      ref.invalidate(emergencyContactsProvider);
      navigator.pop();
      GSToast.showWithMessenger(messenger,
          message: 'Contacto guardado', type: GSToastType.success);
    } catch (e) {
      final dup = e.toString().contains('23505');
      GSToast.showWithMessenger(messenger,
          message: dup
              ? 'Ese número ya está en tus contactos.'
              : 'No pudimos guardarlo. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GSTextField(
            label: 'Nombre',
            hint: 'Mamá, Carlos…',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          const SizedBox(height: GSSpacing.s3),
          GSTextField(
            label: 'Celular',
            hint: '300 123 4567',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            validator: validateColombianMobile,
          ),
          const SizedBox(height: GSSpacing.s3),
          GSTextField(
            label: 'Relación (opcional)',
            hint: 'Hermana, pareja, vecino…',
            controller: _relation,
            maxLength: 40,
          ),
          const SizedBox(height: GSSpacing.s5),
          GSButton(
            label: 'Guardar contacto',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
