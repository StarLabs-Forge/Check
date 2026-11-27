import 'package:check/config/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const prod = 'https://${SupabaseConfig.productionRef}.supabase.co';
  const dev = 'https://abcdefghijklmnop.supabase.co';

  test('producción y desarrollo coherentes son válidos', () {
    expect(SupabaseConfig.problem(env: 'prod', url: prod), isNull);
    expect(SupabaseConfig.problem(env: 'dev', url: dev), isNull);
  });

  test('un build de desarrollo nunca puede apuntar a producción', () {
    expect(SupabaseConfig.problem(env: 'dev', url: prod), contains('producción'));
  });

  test('un build de producción no puede apuntar a otro proyecto', () {
    expect(SupabaseConfig.problem(env: 'prod', url: dev), isNotNull);
  });

  test('entornos desconocidos se rechazan', () {
    expect(SupabaseConfig.problem(env: 'qa', url: dev), isNotNull);
  });

  test('los valores por defecto son de producción y coherentes', () {
    expect(SupabaseConfig.problem(), isNull);
  });
}
