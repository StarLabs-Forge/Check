// Guarda un PNG en el dispositivo. En web dispara la descarga del navegador; en
// otras plataformas devuelve `false` (no hay descarga sin dependencias nuevas).
export 'save_png_stub.dart' if (dart.library.js_interop) 'save_png_web.dart';
