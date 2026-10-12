// test/models/sync_queue_test.dart
// La cola offline: sin duplicados, reintenta, descarta lo viejo o imposible.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

SyncOp _op(String key, {String kind = 'sos', DateTime? at}) => SyncOp(
    kind: kind, key: key, payload: {'k': key}, createdAt: at ?? DateTime.now());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('misma llave no se encola dos veces', () async {
    final q = SyncQueue();
    await q.enqueue(_op('a'));
    await q.enqueue(_op('a'));
    expect((await q.pending()).length, 1);
  });

  test('envía en orden y deja solo lo que falló, con un intento más', () async {
    final sent = <String>[];
    final q = SyncQueue(handlers: {
      'sos': (op) async {
        if (op.key == 'b') throw Exception('sin red');
        sent.add(op.key);
        return true;
      },
    });
    for (final k in ['a', 'b', 'c']) {
      await q.enqueue(_op(k));
    }
    expect(await q.flush(), 1);
    expect(sent, ['a', 'c']);
    final left = await q.pending();
    expect(left.single.key, 'b');
    expect(left.single.attempts, 1);
  });

  test('sobrevive a reiniciar la app (se guarda en disco)', () async {
    await SyncQueue().enqueue(_op('x'));
    expect((await SyncQueue().pending()).single.key, 'x');
  });

  test('descarta lo de hace más de 2 días y lo que agotó intentos', () async {
    final q = SyncQueue(handlers: {'sos': (_) async => false});
    await q.enqueue(_op('viejo', at: DateTime.now().subtract(const Duration(days: 3))));
    await q.enqueue(_op('terco'));
    for (var i = 0; i < SyncQueue.maxAttempts; i++) {
      await q.flush();
    }
    expect(await q.pending(), isEmpty);
  });

  test('un tipo sin handler espera en vez de perderse', () async {
    final q = SyncQueue();
    await q.enqueue(_op('r', kind: 'road_report'));
    expect(await q.flush(), 1);
    expect((await q.pending()).single.attempts, 0);
  });
}
