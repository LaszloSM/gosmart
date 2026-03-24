// lib/features/ai_chat/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';
import '../../providers/ai_conversation_provider.dart';
import '../../models/ai_models.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/gs_button.dart';
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
    '¿Cuánto cuesta el Metro de Medellín?',
    '¿Cómo voy al centro en TransMilenio?',
    'Horario del TransMilenio',
    'Ruta más económica en Bogotá',
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
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: GSDuration.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiConversationProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: GSColors.accent, size: 18),
            ),
            const SizedBox(width: GSSpacing.s2),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GoSmart AI',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Siempre disponible',
                    style: TextStyle(
                        fontSize: 11,
                        color: GSColors.eco,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(GSSpacing.s5),
              itemCount:
                  state.messages.length + (state.isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == state.messages.length && state.isTyping) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: state.messages[i]);
              },
            ),
          ),

          // Suggestion chips — only when few messages
          if (state.messages.length <= 2)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s5),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: GSSpacing.s2),
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
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends ConsumerStatefulWidget {
  const _MessageBubble({required this.message});
  final AiMessage message;

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  /// Index into message.routeResults: 0=walking, 1=driving, 2=cycling.
  /// Defaults to 1 (driving/bus) as the most common urban mode.
  int _selectedRouteIdx = 1;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == 'user';
    final isEstimated = message.source == 'heuristic' ||
        message.source == 'cache';

    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: GSSpacing.s2),
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: GSColors.accent, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: !isUser
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: message.content),
                          );
                          if (context.mounted) {
                            GSToast.show(
                              context,
                              message: 'Copiado al portapapeles',
                              type: GSToastType.info,
                            );
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: GSSpacing.s4,
                        vertical: GSSpacing.s3),
                    decoration: BoxDecoration(
                      color: isUser
                          ? GSColors.primary
                          : GSColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(GSRadius.lg),
                        topRight: const Radius.circular(GSRadius.lg),
                        bottomLeft: Radius.circular(
                            isUser ? GSRadius.lg : 4),
                        bottomRight: Radius.circular(
                            isUser ? 4 : GSRadius.lg),
                      ),
                      boxShadow: GSShadow.sm,
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isUser
                            ? Colors.white
                            : GSColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                // Heuristic / cache source badge
                if (isEstimated) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: GSColors.warning.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(GSRadius.full),
                      border: Border.all(
                          color: GSColors.warning
                              .withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 11, color: GSColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          message.source == 'cache'
                              ? 'Sin conexión'
                              : 'Estimado',
                          style: const TextStyle(
                              fontSize: 11,
                              color: GSColors.warning,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                // Route card
                if (message.routes != null &&
                    message.routes!.isNotEmpty) ...[
                  const SizedBox(height: GSSpacing.s2),
                  _RouteQuickCard(
                      routes: message.routes!,
                      isEstimated: isEstimated),
                ],
                // Real route chips + "Ver en mapa" button
                if (message.routeResults != null) ...[
                  const SizedBox(height: GSSpacing.s3),
                  Wrap(
                    spacing: GSSpacing.s2,
                    runSpacing: GSSpacing.s2,
                    children: List.generate(3, (i) {
                      final r = message.routeResults![i];
                      const labels = ['Caminando', 'Auto/Bus', 'Bici'];
                      const icons = [
                        Icons.directions_walk_rounded,
                        Icons.directions_bus_rounded,
                        Icons.pedal_bike_rounded,
                      ];
                      final label = r != null
                          ? '${labels[i]} · ${r.durationMin} min'
                          : '${labels[i]} · N/D';
                      return ChoiceChip(
                        avatar: Icon(icons[i], size: 14),
                        label: Text(label,
                            style: const TextStyle(fontSize: 12)),
                        selected: _selectedRouteIdx == i,
                        onSelected: r != null
                            ? (_) => setState(() => _selectedRouteIdx = i)
                            : null,
                      );
                    }),
                  ),
                  const SizedBox(height: GSSpacing.s2),
                  GSButton(
                    label: 'Ver en mapa',
                    leadingIcon: Icons.map_rounded,
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
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Route quick card ──────────────────────────────────────────────────────────

class _RouteQuickCard extends StatelessWidget {
  const _RouteQuickCard(
      {required this.routes, required this.isEstimated});
  final List<RouteOption> routes;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final fastest = routes.firstWhere(
      (r) => r.type == 'fastest',
      orElse: () => routes.first,
    );

    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s3),
      shadow: GSShadow.md,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GSColors.accentLight,
              borderRadius: BorderRadius.circular(GSRadius.sm),
            ),
            child: const Icon(Icons.route_rounded,
                color: GSColors.accent, size: 18),
          ),
          const SizedBox(width: GSSpacing.s3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fastest.totalDurationMin} min · \$${fastest.totalCostCop} COP',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: GSColors.accent),
              ),
              Text(
                isEstimated ? 'Tiempo estimado' : 'Ver en el mapa',
                style: const TextStyle(
                    fontSize: 11,
                    color: GSColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(
              color: GSColors.accentLight, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded,
              color: GSColors.accent, size: 16),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.lg),
            boxShadow: GSShadow.sm,
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.33;
                  final val =
                      ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                          GSColors.border, GSColors.accent, val),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.full),
          border: Border.all(color: GSColors.border),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, color: GSColors.textPrimary)),
      ),
    );
  }
}

// ── Chat input ────────────────────────────────────────────────────────────────

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.full),
        boxShadow: GSShadow.md,
        border: Border.all(color: GSColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Pregunta sobre rutas y transporte...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              onSubmitted: (_) {
                if (canSend) onSend();
              },
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          GestureDetector(
            onTap: canSend ? onSend : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend ? GSColors.accent : GSColors.border,
                shape: BoxShape.circle,
                boxShadow: canSend ? GSShadow.primary : null,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
