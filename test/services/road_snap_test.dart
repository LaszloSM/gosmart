import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/route_result.dart';
import 'package:gosmart/services/road_snap.dart';
import 'package:latlong2/latlong.dart';

RouteLeg _leg(String mode, LatLng a, LatLng b) => RouteLeg(
      mode: mode == 'walk' ? 'walk' : 'bus',
      transitMode: mode,
      points: [a, b],
      color: Colors.blue,
      durationMin: 10,
      distanceKm: 1,
    );

void main() {
  const a = LatLng(11.5441, -72.9071);
  const b = LatLng(11.5275, -72.8880);
  const mid = LatLng(11.536, -72.90);

  test('cambia el tramo recto por el trazado de la vía', () async {
    final calls = <bool>[];
    final s = RoadSnapper(route: (x, y, walking) async {
      calls.add(walking);
      return [x, mid, y];
    });
    final r = await s.snap(RouteResult(
      legs: [_leg('walk', a, b), _leg('colectivo', b, a)],
      distanceKm: 2,
      durationMin: 20,
      profile: 'driving',
    ));
    expect(calls, [true, false]); // a pie por andenes, lo demás por la vía
    expect(r.legs.first.points.length, greaterThan(2));
    expect(r.legs.first.points.first, a);
    expect(r.legs.first.points.last, b);
    expect(r.legs.first.transitMode, 'walk');
  });

  test('si Google no responde, el tramo queda recto y se reintenta', () async {
    var fail = true;
    final s = RoadSnapper(route: (x, y, w) async => fail ? null : [x, mid, y]);
    final leg = _leg('mototaxi', a, b);
    expect((await s.snapLeg(leg)).points, [a, b]);
    fail = false;
    expect((await s.snapLeg(leg)).points.length, greaterThan(2));
  });

  test('no vuelve a pedir un tramo ya trazado', () async {
    var n = 0;
    final s = RoadSnapper(route: (x, y, w) async {
      n++;
      return [x, mid, y];
    });
    await s.snapLeg(_leg('taxi', a, b));
    await s.snapLeg(_leg('taxi', a, b));
    expect(n, 1);
  });
}
