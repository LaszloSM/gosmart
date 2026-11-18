// test/core/address_test.dart
// Direcciones colombianas escritas a mano.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/address.dart';
import 'package:gosmart/core/city_rank.dart';
import 'package:gosmart/core/region.dart';

void main() {
  test('reconoce direcciones con número de casa', () {
    expect(looksLikeAddress('Calle 14 # 10-20'), isTrue);
    expect(looksLikeAddress('cl 14 #10-20'), isTrue);
    expect(looksLikeAddress('Cra 7 No. 12 - 30'), isTrue);
    expect(looksLikeAddress('calle 24 # 7h-45'), isTrue);
    expect(looksLikeAddress('Calle 14 #'), isFalse);
    expect(looksLikeAddress('Calle 14'), isFalse);
    expect(looksLikeAddress('Parque Padilla'), isFalse);
  });

  test('las escribe bonito y conserva el barrio', () {
    expect(normalizeAddress('cl 14 #10-20'), 'Calle 14 # 10-20');
    expect(normalizeAddress('Cra 7 No. 12 - 30'), 'Carrera 7 # 12-30');
    expect(normalizeAddress('calle 24 # 7h-45'), 'Calle 24 # 7H-45');
    expect(normalizeAddress('kr 15a #3-2 barrio Cooperativo'),
        'Carrera 15A # 3-2 barrio Cooperativo');
    expect(normalizeAddress('Uniguajira'), isNull);
  });

  test('a Google le llega la ciudad donde estás, si no nombras otra', () {
    expect(withCity('Calle 14', GSRegion.riohacha), 'Calle 14, Riohacha');
    expect(withCity('Calle 14', GSRegion.maicao), 'Calle 14, Maicao');
    expect(withCity('Terminal de Maicao', GSRegion.riohacha), 'Terminal de Maicao');
    expect(withCity('Salinas de Manaure', GSRegion.riohacha), 'Salinas de Manaure');
    expect(withCity('Calle 14', null), 'Calle 14');
  });

  test('la esquina según la nomenclatura colombiana', () {
    expect(crossingQuery('Calle 24 # 14-45'), 'Calle 24 & Carrera 14');
    expect(crossingQuery('cra 11 #9-20'), 'Carrera 11 & Calle 9');
    expect(crossingQuery('Calle 24 # 7h-45'), 'Calle 24 & Carrera 7H');
    expect(crossingQuery('Uniguajira'), isNull);
  });
}
