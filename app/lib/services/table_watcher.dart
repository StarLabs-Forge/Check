import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Suscripción Realtime a cambios de tablas públicas (`events`, `tickets`).
/// Realtime respeta RLS: el admin solo recibe cambios de sus propios eventos.
///
/// Agrupa ráfagas de cambios (p. ej. varios escaneos seguidos) en una sola
/// llamada a [onChange] con un debounce corto.
class TableWatcher {
  TableWatcher({
    required this.tables,
    required this.onChange,
    this.debounce = const Duration(milliseconds: 400),
  });

  final List<String> tables;
  final void Function() onChange;
  final Duration debounce;

  RealtimeChannel? _channel;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    final client = Supabase.instance.client;
    var channel = client.channel('watch-${DateTime.now().microsecondsSinceEpoch}');
    for (final table in tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _schedule(),
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (!_disposed) onChange();
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
  }
}
