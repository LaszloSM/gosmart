import 'dart:math' show cos, sin, pi;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/authorize_result.dart';
import '../../providers/card_provider.dart';
import '../../services/card_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';

enum PaymentValidationState { processing, authorized, insufficient, error, offline }

class PaymentValidationScreen extends ConsumerStatefulWidget {
  const PaymentValidationScreen({super.key});

  @override
  ConsumerState<PaymentValidationScreen> createState() =>
      _PaymentValidationScreenState();
}

class _PaymentValidationScreenState
    extends ConsumerState<PaymentValidationScreen>
    with TickerProviderStateMixin {
  PaymentValidationState _state = PaymentValidationState.processing;
  late final AnimationController _pulseCtrl;
  late final AnimationController _successCtrl;
  late final CurvedAnimation _rippleCurved;
  String _idempotencyKey = cardService.newIdempotencyKey();

  // Populated after authorize response
  String _resultAmount = '—';
  String _resultDetail = 'Tarjeta GoSmart';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _successCtrl = AnimationController(
      vsync: this,
      duration: GSAnimDuration.particleBurst,
    );
    _rippleCurved = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _runAuthorize();
  }

  @override
  void dispose() {
    _rippleCurved.dispose();
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAuthorize() async {
    setState(() => _state = PaymentValidationState.processing);
    if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);

    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) {
      if (mounted) {
        setState(() {
          _state = PaymentValidationState.error;
          _resultDetail = 'No hay tarjeta activa';
        });
      }
      return;
    }

    try {
      final result = await cardService.authorize(
        cardId: card.id,
        validatorId: 'VLD-BOG-001',
        amount: 2900,
        idempotencyKey: _idempotencyKey,
        mode: 'bus',
      );

      if (!mounted) return;
      _pulseCtrl.stop();

      final remaining = result.remainingBalance;

      if (result.isAuthorized) {
        setState(() {
          _state = PaymentValidationState.authorized;
          _resultAmount = '\$2.900 COP';
          _resultDetail = remaining != null
              ? 'Saldo restante: \$${remaining.toStringAsFixed(0)} COP'
              : card.numberMasked;
        });
        _successCtrl.forward(from: 0);
        // Refresh card balance shown in Wallet / Home
        ref.read(activeCardProvider.notifier).refresh();
      } else {
        switch (result.status) {
          case AuthorizeStatus.insufficientBalance:
            setState(() {
              _state = PaymentValidationState.insufficient;
              _resultAmount =
                  '\$${remaining?.toStringAsFixed(0) ?? '0'} COP';
              _resultDetail = 'Saldo insuficiente para \$2.900 COP';
            });
          case AuthorizeStatus.cardLocked:
            setState(() {
              _state = PaymentValidationState.error;
              _resultAmount = '—';
              _resultDetail = 'Tarjeta bloqueada';
            });
          default:
            setState(() {
              _state = PaymentValidationState.error;
              _resultAmount = '—';
              _resultDetail = result.errorCode ?? 'Error desconocido';
            });
        }
      }
    } catch (e) {
      if (!mounted) return;
      _pulseCtrl.stop();
      setState(() {
        _state = PaymentValidationState.error;
        _resultAmount = '—';
        _resultDetail = e.toString();
      });
    }
  }

  void _retry() {
    _idempotencyKey = cardService.newIdempotencyKey();
    _runAuthorize();
  }

  void _setDemo(PaymentValidationState s) {
    setState(() => _state = s);
    if (s == PaymentValidationState.authorized) {
      _successCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Debug-only state switcher — hidden in release builds
            if (kDebugMode) _DemoSwitcher(onSelect: _setDemo),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(GSSpacing.s8),
                  child: _buildContent(),
                ),
              ),
            ),

            // CTA — hidden while processing
            if (_state != PaymentValidationState.processing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s6),
                child: _buildCta(context),
              ),
          ],
        ),
      ),
    );
  }

  Color get _bgColor {
    switch (_state) {
      case PaymentValidationState.authorized:
        return GSColors.successLight;
      case PaymentValidationState.insufficient:
        return GSColors.warningLight;
      case PaymentValidationState.error:
        return GSColors.errorLight;
      case PaymentValidationState.offline:
        return GSColors.surfaceDark;
      default:
        return GSColors.bg;
    }
  }

  Widget _buildContent() {
    switch (_state) {
      case PaymentValidationState.processing:
        return _ProcessingView(controller: _pulseCtrl);
      case PaymentValidationState.authorized:
        return _buildAuthorizedState();
      case PaymentValidationState.insufficient:
        return _ResultView(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: GSColors.warning,
          title: 'Saldo Insuficiente',
          subtitle: 'Recarga tu tarjeta para continuar',
          amount: _resultAmount,
          detail: _resultDetail,
          badgeLabel: 'RECHAZADO',
          badgeColor: GSColors.warning,
        );
      case PaymentValidationState.error:
        return _ResultView(
          icon: Icons.error_rounded,
          iconColor: GSColors.error,
          title: 'Pago Fallido',
          subtitle: 'Por favor intenta de nuevo',
          amount: '—',
          detail: _resultDetail,
          badgeLabel: 'ERROR',
          badgeColor: GSColors.error,
        );
      case PaymentValidationState.offline:
        return const _OfflineView();
    }
  }

  Widget _buildAuthorizedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple background
              AnimatedBuilder(
                animation: _rippleCurved,
                builder: (_, __) {
                  final t = _rippleCurved.value;
                  return Container(
                    width: 60 + 100 * t,
                    height: 60 + 100 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GSColors.success.withValues(alpha: 0.12 * (1 - t)),
                    ),
                  );
                },
              ),
              // Particles
              _AnimatedParticleBurst(controller: _successCtrl),
              // Checkmark
              _AnimatedCheckmark(
                controller: _successCtrl,
                color: GSColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: GSSpacing.s5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: GSColors.success,
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          child: const Text('AUTORIZADO',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.5)),
        ),
        const SizedBox(height: GSSpacing.s5),
        const Text('Pago Autorizado',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s2),
        const Text('¡Que tengas un buen viaje!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s6),
        GSCard(
          padding: const EdgeInsets.all(GSSpacing.s5),
          shadow: GSShadow.md,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto',
                        style: TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                    Text(_resultAmount,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: GSColors.textPrimary)),
                    Text(_resultDetail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: GSSpacing.s3),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: GSColors.accentLight,
                  borderRadius: BorderRadius.all(Radius.circular(GSRadius.md)),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: GSColors.accent, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCta(BuildContext context) {
    switch (_state) {
      case PaymentValidationState.authorized:
        return GSButton(
          label: 'Listo',
          onPressed: () => Navigator.pop(context),
          leadingIcon: Icons.home_rounded,
        );
      case PaymentValidationState.insufficient:
        return Column(
          children: [
            GSButton(
              label: 'Recargar ahora',
              onPressed: () => Navigator.pop(context),
              leadingIcon: Icons.add_rounded,
            ),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Usar código QR',
              onPressed: () {},
              variant: GSButtonVariant.outline,
              leadingIcon: Icons.qr_code_rounded,
            ),
          ],
        );
      case PaymentValidationState.error:
        return Column(
          children: [
            GSButton(
              label: 'Intentar de nuevo',
              onPressed: _retry,
              leadingIcon: Icons.refresh_rounded,
            ),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Usar código QR',
              onPressed: () {},
              variant: GSButtonVariant.outline,
              leadingIcon: Icons.qr_code_rounded,
            ),
          ],
        );
      case PaymentValidationState.offline:
        return GSButton(
          label: 'Generar QR sin conexión',
          onPressed: () {},
          leadingIcon: Icons.qr_code_rounded,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Views ────────────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, child) {
            final scale = 0.85 + (controller.value * 0.15);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: GSColors.accentLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: GSColors.accent
                          .withValues(alpha: 0.20 * controller.value),
                      blurRadius: 40,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.contactless_rounded,
                    size: 72, color: GSColors.accent),
              ),
            );
          },
        ),
        const SizedBox(height: GSSpacing.s8),
        const Text('Procesando pago...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s3),
        const Text('Acerca tu teléfono al validador',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s8),
        const CircularProgressIndicator(color: GSColors.accent),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.detail,
    required this.badgeLabel,
    required this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String detail;
  final String badgeLabel;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 64, color: iconColor),
        ),
        const SizedBox(height: GSSpacing.s5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          child: Text(badgeLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.5)),
        ),
        const SizedBox(height: GSSpacing.s5),
        Text(title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s2),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s6),
        GSCard(
          padding: const EdgeInsets.all(GSSpacing.s5),
          shadow: GSShadow.md,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monto',
                        style: TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                    Text(amount,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: GSColors.textPrimary)),
                    Text(detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: GSColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: GSSpacing.s3),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: GSColors.accentLight,
                  borderRadius: BorderRadius.all(Radius.circular(GSRadius.md)),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: GSColors.accent, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: GSColors.surfaceDark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded,
              size: 64, color: GSColors.textSecondary),
        ),
        const SizedBox(height: GSSpacing.s5),
        const Text('Sin conexión',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s3),
        const Text(
          'El pago NFC no está disponible sin internet.\nPuedes usar un código QR temporal.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: GSColors.textSecondary),
        ),
        const SizedBox(height: GSSpacing.s6),
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.lg),
            boxShadow: GSShadow.md,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_2_rounded,
                  size: 120, color: GSColors.textPrimary),
              Text('Expira en 5:00',
                  style: TextStyle(
                      fontSize: 11, color: GSColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Debug-only state switcher ────────────────────────────────────────────────

class _DemoSwitcher extends StatelessWidget {
  const _DemoSwitcher({required this.onSelect});
  final ValueChanged<PaymentValidationState> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
      child: Row(
        children: [
          const Text('Demo: ',
              style: TextStyle(fontSize: 11, color: GSColors.textDisabled)),
          _DemoChip('✓ OK', () => onSelect(PaymentValidationState.authorized)),
          _DemoChip('\$ Bajo', () => onSelect(PaymentValidationState.insufficient)),
          _DemoChip('✗ Error', () => onSelect(PaymentValidationState.error)),
          _DemoChip('Offline', () => onSelect(PaymentValidationState.offline)),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: GSColors.surfaceDark,
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: GSColors.textSecondary)),
      ),
    );
  }
}

// ─── Payment success animation widgets ───────────────────────────────────────

class _AnimatedCheckmark extends StatefulWidget {
  const _AnimatedCheckmark({
    required this.controller,
    required this.color,
  });

  final AnimationController controller;
  final Color color;

  @override
  State<_AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<_AnimatedCheckmark> {
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (_, __) => CustomPaint(
        size: const Size(64, 64),
        painter: _CheckmarkPainter(
          progress: _curved.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.3);

    final metrics = path.computeMetrics().first;
    final drawn = metrics.extractPath(0, metrics.length * progress);

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

class _AnimatedParticleBurst extends StatefulWidget {
  const _AnimatedParticleBurst({
    required this.controller,
  });

  final AnimationController controller;

  @override
  State<_AnimatedParticleBurst> createState() => _AnimatedParticleBurstState();
}

class _AnimatedParticleBurstState extends State<_AnimatedParticleBurst> {
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = CurvedAnimation(
      parent: widget.controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      builder: (_, __) => CustomPaint(
        size: const Size(200, 200),
        painter: _ParticleBurstPainter(progress: _curved.value),
      ),
    );
  }
}

class _ParticleBurstPainter extends CustomPainter {
  const _ParticleBurstPainter({required this.progress});

  final double progress;
  static const _count = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final distance = 60 * Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * pi;
      final color = i.isEven ? GSColors.success : GSColors.accent;

      canvas.save();
      canvas.translate(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 4, height: 12),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress;
}
