import 'package:check/config/demo_mode.dart';

/// Pruebas que dependen del modo DEMO (store simulado o CheckApp sin Supabase).
/// Sin `--dart-define=DEMO=true` se OMITEN declarando el motivo; con él se ejecutan.
///   flutter test                              -> unitarias y de componentes
///   flutter test --dart-define=DEMO=true      -> todo lo anterior + suites demo
String? get demoOnly => kDemo ? null : 'Requiere modo demo: flutter test --dart-define=DEMO=true';
