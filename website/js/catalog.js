(() => {
    const endpoint = 'https://lvejfwatzdqpzftjraut.supabase.co/rest/v1/rpc/public_events';
    const publishableKey = 'sb_publishable_45XCo6MIZ4Z1ERCD45Vk1Q_D4qIS4RW';
    const buyerUrl = 'https://check-demo-three.vercel.app/#/comprar';
    const timeZone = 'America/La_Paz';
    const localDay = new Intl.DateTimeFormat('sv-SE', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' });
    const localDate = new Intl.DateTimeFormat('es-BO', { timeZone, dateStyle: 'long', timeStyle: 'short' });
    const price = new Intl.NumberFormat('es-BO', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
    const eventId = new URLSearchParams(location.search).get('evento');
    const state = document.getElementById('catalog-state');
    const results = document.getElementById('catalog-results');
    const retry = document.getElementById('catalog-retry');
    const when = /** @type {HTMLSelectElement | null} */ (document.getElementById('when'));
    const category = /** @type {HTMLSelectElement | null} */ (document.getElementById('category'));
    if (!(when instanceof HTMLSelectElement) || !(category instanceof HTMLSelectElement)) return;
    let events = [];

    // Reference listings provided for the visual review. Checkout uses public_events only.
    const references = [
        ['tusuy', 'Tusuy - Bolivia', '27T19:00', 'Tusuy, La Paz', 'Espectáculo'],
        ['fine-line', 'Fine Line Experience', '27T20:00', 'Espacio INNI, La Paz', 'Música'],
        ['vive-bolivia', 'Vive Bolivia', '27T22:00', 'Peña Jamuy, La Paz', 'Música'],
        ['fabrica', 'La fábrica de las emociones', '28T10:00', 'Espacio Kúu Inti, La Paz', 'Teatro'],
        ['your-name', 'Your Name en concierto', '28T16:00', 'Teatro 16 de Julio, La Paz', 'Concierto'],
        ['high-school', 'High School Musical', '28T16:00', 'Espacio Kúu Inti, La Paz', 'Danza'],
        ['mtv', 'MTV On Stage', '28T19:00', 'Espacio Kúu Inti, La Paz', 'Espectáculo'],
        ['gala-boliviana', 'Gala Boliviana', '28T19:30', 'Centro Cultural Torino, La Paz', 'Cultura'],
        ['farmeando', 'Farmeando risas - El Alto', '28T20:00', 'Teatro Raúl Salmón de la Barra, El Alto', 'Comedia'],
        ['sonrisa', 'Carrera benéfica Operación Sonrisa CCS', '29T07:00', 'Cochabamba', 'Deporte'],
        ['elencos', 'Gala 2026: Elencos formativos', '29T09:30', 'Teatro Municipal Alberto Saavedra Pérez, La Paz', 'Cultura'],
        ['wasqueadores', 'Los Wasqueadores', '29T19:00', 'Teatro Modesta Sanjinés, La Paz', 'Teatro'],
        ['jose-jose', 'José José Sinfónico (Oruro)', '29T19:00', 'Super Multiteatro de Oruro', 'Concierto']
    ].map(([id, name, date, venue_name, category]) => ({
        id: 'referencia-' + id, name, startsAt: new Date('2026-11-' + date + ':00-04:00'),
        endsAt: null, venue_name, category, types: [], reference: true, cover_url: './assets/eventos/' + id + '.jpg'
    }));


    function element(tag, text, className) {
        const node = document.createElement(tag);
        if (text) node.textContent = text;
        if (className) node.className = className;
        return node;
    }

    function link(text, href, className) {
        const node = element('a', text, className);
        node.href = href;
        return node;
    }

    function calendarDate(date) {
        return new Date(localDay.format(date) + 'T00:00:00Z');
    }

    function dateMatches(event, filter, now) {
        if (event.endsAt ? event.endsAt <= now : calendarDate(event.startsAt) < calendarDate(now)) return false;
        if (filter === 'upcoming') return true;
        const today = calendarDate(now);
        const starts = calendarDate(event.startsAt);
        const lastActive = event.endsAt ? calendarDate(new Date(event.endsAt.getTime() - 1)) : starts;
        const year = today.getUTCFullYear();
        const month = today.getUTCMonth();
        const first = new Date(today);
        const last = new Date(today);
        switch (filter) {
            case 'today':
                last.setUTCDate(last.getUTCDate() + 1);
                break;
            case 'week':
                first.setUTCDate(first.getUTCDate() - (first.getUTCDay() + 6) % 7);
                last.setTime(first.getTime());
                last.setUTCDate(last.getUTCDate() + 7);
                break;
            case 'month':
                first.setUTCDate(1);
                last.setTime(Date.UTC(year, month + 1, 1));
                break;
            case 'next-month':
                first.setTime(Date.UTC(year, month + 1, 1));
                last.setTime(Date.UTC(year, month + 2, 1));
                break;
            default:
                return false;
        }
        return starts < last && lastActive >= first;
    }

    function available(types) {
        if (!types.some(type => Number.isInteger(type.available))) return 'Disponibilidad por confirmar';
        const count = types.reduce((sum, type) => sum + (type.available ?? 0), 0);
        return count > 0 ? 'Disponible' : 'Agotado';
    }

    function amount(value) {
        return value === 0 ? 'Gratis' : 'Bs. ' + price.format(value);
    }

    function renderCard(event, detail = false) {
        const card = element('article', '', detail ? 'catalog-card catalog-detail' : 'catalog-card');
        const copy = detail ? element('div', '', 'catalog-detail-copy') : card;
        const detailLink = '?evento=' + encodeURIComponent(event.id);
        if (event.reference || (typeof event.cover_url === 'string' && /^https:\/\//i.test(event.cover_url))) {
            const image = element('img');
            image.src = event.cover_url;
            image.alt = 'Afiche de ' + event.name;
            image.loading = 'lazy';
            if (detail) {
                card.append(image);
            } else {
                const coverLink = link('', detailLink, 'catalog-cover-link');
                coverLink.setAttribute('aria-label', 'Ver detalles de ' + event.name);
                coverLink.append(image);
                card.append(coverLink);
            }
        } else if (event.reference || detail) {
            const cover = element('div', '', 'catalog-poster');
            cover.setAttribute('aria-hidden', 'true');
            cover.append(element('span', event.category || 'CHECK EVENTOS'), element('strong', event.name));
            card.append(cover);
        }
        if (detail) card.append(copy);
        if (event.category) copy.append(element('p', event.category, 'welcome-label'));
        copy.append(element(detail ? 'h1' : 'h2', event.name));
        const time = element('time', localDate.format(event.startsAt));
        time.dateTime = event.startsAt.toISOString();
        copy.append(time);
        const place = [event.venue_name, event.venue_zone].filter(Boolean).join(' · ');
        if (place) copy.append(element('p', place));
        const prices = event.types.map(type => type.price).filter(Number.isFinite);
        const hasSeats = event.types.some(type => type.available > 0);
        if (prices.length) {
            const from = Math.min(...prices);
            copy.append(element('strong', from === 0 ? amount(from) : 'Desde ' + amount(from)));
        }
        copy.append(element('p', event.reference ? 'Evento de referencia' : available(event.types)));
        if (detail) {
            if (event.id === 'referencia-jose-jose') copy.append(element('p', 'Apertura de puertas · 18:30'));
            if (event.description) copy.append(element('p', event.description, 'catalog-description'));
            const tickets = element('ul');
            for (const type of event.types) {
                const label = [type.name, Number.isFinite(type.price) ? amount(type.price) : '', available([type])].filter(Boolean).join(' · ');
                tickets.append(element('li', label));
            }
            if (tickets.childElementCount) copy.append(tickets);
            const purchase = element('div', '', 'catalog-purchase');
            const schedule = element('label', 'Función');
            const select = element('select');
            const performances = [event.startsAt];
            if (event.id === 'referencia-your-name') performances.push(new Date('2026-11-28T19:00:00-04:00'));
            for (const date of performances) select.add(new Option(localDate.format(date), date.toISOString()));
            schedule.append(select);
            purchase.append(schedule);
            if (event.reference) {
                const button = element('button', 'Probar compra', 'catalog-action catalog-action-primary');
                button.type = 'button';
                button.addEventListener('click', () => document.dispatchEvent(new CustomEvent('check:demo-checkout', {
                    detail: { name: event.name, date: localDate.format(new Date(select.value)) }
                })));
                purchase.append(button);
            } else if (hasSeats) {
                purchase.append(link('Comprar en CHECK', buyerUrl, 'catalog-action catalog-action-primary'));
            }
            copy.append(purchase);
        } else {
            copy.append(link('Ver detalles', detailLink, 'catalog-action catalog-action-secondary'));
        }
        return card;
    }

    function render() {
        results.replaceChildren();
        if (eventId !== null) {
            const event = events.find(item => item.id === eventId) ?? references.find(item => item.id === eventId);
            state.textContent = event ? '' : 'Este evento ya no está disponible en el catálogo público.';
            if (event) {
                document.title = event.name + ' | CHECK';
                results.append(renderCard(event, true));
            }
            return;
        }
        const now = new Date();
        const visible = events.filter(event =>
            dateMatches(event, when.value, now) && (!category.value || event.category === category.value));
        state.textContent = visible.length
            ? visible.length + (visible.length === 1 ? ' evento' : ' eventos')
            : events.length ? 'No hay eventos para estos filtros.' : 'Todavía no hay eventos públicos. Vuelve pronto.';
        results.append(...visible.map(event => renderCard(event)));
        if (when.value === 'upcoming' && !category.value) {
            const gallery = element('section', '', 'catalog-references');
            gallery.append(
                element('h2', 'Eventos de referencia'),
                element('p', 'Cartelera de las capturas. Estos eventos no tienen venta habilitada en CHECK.')
            );
            const grid = element('div', '', 'catalog-grid');
            grid.append(...references.map(event => renderCard(event)));
            gallery.append(grid);
            results.append(gallery);
        }
    }

    async function load() {
        state.textContent = 'Cargando eventos…';
        retry.hidden = true;
        results.replaceChildren();
        try {
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { apikey: publishableKey, 'Content-Type': 'application/json' },
                body: '{}',
                credentials: 'omit',
                signal: AbortSignal.timeout(12000)
            });
            if (!response.ok) throw new Error('Catalog HTTP ' + response.status);
            const data = await response.json();
            if (!Array.isArray(data)) throw new TypeError('Unexpected public catalog response');
            events = data.filter(event => event && ['active', 'live'].includes(event.status) &&
                typeof event.id === 'string' && typeof event.name === 'string' && event.starts_at &&
                Number.isFinite(Date.parse(event.starts_at)))
                .map(event => ({
                    ...event,
                    startsAt: new Date(event.starts_at),
                    endsAt: event.ends_at && Number.isFinite(Date.parse(event.ends_at)) ? new Date(event.ends_at) : null,
                    category: typeof event.category === 'string' ? event.category.trim() : '',
                    types: Array.isArray(event.types) ? event.types.filter(type => type && typeof type.name === 'string') : []
                }));
            if (eventId === null) {
                const categories = [...new Set(events.map(event => event.category).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'es'));
                category.length = 1;
                for (const value of categories) category.add(new Option(value, value));
                document.getElementById('category-filter').hidden = categories.length === 0;
            }
            render();
        } catch {
            state.textContent = 'No se pudo cargar el catálogo. Intenta de nuevo.';
            retry.hidden = false;
        }
    }

    if (eventId !== null) {
        document.getElementById('catalog-intro').replaceChildren(link('← Volver a los eventos', './eventos.html', 'catalog-action catalog-action-secondary'));
    }
    when.addEventListener('change', render);
    category.addEventListener('change', render);
    retry.addEventListener('click', load);
    load();
})();
