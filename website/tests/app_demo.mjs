// Navegación de la app Flutter (build DEMO) en un navegador real.
//   flutter build web --dart-define=DEMO=true --output=build/web-demo   (desde app/)
//   node website/tests/app_demo.mjs [carpeta-capturas]
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, reporter, serve, sleep } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'app', 'build', 'web-demo');
if (!existsSync(join(root, 'main.dart.js'))) throw new Error('Falta el build demo en app/build/web-demo.');
const shots = process.argv[2];
const { server, url } = await serve(root);
const page = await launch();
const t = reporter();

// Flutter dibuja en un lienzo: se activa su árbol de accesibilidad para leer textos.
const text = async () => {
  await page.eval(`document.querySelector('flt-semantics-placeholder')?.click()`);
  await sleep(800);
  return page.eval(`[...document.querySelectorAll('flt-semantics, flt-semantics span, input, [aria-label]')]
    .map(e => e.getAttribute('aria-label') || e.textContent).join(' | ')`);
};
const waitFor = async (needle, seconds = 40) => {
  let found = '';
  for (let i = 0; i < seconds / 2; i++) {
    found = await text();
    if (found.includes(needle)) return true;
    await sleep(1200);
  }
  return false;
};
const hash = () => page.eval('location.hash');
const step = async (name, needle, expectedHash) => {
  const seen = await waitFor(needle);
  const h = await hash();
  t.check(name, seen && h.startsWith(expectedHash), `ruta ${h}${seen ? '' : `, no se leyó «${needle}»`}`);
};
const shot = async (name) => { if (shots) await page.screenshot(join(shots, name)); };

try {
  await page.viewport(1366, 768);
  await page.goto(`${url}/#/registro?origen=prueba`, 3000);
  await step('enlace directo al registro con contexto de prueba', 'prueba gratuita', '#/registro');
  await shot('app-registro-escritorio.png');

  await page.eval(`location.hash = '#/login'`);
  await sleep(2500);
  await step('ruta de inicio de sesión', 'Continuar con Google', '#/login');
  await page.history(-1, 2500);
  await step('retroceso vuelve al registro', 'Crea tu cuenta', '#/registro');
  if (await page.history(+1, 2500)) {
    await step('avance vuelve al inicio de sesión', 'Continuar con Google', '#/login');
  } else {
    t.check('avance del navegador', false, 'no hay entrada hacia delante tras retroceder (historial de Flutter)');
  }

  await page.viewport(390, 844, true);
  await page.goto(`${url}/#/acceso-locales`, 3000);
  await step('móvil: dirección antigua del selector → iniciar sesión', 'Continuar con Google', '#/acceso-locales');
  await shot('app-login-movil.png');
  await page.goto(`${url}/#/comprar`, 3000);
  await step('móvil: catálogo del comprador', 'Mi pedido', '#/comprar');
  await shot('app-catalogo-movil.png');
  await page.goto(`${url}/#/superadmin`, 3000);
  await sleep(2000);
  t.check('ruta privada sin sesión redirige a iniciar sesión', (await hash()).startsWith('#/login'), await hash());
  t.check('sin errores de JavaScript', page.errors.length === 0, page.errors.slice(0, 2).join(' | ').slice(0, 200));
} finally {
  page.close();
  server.close();
}
process.exit(t.done() ? 1 : 0);
