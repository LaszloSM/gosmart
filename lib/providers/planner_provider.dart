// lib/providers/planner_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/graph_service.dart';

/// Grafo de transporte (de Supabase o, sin señal, la copia guardada).
final transportGraphProvider =
    FutureProvider<GraphBundle>((ref) => graphService.load());
