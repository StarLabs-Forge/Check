import 'package:check/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fmt (hora de La Paz, UTC-4)', () {
    test('fromLaPaz y toLaPaz son inversas', () {
      final utc = Fmt.fromLaPaz(2026, 10, 1, 22, 0);
      expect(utc, DateTime.utc(2026, 10, 2, 2, 0));
      expect(Fmt.time(utc), '22:00');
      expect(Fmt.date(utc), '1 Oct 2026');
    });

    test('iniciales', () {
      expect(Fmt.initials('Napoleón Flores'), 'NF');
      expect(Fmt.initials('  Dash '), 'D');
      expect(Fmt.initials(''), '?');
    });

    test('fecha larga', () {
      // 2026-10-01 15:00 UTC = 11:00 en La Paz (jueves)
      expect(Fmt.longToday(DateTime.utc(2026, 10, 1, 15)), 'Jueves, 1 de octubre de 2026');
    });
  });
}
