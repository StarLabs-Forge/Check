// Backend que usa el sitio. Publicado: producción. En este equipo: el proyecto de
// desarrollo definido en `config.local.json` (no se versiona; ver
// `config.local.example.json`). Sin ese archivo, en local la compra queda
// desactivada para no crear pedidos reales mientras se prueba.
window.checkConfig = (() => {
    const production = {
        supabaseUrl: 'https://lvejfwatzdqpzftjraut.supabase.co',
        publishableKey: 'sb_publishable_45XCo6MIZ4Z1ERCD45Vk1Q_D4qIS4RW'
    };
    if (!['localhost', '127.0.0.1', '[::1]'].includes(location.hostname)) {
        return Promise.resolve({ ...production, canBuy: true, dev: false });
    }
    return fetch('./config.local.json', { cache: 'no-store' })
        .then(response => response.ok ? response.json() : null)
        .catch(() => null)
        .then(local => local?.supabaseUrl && local.publishableKey && local.supabaseUrl !== production.supabaseUrl
            ? { supabaseUrl: local.supabaseUrl, publishableKey: local.publishableKey, canBuy: true, dev: true }
            : { ...production, canBuy: false, dev: false });
})();
