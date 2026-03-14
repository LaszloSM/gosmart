import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';
import '../../services/ai_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [
    const _Message(
      text: 'Hi! I\'m your GoSmart AI assistant. Tell me where you want to go and I\'ll plan the best route for you.',
      isUser: false,
    ),
  ];
  bool _isTyping = false;

  static const _suggestions = [
    'Best route from Makati to BGC now',
    'Cheapest way to get to the airport',
    'Eco-friendly route to SM North',
    'How much does the metro cost?',
  ];

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

    setState(() {
      _messages.add(_Message(text: msg, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await aiService.sendMessage(query: msg);
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_Message(
            text: reply.content,
            isUser: false,
            hasRouteCard: reply.routes != null && reply.routes!.isNotEmpty,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(const _Message(
            text: 'Error al contactar el asistente. Intenta de nuevo.',
            isUser: false,
          ));
        });
      }
    }
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
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Always online',
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
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(GSSpacing.s5),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isTyping) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: _messages[i]);
              },
            ),
          ),

          // Suggestions (only show when few messages)
          if (_messages.length <= 2)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s5),
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

          // Input
          _ChatInput(ctrl: _ctrl, onSend: _send),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
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
              decoration: BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: GSColors.accent, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
                  decoration: BoxDecoration(
                    color: isUser ? GSColors.primary : GSColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(GSRadius.lg),
                      topRight: const Radius.circular(GSRadius.lg),
                      bottomLeft: Radius.circular(isUser ? GSRadius.lg : 4),
                      bottomRight: Radius.circular(isUser ? 4 : GSRadius.lg),
                    ),
                    boxShadow: GSShadow.sm,
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      
                      fontSize: 14,
                      color: isUser ? Colors.white : GSColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (message.hasRouteCard) ...[
                  const SizedBox(height: GSSpacing.s2),
                  _RouteQuickCard(),
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

class _RouteQuickCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('View on map',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: GSColors.accent)),
              Text('Tap to open route',
                  style: TextStyle(
                      fontSize: 11, color: GSColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

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
          decoration: BoxDecoration(
              color: GSColors.accentLight, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded,
              color: GSColors.accent, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  final val = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.full),
          border: Border.all(color: GSColors.border),
        ),
        child: Text(label,
            style: const TextStyle(
                
                fontSize: 13,
                color: GSColors.textPrimary)),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  const _ChatInput({required this.ctrl, required this.onSend});
  final TextEditingController ctrl;
  final VoidCallback onSend;

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
                hintText: 'Ask anything...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle( fontSize: 15),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: GSColors.accent,
                shape: BoxShape.circle,
                boxShadow: GSShadow.primary,
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

class _Message {
  final String text;
  final bool isUser;
  final bool hasRouteCard;
  const _Message({
    required this.text,
    required this.isUser,
    this.hasRouteCard = false,
  });
}
