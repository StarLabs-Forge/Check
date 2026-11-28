// Compra web con un backend simulado dentro del navegador (no toca ninguna base).
//   node website/tests/checkout.mjs
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, reporter, serve, sleep } from './browser.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const EVENT = '11111111-1111-4111-8111-111111111111';
const ORDER = '22222222-2222-4222-8222-222222222222';
const TOKEN = 'a'.repeat(64);

const mock = `(() => {
  const real = window.fetch.bind(window);
  const json = (body, status = 200) => Promise.resolve(new Response(JSON.stringify(body), { status }));
  const noConfig = location.search.includes('sinconfig');
  window.calls = [];
  window.backend = { status: 'awaiting_payment', fail: null, eventStatus: 'active' };
  window.fetch = (url, options) => {
    url = String(url);
    if (url.endsWith('config.local.json')) {
      return noConfig ? Promise.resolve(new Response('', { status: 404 }))
        : json({ supabaseUrl: 'https://dev.example.test', publishableKey: 'clave-de-prueba' });
    }
    if (!url.includes('/rest/v1/rpc/')) return real(url, options);
    const name = url.split('/rpc/')[1];
    const params = JSON.parse(options.body);
    window.calls.push({ url, name, params });
    const state = window.backend;
    if (name === 'public_events') return json([{ id: '${EVENT}', name: 'Evento <b>X</b>', status: 'active',
      starts_at: new Date(Date.now() + 864e5).toISOString(), ends_at: new Date(Date.now() + 9e7).toISOString(),
      venue_name: 'Local de prueba', types: [
        { id: 't1', name: 'General', price: 50, available: 200, max_per_order: 4 },
        { id: 't2', name: 'VIP', price: 100, available: 1, max_per_order: 6 },
        { id: 't3', name: 'Preventa', price: 30, available: 0, max_per_order: 6 }] }]);
    if (state.fail) { const message = state.fail; state.fail = null; return json({ message, hint: 'VIP' }, 400); }
    if (name === 'create_order') return json({ order_id: '${ORDER}', token: '${TOKEN}', number: 'CHK-1', total: 200,
      expires_at: new Date(Date.now() + 9e5).toISOString() });
    if (name === 'declare_payment') { state.status = 'verifying'; return json({ status: state.status }); }
    if (name === 'cancel_order') { state.status = 'cancelled'; return json({ status: state.status }); }
    const paying = ['awaiting_payment', 'verifying'].includes(state.status);
    return json({
      order: { id: '${ORDER}', number: 'CHK-1', status: state.status, total: 200, buyer_name: 'Persona Ficticia',
        expires_at: new Date(Date.now() + 9e5).toISOString(), reject_reason: 'No llegó el depósito' },
      event: { id: '${EVENT}', name: 'Evento <b>X</b>', starts_at: new Date(Date.now() + 864e5).toISOString(), status: state.eventStatus },
      venue: { name: 'Local de prueba' },
      bank: paying ? { beneficiary: 'Beneficiario Ficticio', bank_name: 'Banco de prueba', account: '000111' } : null,
      lines: [{ type_name: 'General', qty: 2 }, { type_name: 'VIP', qty: 1 }],
      tickets: state.status === 'approved' ? [
        { type_name: 'General', status: 'valid', qr_token: '${'b'.repeat(64)}' },
        { type_name: 'VIP', status: 'used', qr_token: '${'c'.repeat(64)}' }] : []
    });
  };
})();`;

const { server, url } = await serve(root);
const page = await launch();
const report = reporter();
const text = () => page.eval('document.querySelector("dialog.checkout")?.innerText ?? ""');
const press = (label) => page.eval(`(() => { const b = [...document.querySelectorAll('button')]
  .find(n => n.textContent.trim() === ${JSON.stringify(label)} && n.offsetParent !== null); b?.click(); return !!b; })()`);
const calls = (name) => page.eval(`window.calls.filter(c => c.name === ${JSON.stringify(name)})`);
const refresh = async (status) => {
  await page.eval(`window.backend.status = ${JSON.stringify(status)}; window.dispatchEvent(new HashChangeEvent('hashchange'))`);
  await sleep(700);
};

try {
  await page.send('Page.addScriptToEvaluateOnNewDocument', { source: mock });
  await page.viewport(390, 844, true);
  await page.goto(`${url}/eventos.html?evento=${EVENT}`);
  report.check('usa el backend de desarrollo en local', (await calls('public_events'))[0]?.url.startsWith('https://dev.example.test'));
  report.check('muestra «Comprar entradas»', await press('Comprar entradas'));
  await sleep(300);
  report.check('el nombre del evento no se interpreta como HTML', !(await page.eval('!!document.querySelector("dialog.checkout b")')));
  const options = await page.eval('[...document.querySelectorAll("dialog.checkout select")].map(s => [s.options.length, s.disabled])');
  report.check('cantidades limitadas por cupo y máximo', JSON.stringify(options) === '[[5,false],[2,false],[1,true]]', JSON.stringify(options));
  await page.eval(`for (const [id, v] of [['t1', '2'], ['t2', '1']]) {
    const s = document.querySelector('select[data-type="' + id + '"]'); s.value = v; s.dispatchEvent(new Event('change')); }`);
  report.check('calcula el total', (await text()).includes('3 entradas · Total Bs. 200'));
  await press('Continuar');
  await press('Reservar y ver cómo pagar');
  await sleep(300);
  report.check('no envía el formulario incompleto', (await calls('create_order')).length === 0);
  await page.eval(`for (const [n, v] of [['name', 'Persona Ficticia'], ['ci', '1234567'], ['phone', '70000000']]) {
    document.querySelector('dialog.checkout input[name="' + n + '"]').value = v; }
    window.backend.fail = 'sold_out';`);
  await press('Reservar y ver cómo pagar');
  await sleep(700);
  report.check('explica que no quedan cupos', (await text()).includes('Ya no quedan suficientes cupos. (VIP)'), '');
  await press('Reservar y ver cómo pagar');
  await sleep(1000);
  const sent = (await calls('create_order')).at(-1)?.params;
  report.check('envía categorías y cantidades', JSON.stringify(sent?.p_lines) === '[{"type_id":"t1","qty":2},{"type_id":"t2","qty":1}]' && sent.p_buyer_email === null);
  let body = await text();
  report.check('muestra los datos de pago del local', ['Beneficiario Ficticio', '000111', 'CHK-1', 'Ya pagué'].every((t) => body.includes(t)));
  report.check('muestra la cuenta regresiva', /1[45]:\d\d/.test(body));
  report.check('deja el enlace privado en la dirección', await page.eval(`location.hash === '#pedido=${ORDER}.${TOKEN}'`));
  report.check('sin desplazamiento horizontal en celular', await page.eval('(() => { const d = document.querySelector("dialog.checkout"); return d.scrollWidth <= d.clientWidth + 1; })()'));
  await press('Cancelar pedido');
  report.check('cancelar pide confirmación', (await calls('cancel_order')).length === 0 && (await text()).includes('Confirmar cancelación'));
  await press('Ya pagué');
  await sleep(800);
  report.check('«Ya pagué» pasa a verificación', (await calls('declare_payment')).length === 1 && (await text()).includes('Estamos verificando tu pago'));

  await refresh('approved');
  body = await text();
  report.check('aprobado: entradas con QR', body.includes('Entrada 1 de 2') && (await page.eval('document.querySelectorAll(".checkout-ticket img").length')) === 2);
  report.check('aprobado: avisa la entrada ya usada y oculta datos bancarios', body.includes('Ya se usó') && !body.includes('000111'));
  await page.eval('window.backend.eventStatus = "draft"');
  await refresh('approved');
  report.check('avisa si el evento aún no está activo', (await text()).includes('todavía no está activo'));
  await refresh('rejected');
  report.check('rechazado: muestra el motivo', (await text()).includes('No llegó el depósito'));
  await refresh('expired');
  report.check('vencido', (await text()).includes('El pedido venció'));

  await refresh('awaiting_payment');
  await press('Cancelar pedido');
  await press('Confirmar cancelación');
  await sleep(800);
  report.check('cancelación confirmada', (await text()).includes('Pedido cancelado'));
  await press('Cerrar');
  await sleep(300);
  report.check('al cerrar limpia el código de la dirección', await page.eval('location.hash === ""'));
  report.check('el pedido queda en «Mis pedidos»', await page.eval('document.querySelector(".catalog-orders")?.innerText.includes("CHK-1")'));

  await page.goto(`${url}/eventos.html?sinconfig=1&evento=${EVENT}`);
  report.check('en local sin configuración no permite comprar',
    (await page.eval('document.body.innerText.includes("Compra desactivada")')) && !(await press('Comprar entradas')));

  await page.goto(`${url}/eventos.html?evento=referencia-tusuy`);
  await press('Probar compra');
  await sleep(300);
  report.check('la simulación de referencia sigue funcionando', await page.eval('!!document.querySelector("dialog.checkout-demo[open] select[name=type]")'));
  report.check('sin errores de JavaScript', page.errors.length === 0, page.errors.join(' | '));
} finally {
  page.close();
  server.close();
}
process.exit(report.done());
