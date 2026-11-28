// Compra real de entradas (comprador sin cuenta). Las reglas viven en la base:
// aquí solo se llama a create_order, get_order, declare_payment y cancel_order.
(() => {
    const STORE = 'check:pedidos';
    const MAX_LINES = 6;
    const money = new Intl.NumberFormat('es-BO', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
    const bs = value => 'Bs. ' + money.format(value);
    const when = new Intl.DateTimeFormat('es-BO', { timeZone: 'America/La_Paz', dateStyle: 'long', timeStyle: 'short' });
    const messages = {
        invalid_buyer_name: 'Escribe tu nombre y apellido.',
        invalid_buyer_ci: 'Revisa tu número de carnet (entre 4 y 20 caracteres).',
        invalid_buyer_phone: 'Revisa tu número de teléfono.',
        invalid_buyer_email: 'Revisa tu correo electrónico.',
        invalid_lines: 'Revisa las entradas elegidas.',
        invalid_quantity: 'Esa cantidad no está permitida.',
        invalid_ticket_type: 'Una de las categorías ya no está disponible.',
        sold_out: 'Ya no quedan suficientes cupos.',
        event_not_available: 'Este evento ya no está a la venta.',
        venue_payment_not_configured: 'El local todavía no configuró cómo cobrar. Intenta más tarde.',
        commercial_inactive: 'El local no está habilitado para vender en este momento.',
        too_many_open_orders: 'Ya tienes 3 pedidos activos. Paga o cancela uno antes de crear otro.',
        order_total_zero: 'Las entradas sin costo no se pueden pedir en línea. Consulta con el local.',
        plan_limit_tickets: 'El local no puede emitir más entradas por ahora.',
        order_expired: 'El tiempo para pagar venció. Haz un pedido nuevo.',
        order_not_payable: 'El pedido cambió de estado.',
        order_not_cancellable: 'El pedido ya no se puede cancelar.',
        not_found: 'No encontramos ese pedido. Revisa que el enlace esté completo.',
        network: 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.'
    };
    const titles = {
        awaiting_payment: 'Paga tu pedido',
        verifying: 'Estamos verificando tu pago',
        approved: 'Pago aprobado',
        rejected: 'Pago rechazado',
        expired: 'El pedido venció',
        cancelled: 'Pedido cancelado'
    };

    function errorText(error) {
        const key = Object.keys(messages).find(code => String(error?.message ?? '').includes(code));
        if (!key) return 'No se pudo completar la operación. Intenta de nuevo.';
        const detail = ['sold_out', 'invalid_quantity'].includes(key) && error.hint ? ' (' + error.hint + ')' : '';
        return messages[key] + detail;
    }

    async function rpc(name, params) {
        const config = await window.checkConfig;
        if (!config.canBuy) throw new Error('disabled');
        let response;
        try {
            response = await fetch(config.supabaseUrl + '/rest/v1/rpc/' + name, {
                method: 'POST',
                headers: { apikey: config.publishableKey, 'Content-Type': 'application/json' },
                body: JSON.stringify(params),
                credentials: 'omit',
                signal: AbortSignal.timeout(20000)
            });
        } catch {
            throw new Error('network');
        }
        const body = await response.json().catch(() => null);
        if (!response.ok) throw Object.assign(new Error(body?.message ?? 'request_failed'), { hint: body?.hint });
        return body;
    }

    // El navegador recuerda los pedidos; el enlace privado sirve en cualquier otro.
    function readOrders() {
        try {
            const list = JSON.parse(localStorage.getItem(STORE) ?? '[]');
            return Array.isArray(list) ? list.filter(item => item?.id && item.token) : [];
        } catch {
            return [];
        }
    }

    async function savedOrders() {
        const { supabaseUrl } = await window.checkConfig;
        return readOrders().filter(item => item.backend === supabaseUrl);
    }

    async function remember(order) {
        const { supabaseUrl } = await window.checkConfig;
        const others = readOrders().filter(item => item.id !== order.id);
        try {
            localStorage.setItem(STORE, JSON.stringify([{ ...order, backend: supabaseUrl }, ...others].slice(0, 20)));
        } catch {
            // Sin almacenamiento: queda el enlace privado que se muestra en pantalla.
        }
        document.dispatchEvent(new CustomEvent('check:orders-changed'));
    }

    /** Acepta el enlace completo o el código `<id>.<token>`. */
    function parseCode(raw) {
        const match = String(raw).trim().match(/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.([0-9a-f]{64})$/i);
        return match ? { id: match[1], token: match[2] } : null;
    }

    function el(tag, text, className) {
        const node = document.createElement(tag);
        if (text !== undefined && text !== null) node.textContent = text;
        if (className) node.className = className;
        return node;
    }

    function button(text, kind, onClick) {
        const node = el('button', text, 'catalog-action catalog-action-' + kind);
        node.type = 'button';
        if (onClick) node.addEventListener('click', onClick);
        return node;
    }

    function details(rows) {
        const list = el('dl');
        for (const [label, value] of rows) {
            if (value) list.append(el('dt', label), el('dd', value));
        }
        return list;
    }

    function qrImage(payload, alt) {
        const code = qrcode(0, 'M');
        code.addData(payload);
        code.make();
        const image = el('img');
        image.src = code.createDataURL(5, 20);
        image.alt = alt;
        image.width = 220;
        image.height = 220;
        return image;
    }

    function openDialog(label, name, date) {
        document.querySelector('dialog.checkout')?.close();
        const dialog = el('dialog', null, 'checkout-demo checkout');
        dialog.setAttribute('aria-labelledby', 'checkout-title');
        const header = el('header', null, 'checkout-demo-header');
        const heading = el('div');
        const title = el('h2', name);
        title.id = 'checkout-title';
        const subtitle = el('p', date);
        heading.append(el('p', label, 'welcome-label'), title, subtitle);
        header.append(heading, button('Cerrar', 'secondary', () => dialog.close()));
        const status = el('p');
        status.setAttribute('role', 'status');
        status.dataset.status = '';
        const body = el('div');
        dialog.append(header, status, body);
        const opener = document.activeElement;
        const cleanups = [];
        dialog.addEventListener('close', () => {
            cleanups.forEach(stop => stop());
            dialog.remove();
            // El evento `close` llega después: si ya se abrió otra ventana, la
            // dirección y el foco son de ella.
            if (document.querySelector('dialog.checkout[open]')) return;
            if (location.hash.startsWith('#pedido=')) history.replaceState(null, '', location.pathname + location.search);
            opener?.focus?.();
        }, { once: true });
        document.body.append(dialog);
        dialog.showModal();
        return { dialog, title, subtitle, status, body, onClose: stop => cleanups.push(stop) };
    }

    // ───────── Elegir entradas y datos del comprador ─────────
    function openPurchase(event) {
        if (document.querySelector('dialog.checkout[open]')) return;
        const view = openDialog('COMPRAR ENTRADAS', event.name, when.format(event.startsAt));
        const quantities = new Map();
        const form = el('form');
        form.noValidate = false;
        const selection = el('section');
        const total = el('p', '', 'checkout-total');
        const next = button('Continuar', 'primary');
        next.disabled = true;

        const chosen = () => event.types.filter(type => (quantities.get(type.id) ?? 0) > 0);
        const sum = () => chosen().reduce((value, type) => value + type.price * quantities.get(type.id), 0);

        function update() {
            const count = chosen().reduce((value, type) => value + quantities.get(type.id), 0);
            total.textContent = count
                ? count + (count === 1 ? ' entrada' : ' entradas') + ' · Total ' + bs(sum())
                : 'Elige cuántas entradas quieres.';
            const tooMany = chosen().length > MAX_LINES;
            next.disabled = !count || sum() <= 0 || tooMany;
            view.status.textContent = tooMany ? 'Puedes combinar hasta ' + MAX_LINES + ' categorías por pedido.'
                : count && sum() <= 0 ? messages.order_total_zero : '';
        }

        for (const type of event.types) {
            const max = Math.max(0, Math.min(type.available ?? 0, type.max_per_order ?? 0));
            const row = el('label', null, 'checkout-type');
            const name = el('span', type.name + ' · ' + (type.price === 0 ? 'Gratis' : bs(type.price)));
            const select = el('select');
            select.dataset.type = type.id;
            if (!max) {
                select.add(new Option('Agotado', '0'));
                select.disabled = true;
            } else {
                for (let quantity = 0; quantity <= max; quantity++) select.add(new Option(String(quantity), String(quantity)));
            }
            select.addEventListener('change', () => {
                quantities.set(type.id, Number(select.value));
                update();
            });
            row.append(name, select);
            selection.append(row);
        }
        selection.append(total, next);

        const buyer = el('section');
        buyer.hidden = true;
        const summary = el('p', '', 'checkout-total');
        const field = (label, name, attributes) => {
            const wrapper = el('label', label);
            const input = el('input');
            input.name = name;
            Object.assign(input, attributes);
            wrapper.append(input);
            return wrapper;
        };
        const submit = button('Reservar y ver cómo pagar', 'primary');
        submit.type = 'submit';
        const back = button('← Cambiar entradas', 'secondary', () => {
            buyer.hidden = true;
            selection.hidden = false;
            view.status.textContent = '';
        });
        buyer.append(
            el('h3', '¿A nombre de quién van?'),
            summary,
            field('Nombre y apellido', 'name', { required: true, minLength: 2, maxLength: 120, autocomplete: 'name' }),
            field('Carnet de identidad', 'ci', { required: true, minLength: 4, maxLength: 20, autocomplete: 'off' }),
            field('Teléfono', 'phone', { required: true, type: 'tel', minLength: 6, maxLength: 30, autocomplete: 'tel' }),
            field('Correo electrónico (opcional)', 'email', { type: 'email', maxLength: 200, autocomplete: 'email' }),
            el('p', 'No necesitas crear una cuenta. El local usará estos datos para identificar tu pedido.', 'checkout-demo-disclaimer'),
            submit, back
        );

        next.addEventListener('click', () => {
            selection.hidden = true;
            buyer.hidden = false;
            summary.textContent = total.textContent;
            view.status.textContent = '';
            form.elements.namedItem('name').focus();
        });

        let sending = false;
        form.addEventListener('submit', async submission => {
            submission.preventDefault();
            if (sending || buyer.hidden) return;
            sending = true;
            submit.disabled = back.disabled = true;
            view.status.textContent = 'Reservando tus entradas…';
            const data = new FormData(form);
            const value = name => String(data.get(name) ?? '').trim();
            try {
                const created = await rpc('create_order', {
                    p_event_id: event.id,
                    p_buyer_name: value('name'),
                    p_buyer_ci: value('ci'),
                    p_buyer_phone: value('phone'),
                    p_buyer_email: value('email') || null,
                    p_lines: chosen().map(type => ({ type_id: type.id, qty: quantities.get(type.id) }))
                });
                const order = { id: created.order_id, token: created.token, number: created.number, event: event.name };
                await remember(order);
                document.dispatchEvent(new CustomEvent('check:catalog-refresh'));
                if (view.dialog.open) view.dialog.close();
                openOrder(order);
            } catch (error) {
                view.status.textContent = errorText(error);
                if (/sold_out|invalid_ticket_type|event_not_available/.test(error.message)) {
                    document.dispatchEvent(new CustomEvent('check:catalog-refresh'));
                }
                sending = false;
                submit.disabled = back.disabled = false;
            }
        });

        form.append(selection, buyer);
        view.body.append(form);
        update();
    }

    // ───────── Seguimiento del pedido ─────────
    function openOrder({ id, token }) {
        const view = openDialog('TU PEDIDO', 'Consultando…', '');
        history.replaceState(null, '', location.pathname + location.search + '#pedido=' + id + '.' + token);
        const link = location.origin + location.pathname + '#pedido=' + id + '.' + token;
        let data;
        let shown = '';
        let busy = false;
        let confirming = false;
        let lastLoad = 0;
        let countdown = null;

        async function load(announce) {
            if (busy) return;
            busy = true;
            lastLoad = Date.now();
            try {
                data = await rpc('get_order', { p_order_id: id, p_token: token });
                if (!view.dialog.open) return;
                const fingerprint = JSON.stringify(data);
                if (fingerprint !== shown) {
                    shown = fingerprint;
                    render();
                    await remember({ id, token, number: data.order.number, event: data.event.name });
                }
                if (announce) view.status.textContent = 'Estado actualizado.';
            } catch (error) {
                view.status.textContent = errorText(error);
                if (!data) {
                    view.title.textContent = 'Mi pedido';
                    view.body.replaceChildren(button('Reintentar', 'secondary', () => load(true)));
                }
            } finally {
                busy = false;
            }
        }

        async function act(name, trigger) {
            trigger.disabled = true;
            view.status.textContent = 'Enviando…';
            try {
                await rpc(name, { p_order_id: id, p_token: token });
                view.status.textContent = '';
            } catch (error) {
                view.status.textContent = errorText(error);
                trigger.disabled = false;
            }
            confirming = false;
            shown = '';
            while (busy) await new Promise(resolve => setTimeout(resolve, 100));
            await load(false);
        }

        function tick() {
            if (!countdown) return;
            const seconds = Math.max(0, Math.ceil((countdown.until - Date.now()) / 1000));
            countdown.node.textContent = seconds
                ? String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0')
                : '00:00';
        }

        function render() {
            const { order, event, venue, bank, lines, tickets } = data;
            countdown = null;
            view.title.textContent = titles[order.status] ?? 'Mi pedido';
            view.subtitle.textContent = [event.name, when.format(new Date(event.starts_at)), venue?.name].filter(Boolean).join(' · ');
            const panel = el('section');
            panel.dataset.state = order.status;
            panel.append(details([
                ['Pedido', order.number],
                ['A nombre de', order.buyer_name],
                ['Entradas', (lines ?? []).map(line => line.qty + ' × ' + line.type_name).join(', ')],
                ['Total', bs(order.total)]
            ]));

            if (order.status === 'awaiting_payment') {
                const timer = el('p', 'Tiempo para pagar y avisar ');
                timer.dataset.timer = '';
                const clock = el('strong');
                clock.setAttribute('role', 'timer');
                timer.append(clock);
                countdown = { until: Date.parse(order.expires_at), node: clock };
                panel.append(timer, el('h3', 'Datos para pagar'), details([
                    ['Beneficiario', bank?.beneficiary],
                    ['Banco', bank?.bank_name],
                    ['Número de cuenta', bank?.account],
                    ['Monto', bs(order.total)],
                    ['Referencia', order.number]
                ]));
                if (/^https:\/\//i.test(bank?.qr_path ?? '')) {
                    const image = el('img');
                    image.src = bank.qr_path;
                    image.alt = 'QR de cobro del local';
                    image.width = 220;
                    panel.append(image);
                }
                panel.append(el('p', 'Paga directamente al local desde tu banco y después pulsa «Ya pagué». CHECK no recibe ni mueve tu dinero.', 'checkout-demo-disclaimer'));
                const paid = button('Ya pagué', 'primary', () => act('declare_payment', paid));
                paid.dataset.paid = '';
                const cancel = button(confirming ? 'Confirmar cancelación' : 'Cancelar pedido', 'secondary', () => {
                    if (confirming) return act('cancel_order', cancel);
                    confirming = true;
                    cancel.textContent = 'Confirmar cancelación';
                    view.status.textContent = 'Si cancelas, se liberan tus entradas reservadas. Pulsa otra vez para confirmar.';
                });
                cancel.dataset.cancel = '';
                panel.append(paid, cancel);
            } else if (order.status === 'verifying') {
                panel.append(el('p', 'El local está revisando su cuenta. Esta pantalla se actualiza sola; también puedes volver más tarde con tu enlace.'),
                    button('Actualizar ahora', 'secondary', () => load(true)));
            } else if (order.status === 'approved') {
                panel.append(el('p', 'Muestra cada QR en la puerta. Cada uno sirve para una sola persona y un solo ingreso: no lo compartas.'));
                if (event.status === 'draft') {
                    panel.append(el('p', 'El evento todavía no está activo: tus entradas permitirán ingresar cuando el local lo active.', 'checkout-warning'));
                }
                (tickets ?? []).forEach((ticket, index) => {
                    const card = el('article', null, 'checkout-ticket');
                    card.append(el('h3', 'Entrada ' + (index + 1) + ' de ' + tickets.length), el('p', ticket.type_name));
                    if (ticket.status === 'cancelled') {
                        card.append(el('p', 'Esta entrada fue anulada.', 'checkout-warning'));
                    } else {
                        const image = qrImage(ticket.qr_token, 'Código QR de la entrada ' + (index + 1));
                        const download = el('a', 'Descargar QR', 'catalog-action catalog-action-secondary');
                        download.href = image.src;
                        download.download = 'CHECK-' + order.number + '-' + (index + 1) + '.gif';
                        card.append(image);
                        if (ticket.status === 'used') card.append(el('p', 'Ya se usó para ingresar.', 'checkout-warning'));
                        card.append(download);
                    }
                    panel.append(card);
                });
            } else if (order.status === 'rejected') {
                panel.append(el('p', 'El local no confirmó el pago.' + (order.reject_reason ? ' Motivo: ' + order.reject_reason : ''), 'checkout-warning'),
                    el('p', 'Si ya pagaste, escribe a soporte con tu número de pedido.'));
            } else {
                panel.append(el('p', order.status === 'expired'
                    ? 'No se avisó el pago a tiempo y las entradas se liberaron. Puedes hacer un pedido nuevo.'
                    : 'Las entradas se liberaron. Puedes hacer un pedido nuevo.'));
            }

            const copy = button('Copiar enlace de mi pedido', 'secondary', async () => {
                try {
                    await navigator.clipboard.writeText(link);
                    view.status.textContent = 'Enlace copiado. Guárdalo en un lugar seguro.';
                } catch {
                    view.status.textContent = 'No se pudo copiar. Selecciona el enlace y cópialo.';
                }
            });
            panel.append(el('p', 'Guarda tu enlace privado: con él vuelves a ver tu pedido y tus entradas.', 'checkout-demo-disclaimer'),
                el('code', link, 'checkout-link'), copy);
            view.body.replaceChildren(panel);
            tick();
        }

        const interval = setInterval(() => {
            tick();
            if (document.hidden || confirming || !data) return;
            const state = data.order.status;
            // El servidor decide el vencimiento y la aprobación: se le vuelve a preguntar.
            const wait = state === 'verifying' ? 10000
                : state === 'awaiting_payment' ? (countdown && Date.now() >= countdown.until ? 5000 : 30000)
                : state === 'approved' ? 60000 : 0;
            if (wait && Date.now() - lastLoad >= wait) load(false);
        }, 1000);
        view.onClose(() => clearInterval(interval));
        load(false);
    }

    function openFromHash() {
        if (!location.hash.startsWith('#pedido=')) return;
        const order = parseCode(location.hash.slice('#pedido='.length));
        if (order) openOrder(order);
    }

    window.checkCheckout = { openPurchase, openOrder, savedOrders, parseCode };
    window.addEventListener('hashchange', openFromHash);
    window.checkConfig.then(config => { if (config.canBuy) openFromHash(); });
})();
