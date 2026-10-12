// test/planner/fixture_graph.dart
// Mismo grafo semilla que supabase/migrations/014_transport_graph.sql
// (coordenadas, tiempos y tarifas APROXIMADOS, para probar el planificador).
import 'package:gosmart/planner/graph.dart';
import 'package:latlong2/latlong.dart';

const troncal = [
  'troncal-00-10', 'troncal-10-20', 'troncal-20-30', 'troncal-30-40',
  'troncal-40-50', 'troncal-50-60', 'troncal-60-75',
];

List<GraphEdge> both(String a, String b, TransitMode m, int min, int wait,
        int fMin, int fMax, {List<String> segs = const [], bool night = true}) =>
    [
      GraphEdge(from: a, to: b, mode: m, minutes: min, waitMinutes: wait,
          fareMin: fMin, fareMax: fMax, segmentIds: segs, nightOk: night),
      GraphEdge(from: b, to: a, mode: m, minutes: min, waitMinutes: wait,
          fareMin: fMin, fareMax: fMax,
          segmentIds: segs.reversed.toList(), nightOk: night),
    ];

final fixtureGraph = TransportGraph(
  nodes: const [
    GraphNode(id: 'rio-centro', name: 'Parque Padilla', at: LatLng(11.5441, -72.9071)),
    GraphNode(id: 'rio-terminal', name: 'Terminal de Riohacha', at: LatLng(11.5330, -72.9125), kind: 'terminal'),
    GraphNode(id: 'rio-uniguajira', name: 'Universidad de La Guajira', at: LatLng(11.5275, -72.8880)),
    GraphNode(id: 'mai-terminal', name: 'Terminal de Maicao', at: LatLng(11.3790, -72.2370), kind: 'terminal'),
    GraphNode(id: 'mai-centro', name: 'Centro de Maicao', at: LatLng(11.3780, -72.2405)),
    GraphNode(id: 'cuestecitas', name: 'Cuestecitas', at: LatLng(11.2050, -72.6160)),
    GraphNode(id: 'albania', name: 'Albania', at: LatLng(11.1610, -72.5920)),
  ],
  edges: [
    ...both('rio-centro', 'rio-uniguajira', TransitMode.transpadilla, 20, 10, 2500, 2500),
    ...both('rio-centro', 'rio-terminal', TransitMode.transpadilla, 10, 10, 2500, 2500),
    ...both('rio-terminal', 'mai-centro', TransitMode.colectivo, 70, 20, 12000, 15000,
        segs: troncal, night: false),
    ...both('rio-terminal', 'mai-terminal', TransitMode.intermunicipal, 75, 30, 13000, 16000,
        segs: troncal),
    ...both('rio-terminal', 'cuestecitas', TransitMode.intermunicipal, 60, 30, 12000, 15000),
    ...both('cuestecitas', 'albania', TransitMode.colectivo, 20, 15, 4000, 5000,
        segs: ['desvio-albania-cuestecitas']),
    ...both('albania', 'mai-terminal', TransitMode.colectivo, 40, 15, 8000, 10000),
    ...both('mai-terminal', 'mai-centro', TransitMode.walk, 5, 0, 0, 0),
  ],
);
