import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:qr_flutter/qr_flutter.dart';

/// PNG de un QR con fondo blanco y margen (zona de silencio), apto para escanear.
Future<Uint8List> qrPng(String data, {double size = 600}) async {
  const margin = 40.0;
  final painter = QrPainter(data: data, version: QrVersions.auto, gapless: true);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, size, size), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.translate(margin, margin);
  painter.paint(canvas, ui.Size.square(size - margin * 2));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
