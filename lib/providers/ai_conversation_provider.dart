// lib/providers/ai_conversation_provider.dart
import 'package:flutter/foundation.dart'; // for @visibleForTesting
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/ai_service.dart';
import '../models/ai_models.dart';

const _welcomeMessage = 'Hola! Soy tu asistente GoSmart. '
    'Dime a dónde quieres ir y te planearé la mejor ruta.';

// ── State ─────────────────────────────────────────────────────────────────────

class AiConversationState {
  final List<AiMessage> messages;
  final List<ConversationTurn> history; // last ≤10 turns — sent to backend
  final List<RouteOption> recentRoutes; // offline fallback cache
  final bool isTyping;

  const AiConversationState({
    this.messages = const [],
    this.history = const [],
    this.recentRoutes = const [],
    this.isTyping = false,
  });

  AiConversationState copyWith({
    List<AiMessage>? messages,
    List<ConversationTurn>? history,
    List<RouteOption>? recentRoutes,
    bool? isTyping,
  }) =>
      AiConversationState(
        messages: messages ?? this.messages,
        history: history ?? this.history,
        recentRoutes: recentRoutes ?? this.recentRoutes,
        isTyping: isTyping ?? this.isTyping,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AiConversationNotifier extends StateNotifier<AiConversationState> {
  AiConversationNotifier()
      : super(AiConversationState(
          messages: [
            AiMessage(
              role: 'assistant',
              content: _welcomeMessage,
              timestamp: DateTime.now(),
            ),
          ],
        ));

  /// Send a user message and receive an assistant reply.
  /// The notifier reads state.history and passes it to sendMessage() —
  /// the screen never constructs or passes history directly.
  Future<void> send(String query, {String? selectedMode, LatLng? userLatLng}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(role: 'user', content: trimmed, timestamp: DateTime.now()),
      ],
      isTyping: true,
    );

    try {
      final reply = await aiService.sendMessage(
        query: trimmed,
        history: state.history,
        selectedMode: selectedMode,
        userLatLng: userLatLng,
      );

      // Build updated history and trim to last 10 turns
      final updatedHistory = [
        ...state.history,
        ConversationTurn(role: 'user', content: trimmed),
        ConversationTurn(role: 'assistant', content: reply.content),
      ];
      final trimmedHistory = updatedHistory.length > 10
          ? updatedHistory.sublist(updatedHistory.length - 10)
          : updatedHistory;

      state = state.copyWith(
        messages: [...state.messages, reply],
        history: trimmedHistory,
        recentRoutes: reply.routes ?? state.recentRoutes,
        isTyping: false,
      );
    } catch (_) {
      // Layer 2 fallback: if the function is unreachable, serve cached routes
      final offlineReply = AiMessage(
        role: 'assistant',
        content: state.recentRoutes.isNotEmpty
            ? 'Sin conexión. Mostrando tu última ruta guardada.'
            : 'Error al contactar el asistente. Intenta de nuevo.',
        timestamp: DateTime.now(),
        routes: state.recentRoutes.isNotEmpty ? state.recentRoutes : null,
        source: state.recentRoutes.isNotEmpty ? 'cache' : null,
      );

      state = state.copyWith(
        messages: [...state.messages, offlineReply],
        isTyping: false,
      );
    }
  }

  /// Reset the conversation. Call this from a "New conversation" button.
  void resetConversation() {
    state = AiConversationState(
      messages: [
        AiMessage(
          role: 'assistant',
          content: _welcomeMessage,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  /// Inject state for unit testing without triggering a network call.
  /// The @visibleForTesting annotation causes flutter analyze to warn if
  /// this method is called from non-test code.
  @visibleForTesting
  void injectStateForTesting({
    List<ConversationTurn>? history,
    List<RouteOption>? recentRoutes,
  }) {
    state = state.copyWith(
      history: history ?? state.history,
      recentRoutes: recentRoutes ?? state.recentRoutes,
    );
  }

  /// Simulate appending a user+assistant turn to history (tests history trimming).
  @visibleForTesting
  void appendToHistoryForTesting({
    required String query,
    required String reply,
  }) {
    final updated = [
      ...state.history,
      ConversationTurn(role: 'user', content: query),
      ConversationTurn(role: 'assistant', content: reply),
    ];
    final trimmed =
        updated.length > 10 ? updated.sublist(updated.length - 10) : updated;
    state = state.copyWith(history: trimmed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Not autoDispose — history persists across screen pops for the session.
/// Resets only on resetConversation() or app restart.
final aiConversationProvider =
    StateNotifierProvider<AiConversationNotifier, AiConversationState>(
  (ref) => AiConversationNotifier(),
);
