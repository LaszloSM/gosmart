// test/providers/ai_conversation_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosmart/providers/ai_conversation_provider.dart';
import 'package:gosmart/models/ai_models.dart';

void main() {
  group('AiConversationNotifier — initial state', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('has one welcome assistant message', () {
      final state = container.read(aiConversationProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.role, 'assistant');
    });

    test('history is empty', () {
      final state = container.read(aiConversationProvider);
      expect(state.history, isEmpty);
    });

    test('recentRoutes is empty', () {
      final state = container.read(aiConversationProvider);
      expect(state.recentRoutes, isEmpty);
    });

    test('isTyping is false', () {
      final state = container.read(aiConversationProvider);
      expect(state.isTyping, isFalse);
    });
  });

  group('AiConversationNotifier — resetConversation', () {
    test('clears history and recentRoutes, restores welcome message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiConversationProvider.notifier);

      // Manually inject state with history to simulate post-conversation state
      notifier.injectStateForTesting(
        history: [
          const ConversationTurn(role: 'user', content: '¿Cómo llego?'),
          const ConversationTurn(role: 'assistant', content: 'Toma el bus 22.'),
        ],
        recentRoutes: [
          const RouteOption(
            id: 'r1',
            type: 'fastest',
            totalDurationMin: 35,
            totalCostCop: 2900,
            totalCo2Kg: 0.4,
            legs: [],
          ),
        ],
      );

      notifier.resetConversation();
      final state = container.read(aiConversationProvider);

      expect(state.history, isEmpty);
      expect(state.recentRoutes, isEmpty);
      expect(state.messages.length, 1);
      expect(state.messages.first.role, 'assistant');
    });
  });

  group('AiConversationNotifier — history trimming', () {
    test('history never exceeds 10 turns', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(aiConversationProvider.notifier);

      // Inject 10 existing turns
      final existing = List.generate(
        10,
        (i) => ConversationTurn(role: i.isEven ? 'user' : 'assistant', content: 'msg $i'),
      );
      notifier.injectStateForTesting(history: existing);

      // Add 2 more turns (simulating what appendToHistory does)
      notifier.appendToHistoryForTesting(
        query: 'new question',
        reply: 'new answer',
      );

      final state = container.read(aiConversationProvider);
      expect(state.history.length, 10);
      // The oldest 2 turns should have been dropped
      expect(state.history.first.content, 'msg 2');
    });
  });
}
