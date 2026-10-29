// lib/features/settings/settings_screen.dart
// Configuración, como en Google Maps o Waze: lo que es del teléfono (tema,
// alertas del mapa) y lo de la cuenta (contraseña, datos y la ley, salir).
// Sirve también sin cuenta: el tema y las alertas no la necesitan.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_switch.dart';
import '../../models/map_alert.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_alerts_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_nav_spacer.dart';
import '../../widgets/gs_pressable.dart';
import '../../widgets/gs_toast.dart';
import '../profile/widgets/change_password_form.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _changePassword() {
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();
    GSBottomSheet.show(
      context: context,
      title: 'Cambiar contraseña',
      initialChildSize: 0.65,
      child: ChangePasswordForm(
        newPassCtrl: _newPassCtrl,
        confirmPassCtrl: _confirmPassCtrl,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          try {
            await ref.read(profileProvider.notifier).updatePassword(_newPassCtrl.text);
            navigator.pop();
            GSToast.showWithMessenger(messenger,
                message: 'Contraseña cambiada', type: GSToastType.success);
          } catch (_) {
            GSToast.showWithMessenger(messenger,
                message: 'No pudimos cambiar la contraseña. Intenta de nuevo.',
                type: GSToastType.error);
          }
        },
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
            'Se borran tu perfil, tu billetera de prueba, tus contactos de '
            'emergencia y tus viajes. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await authService.deleteAccount();
      await authService.signOut();
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos eliminar tu cuenta. Revisa tu conexión e intenta de nuevo.',
          type: GSToastType.error);
    }
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // El router lleva al login solo, con el evento de auth.
      await authService.signOut();
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos cerrar sesión. Intenta de nuevo.', type: GSToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final prefs = ref.watch(alertPrefsProvider);
    final shown = prefs.values.where((p) => p.show).length;
    final warned = prefs.values.where((p) => p.show && p.warn).length;

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const GSSectionTitle('Apariencia'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: _ThemePicker(),
          ),
          const GSSectionTitle('Mapa y alertas'),
          GSGroup(children: [
            GSListRow(
              icon: Icons.add_location_alt_rounded,
              title: 'Alertas en el mapa',
              subtitle: shown == 0
                  ? 'No ves ninguna alerta'
                  : '$shown de ${AlertKind.all.length} tipos visibles · '
                      '${warned == 0 ? 'sin avisos' : 'te avisamos de $warned'}',
              onTap: () => context.push(AppRoutes.alertSettings),
            ),
          ]),
          if (!isGuest) ...[
            const GSSectionTitle('Tu cuenta'),
            GSGroup(children: [
              GSListRow(
                icon: Icons.group_rounded,
                title: 'Contactos de emergencia',
                subtitle: 'Reciben tu ubicación cuando pides ayuda',
                onTap: () => context.push(AppRoutes.emergencyContacts),
              ),
              GSListRow(
                icon: Icons.lock_rounded,
                title: 'Cambiar contraseña',
                onTap: _changePassword,
              ),
            ]),
          ],
          const GSSectionTitle('Tus datos y la ley'),
          GSGroup(children: [
            GSListRow(
              icon: Icons.privacy_tip_rounded,
              title: 'Cómo usamos tus datos',
              onTap: () => context.push(AppRoutes.privacy),
            ),
            GSListRow(
              icon: Icons.description_rounded,
              title: 'Términos de uso',
              onTap: () => context.push(AppRoutes.terms),
            ),
            if (!isGuest)
              GSListRow(
                icon: Icons.delete_forever_rounded,
                iconColor: GSColors.roadClosed,
                title: 'Eliminar mi cuenta',
                subtitle: 'Borra tu perfil, billetera, contactos y viajes',
                onTap: _deleteAccount,
              ),
          ]),
          if (kDebugMode) ...[
            const GSSectionTitle('Desarrollo'),
            GSGroup(children: [
              GSListRow(
                icon: Icons.nfc_rounded,
                title: 'Simulador NFC',
                subtitle: 'Solo en builds de depuración',
                onTap: () => context.push(AppRoutes.nfcSimulator),
              ),
            ]),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s8, GSSpacing.s4, GSSpacing.s3),
            child: isGuest
                ? GSButton(
                    label: 'Entrar o crear cuenta',
                    onPressed: () => context.push(AppRoutes.login),
                  )
                : GSButton(
                    label: 'Cerrar sesión',
                    variant: GSButtonVariant.outline,
                    leadingIcon: Icons.logout_rounded,
                    onPressed: _signOut,
                  ),
          ),
          Center(
            child: Text('GoSmart 1.1.0', style: Theme.of(context).textTheme.bodySmall),
          ),
          const GSNavSpacer(),
        ],
      ),
    );
  }
}

/// Tres tarjetas con un teléfono en miniatura (Sistema, Claro, Oscuro): se
/// ve lo que se elige antes de elegirlo. El cambio se funde (ThemeSwitchHost).
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    Widget card(ThemeMode m, String label, IconData icon) => Expanded(
          child: _ThemeCard(
            mode: m,
            label: label,
            icon: icon,
            selected: mode == m,
            onTap: () {
              if (mode == m) return;
              ThemeSwitchHost.run(context, () => ref.read(themeModeProvider.notifier).set(m));
            },
          ),
        );
    return Row(
      children: [
        card(ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
        const SizedBox(width: GSSpacing.s2),
        card(ThemeMode.light, 'Claro', Icons.light_mode_rounded),
        const SizedBox(width: GSSpacing.s2),
        card(ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: 'Tema $label',
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : GSDuration.fast,
        curve: GSCurve.enter,
        padding: const EdgeInsets.all(GSSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? GSColors.brandTint : GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: selected ? GSColors.brand : GSColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 0.8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GSRadius.md),
                child: CustomPaint(painter: _MiniPhone(mode)),
              ),
            ),
            const SizedBox(height: GSSpacing.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: GSSize.iconSm, color: selected ? GSColors.brand : GSColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? GSColors.brand : GSColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La app en miniatura: mapa, una ruta azul y la hoja de abajo. "Sistema"
/// va partido en diagonal (mitad día, mitad noche).
class _MiniPhone extends CustomPainter {
  _MiniPhone(this.mode);
  final ThemeMode mode;

  void _scene(Canvas c, Size s, GSPalette p, bool dark) {
    c.drawRect(Offset.zero & s, Paint()..color = dark ? const Color(0xFF1E2430) : const Color(0xFFE8ECF2));
    final street = Paint()
      ..color = dark ? const Color(0xFF2C3442) : Colors.white
      ..strokeWidth = s.width * 0.06;
    c.drawLine(Offset(0, s.height * 0.22), Offset(s.width, s.height * 0.12), street);
    c.drawLine(Offset(s.width * 0.3, 0), Offset(s.width * 0.45, s.height * 0.6), street);
    final route = Paint()
      ..color = p.brand
      ..strokeWidth = s.width * 0.045
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawPath(
        Path()
          ..moveTo(s.width * 0.2, s.height * 0.5)
          ..quadraticBezierTo(s.width * 0.5, s.height * 0.18, s.width * 0.82, s.height * 0.3),
        route);
    c.drawCircle(Offset(s.width * 0.82, s.height * 0.3), s.width * 0.05, Paint()..color = p.brand);
    // Hoja de abajo
    final sheet = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, s.height * 0.6, s.width, s.height * 0.4),
      topLeft: Radius.circular(s.width * 0.12),
      topRight: Radius.circular(s.width * 0.12),
    );
    c.drawRRect(sheet, Paint()..color = p.surface);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.1, s.height * 0.7, s.width * 0.8, s.height * 0.09),
            Radius.circular(s.height)),
        Paint()..color = p.surfaceSunken);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(s.width * 0.1, s.height * 0.84, s.width * 0.36, s.height * 0.08),
            Radius.circular(s.width * 0.04)),
        Paint()..color = p.brandTint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case ThemeMode.light:
        _scene(canvas, size, GSPalette.light, false);
      case ThemeMode.dark:
        _scene(canvas, size, GSPalette.dark, true);
      case ThemeMode.system:
        _scene(canvas, size, GSPalette.light, false);
        canvas.save();
        canvas.clipPath(Path()
          ..moveTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close());
        _scene(canvas, size, GSPalette.dark, true);
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MiniPhone old) => old.mode != mode;
}
