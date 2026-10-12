// lib/features/ai_chat/ai_chat_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/design_tokens.dart';
import '../../providers/ai_conversation_provider.dart';
import '../../models/ai_models.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../core/money.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_toast.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  LatLng? _currentLocation;

  static const _suggestions = [
    '¿Cómo llego a Maicao desde el centro?',
    '¿Cuánto vale el TransPadilla?',
    '¿Está abierta la Troncal hoy?',
    '¿Cuánto debería costar un mototaxi al terminal?',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      if (mounted) {
        setState(() => _currentLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final msg = text ?? _ctrl.text.trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    // Scroll immediately so the user's own message is visible before the reply.
    _scrollToBottom();
    await ref.read(aiConversationProvider.notifier).send(
      msg,
      selectedMode: ref.read(selectedModeProvider),
      userLatLng: _currentLocation,
    );
    // Scroll again once the assistant reply is appended.
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients || !mounted) return;
      final end = _scrollCtrl.position.maxScrollExtent;
      if (MediaQuery.of(context).disableAnimations) {
        _scrollCtrl.jumpTo(end);
      } else {
        _scrollCtrl.animateTo(end,
            duration: GSDuration.normal, curve: GSCurve.enter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiConversationProvider);

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Asistente')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(GSSpacing.s4),
              itemCount: state.messages.length + (state.isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == state.messages.length && state.isTyping) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: state.messages[i]);
              },
            ),
          ),
          if (state.messages.length <= 2)
            SizedBox(
              height: GSSize.touchTarget,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: GSSpacing.s2),
                itemBuilder: (_, i) => _SuggestionChip(
                  label: _suggestions[i],
                  onTap: () => _send(_suggestions[i]),
                ),
              ),
            ),
          const SizedBox(height: GSSpacing.s2),
          _ChatInput(
            ctrl: _ctrl,
            onSend: _send,
            canSend: _ctrl.text.trim().isNotEmpty,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + GSSpacing.s2),
        ],
      ),
    );
  }
}

// ── Burbuja ───────────────────────────────────────────────────────────────────

class _MessageBubble extends ConsumerStatefulWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  /// Índice en message.routeResults: 0 = a pie, 1 = por la vía, 2 = en bici.
  int _selectedRouteIdx = 1;

  static const _routeLabels = ['A pie', 'Por la vía', 'En bici'];
  static const _routeIcons = [
    Icons.directions_walk_rounded,
    Icons.two_wheeler_rounded,
    Icons.pedal_bike_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == 'user';
    final isEstimated =
        message.source == 'heuristic' || message.source == 'cache';
    final maxWidth = MediaQuery.of(context).size.width * 0.82;
    const r = Radius.circular(GSRadius.lg);
    const tail = Radius.circular(GSRadius.sm);

    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: isUser
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                            ClipboardData(text: message.content));
                        GSToast.showWithMessenger(messenger,
                            message: 'Copiado', type: GSToastType.info);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
                  decoration: BoxDecoration(
                    color: isUser ? GSColors.brand : GSColors.surface,
                    border: isUser ? null : Border.all(color: GSColors.line),
                    borderRadius: BorderRadius.only(
                      topLeft: r,
                      topRight: r,
                      bottomLeft: isUser ? r : tail,
                      bottomRight: isUser ? tail : r,
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 17,
                      height: 1.45,
                      color: isUser ? GSColors.onBrand : GSColors.text,
                    ),
                  ),
                ),
              ),
              if (isEstimated) ...[
                const SizedBox(height: GSSpacing.s1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: GSColors.textMuted),
                    const SizedBox(width: GSSpacing.s1),
                    Text(
                      message.source == 'cache'
                          ? 'Respuesta guardada, sin conexión'
                          : 'Estimado, sin el asistente en línea',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              if (message.routes != null && message.routes!.isNotEmpty) ...[
                const SizedBox(height: GSSpacing.s2),
                _RoutePlate(routes: message.routes!, isEstimated: isEstimated),
              ],
              if (message.routeResults != null) ...[
                const SizedBox(height: GSSpacing.s3),
                Wrap(
                  spacing: GSSpacing.s2,
                  runSpacing: GSSpacing.s2,
                  children: [
                    for (var i = 0; i < 3; i++)
                      if (message.routeResults![i] != null)
                        ChoiceChip(
                          avatar: Icon(_routeIcons[i], size: 18),
                          label: Text(
                              '${_routeLabels[i]} · ${message.routeResults![i]!.durationMin} min'),
                          selected: _selectedRouteIdx == i,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _selectedRouteIdx = i),
                        ),
                  ],
                ),
                const SizedBox(height: GSSpacing.s2),
                GSButton(
                  label: 'Ver en el mapa',
                  leadingIcon: Icons.map_outlined,
                  isFullWidth: false,
                  onPressed: message.routeResults![_selectedRouteIdx] != null
                      ? () {
                          ref.read(activeRouteProvider.notifier).state =
                              message.routeResults![_selectedRouteIdx];
                          context.go(AppRoutes.home);
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ruta sugerida como placa ─────────────────────────────────────────────────

class _RoutePlate extends StatelessWidget {
  const _RoutePlate({required this.routes, required this.isEstimated});
  final List<RouteOption> routes;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final fastest = routes.firstWhere(
      (r) => r.type == 'fastest',
      orElse: () => routes.first,
    );
    return GSRoutePlate(
      text: '${fastest.totalDurationMin} min',
      leading: Icons.route_rounded,
      size: GSPlateSize.sm,
      detail: '${formatCop(fastest.totalCostCop)}'
          '${isEstimated ? ' · estimado' : ''}',
    );
  }
}

// ── Escribiendo… ─────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
    return Semantics(
      label: 'El asistente está escribiendo',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: GSSpacing.s4, vertical: GSSpacing.s4),
          decoration: BoxDecoration(
            color: GSColors.surface,
            border: Border.all(color: GSColors.line),
            borderRadius: BorderRadius.circular(GSRadius.lg),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Onda suave (sin el salto de un diente de sierra).
                final v = still
                    ? 0.5
                    : 0.5 - 0.5 * math.cos(2 * math.pi * ((_ctrl.value - i / 3) % 1));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color.lerp(GSColors.line, GSColors.brand, v),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sugerencia ───────────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GSColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GSRadius.sm),
        side: BorderSide(color: GSColors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s3),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: GSColors.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Campo de mensaje ─────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  const _ChatInput({
    required this.ctrl,
    required this.onSend,
    required this.canSend,
  });
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final bool canSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontFamily: GSFonts.sans, fontSize: 17),
              decoration: const InputDecoration(
                hintText: 'Escribe tu pregunta',
              ),
              onSubmitted: (_) {
                if (canSend) onSend();
              },
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          IconButton.filled(
            tooltip: 'Enviar',
            onPressed: canSend ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: GSColors.brand,
              foregroundColor: GSColors.onBrand,
              disabledBackgroundColor: GSColors.surfaceSunken,
              disabledForegroundColor: GSColors.textDisabled,
              minimumSize: const Size(52, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GSRadius.md)),
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
