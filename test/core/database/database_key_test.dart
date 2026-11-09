import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:poop_tracker/core/security/database_key.dart';

void main() {
  test('generated keys are 32 bytes and differ', () {
    final a = DatabaseKey.generate();
    final b = DatabaseKey.generate();
    expect(a.bytes, hasLength(32));
    expect(a.sameAs(b), isFalse);
  });

  test('encode and decode round-trip', () {
    final k = DatabaseKey.generate(Random(3));
    expect(DatabaseKey.decode(k.encode()).sameAs(k), isTrue);
  });

  test('hex is 64 lower-case characters', () {
    final k = DatabaseKey(List<int>.generate(32, (i) => i * 8));
    expect(k.toHex(), matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(k.toHex().substring(0, 6), '000810');
  });

  test('wrong lengths and damaged values are rejected', () {
    expect(() => DatabaseKey(List<int>.filled(31, 0)), throwsArgumentError);
    expect(() => DatabaseKey.decode('AAAA'), throwsFormatException);
    expect(() => DatabaseKey.decode('not base64!'), throwsFormatException);
  });

  test('never prints key material', () {
    final k = DatabaseKey.generate(Random(4));
    expect(k.toString(), isNot(contains(k.toHex())));
    expect(k.toString(), isNot(contains(k.encode())));
  });

  test('changing the source list does not change the key', () {
    final source = List<int>.filled(32, 1);
    final k = DatabaseKey(source);
    source[0] = 99;
    expect(k.bytes[0], 1);
  });
}
