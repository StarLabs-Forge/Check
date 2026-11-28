// Navegación real del sitio público.  node website/tests/navigation.mjs [carpeta-capturas]
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, reporter, serve, sleep } from './browser.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const shots = process.argv[2];
const { server, url } = await serve(root);
const page = await launch();
const t = reporter();

// Distancia entre el inicio de la sección y el borde inferior del encabezado fijo.
const offset = (id) => page.eval(`(() => {
  const s = document.getElementById('${id}').getBoundingClientRect().top;
  const h = document.querySelector('header, .header, nav')?.getBoundingClientRect().height ?? 0;
  return Math.round(s - h) || 0; // evita -0, que el protocolo no serializa como número
})()`);
const state = () => page.eval('({ hash: location.hash, y: Math.round(scrollY) })');
const aligned = async (id) => {
  const d = await offset(id);
  const atBottom = await page.eval('Math.ceil(scrollY + innerHeight) >= document.documentElement.scrollHeight - 2');
  return { ok: Math.abs(d) <= 40 || (atBottom && d > 0), d };
};
// El desplazamiento suave dura lo que el equipo permita: se espera a que la
// posición quede quieta (1,5 s sin cambios), con un máximo de 25 s.
const settle = async () => {
  let last = -1;
  let still = 0;
  for (let i = 0; i < 100 && still < 6; i++) {
    await sleep(250);
    const y = await page.eval('Math.round(scrollY)');
    still = y === last ? still + 1 : 0;
    last = y;
  }
};
const click = async (selector) => {
  await page.eval(`document.querySelector('${selector}').click()`);
  await sleep(500);
  await settle();
};
const open = async (target) => { await page.goto(target); await settle(); };
const history = async (delta) => { await page.history(delta, 500); await settle(); };

try {
  await page.viewport(1366, 768);
  await page.goto(url + '/');
  t.check('carga en la parte superior', (await state()).y === 0);

  const visited = [];
  for (const id of ['como-funciona', 'modulos', 'planes', 'contacto', 'planes']) {
    await click(`a.nav-link[href="#${id}"]`);
    const a = await aligned(id);
    const s = await state();
    t.check(`menú → #${id}`, a.ok && s.hash === `#${id}`, `desfase ${a.d}px, y=${s.y}`);
    visited.push({ id, y: s.y });
  }
  const before = await state();
  await sleep(2500);
  t.check('no regresa sola a la bienvenida', Math.abs((await state()).y - before.y) <= 2);

  await history(-1);
  t.check('retroceso → sección anterior', (await state()).hash === '#contacto' && (await aligned('contacto')).ok, JSON.stringify(await state()));
  await history(-1);
  t.check('segundo retroceso', (await state()).hash === '#planes' && (await aligned('planes')).ok, JSON.stringify(await state()));
  await history(+1);
  t.check('avance', (await state()).hash === '#contacto' && (await aligned('contacto')).ok, JSON.stringify(await state()));

  for (const id of ['como-funciona', 'modulos', 'planes', 'contacto']) {
    await open(`${url}/#${id}`);
    const a = await aligned(id);
    t.check(`enlace directo /#${id}`, a.ok && (await state()).hash === `#${id}`, `desfase ${a.d}px`);
  }

  await page.goto(url + '/');
  await click('.hero-actions a[href="#como-funciona"]');
  t.check('botón del héroe «Ver cómo funciona»', (await aligned('como-funciona')).ok);
  await page.eval('scrollTo({ top: document.body.scrollHeight, behavior: "instant" })');
  await sleep(500);
  await click('footer a[href="#modulos"]');
  t.check('enlace del pie → #modulos', (await aligned('modulos')).ok);
  await click('a.logo');
  t.check('logo → parte superior', (await state()).y <= 2, JSON.stringify(await state()));

  const trial = await page.eval(`[...document.querySelectorAll('a')].find(a => a.textContent.trim() === 'Probar gratis')?.href`);
  t.check('«Probar gratis» → registro real con contexto de prueba', /#\/registro\?origen=prueba$/.test(trial ?? ''), trial);
  t.check('animaciones presentes', await page.eval('document.querySelectorAll(".reveal").length > 0 && !!document.querySelector(".tilt-3d")'));
  if (shots) { await page.goto(`${url}/#planes`, 3000); await page.screenshot(join(shots, 'web-planes-escritorio.png')); }
  console.log('-- móvil');

  await page.viewport(390, 844, true);
  await page.goto(url + '/', 2000);
  const overflow = await page.eval('document.documentElement.scrollWidth - innerWidth');
  t.check('móvil: sin desplazamiento horizontal', overflow <= 1, `exceso ${overflow}px`);
  t.check('móvil: menú de secciones oculto por diseño', await page.eval('getComputedStyle(document.querySelector(".nav-links")).display === "none"'));
  for (const id of ['como-funciona', 'planes', 'contacto']) {
    await open(`${url}/#${id}`);
    const a = await aligned(id);
    t.check(`móvil: enlace directo /#${id}`, a.ok, `desfase ${a.d}px`);
  }
  await page.goto(url + '/');
  await click('.hero-actions a[href="#como-funciona"]');
  t.check('móvil: botón del héroe', (await aligned('como-funciona')).ok);
  await history(-1);
  t.check('móvil: retroceso vuelve arriba', (await state()).y <= 2, JSON.stringify(await state()));
  if (shots) { await page.goto(`${url}/#planes`, 3000); await page.screenshot(join(shots, 'web-planes-movil.png')); }

  t.check('sin errores de JavaScript', page.errors.length === 0, page.errors.slice(0, 3).join(' | '));
} finally {
  page.close();
  server.close();
}
process.exit(t.done() ? 1 : 0);
