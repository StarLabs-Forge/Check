(() => {
    const types = [
        { name: 'Segunda fila', price: 200 },
        { name: 'Tercera fila', price: 180 },
        { name: 'Cuarta fila', price: 150 },
        { name: 'Primera fila', price: 240, soldOut: true }
    ];

    document.addEventListener('check:demo-checkout', event => {
        if (document.querySelector('.checkout-demo[open]')) return;
        const { name, date } = event.detail;
        const dialog = document.createElement('dialog');
        dialog.className = 'checkout-demo';
        dialog.setAttribute('aria-labelledby', 'checkout-demo-title');
        dialog.innerHTML = `
            <header class="checkout-demo-header">
                <div><p class="welcome-label">COMPRA DE DEMOSTRACIÓN</p><h2 id="checkout-demo-title"></h2><p data-date></p></div>
                <button class="catalog-action catalog-action-secondary" type="button" data-close>← Volver al evento</button>
            </header>
            <p class="checkout-demo-disclaimer">Usa datos ficticios. El pago y la entrada son de prueba.</p>
            <p data-timer>Tiempo de selección <strong role="timer">10:00</strong></p>
            <p role="status" data-status></p>
            <form data-form>
                <section data-selection>
                    <label>Tipo de entrada <select name="type" required><option value="">Selecciona un tipo</option></select></label>
                    <fieldset hidden data-seats><legend>Elige tu butaca</legend><div class="checkout-demo-seats"></div></fieldset>
                    <p data-total hidden></p>
                    <button class="catalog-action catalog-action-primary" type="button" data-next disabled>Verificar disponibilidad</button>
                </section>
                <section data-buyer hidden>
                    <h3>Datos del comprador</h3>
                    <label>Nombre y apellido <input name="buyer" maxlength="100" required></label>
                    <label>Correo electrónico <input name="email" type="email" maxlength="160" required></label>
                    <label>Teléfono <input name="phone" type="tel" maxlength="30"></label>
                    <label>Medio de pago <select name="payment"><option>QR de prueba</option></select></label>
                    <button class="catalog-action catalog-action-primary" type="submit">Generar QR de pago</button>
                </section>
            </form>
            <section data-payment hidden>
                <h3>Paga con QR</h3>
                <p>QR simulado. No lo uses en una aplicación bancaria.</p>
                <img data-payment-code alt="QR de pago simulado" width="180" height="180">
                <button class="catalog-action catalog-action-primary" type="button" data-paid>Ya pagué</button>
            </section>
            <section data-result hidden>
                <h3>Compra aceptada <span>· Demostración</span></h3>
                <dl data-receipt></dl>
                <img data-entry-code alt="QR único de entrada de demostración" width="180" height="180">
                <a class="catalog-action catalog-action-primary" data-download-entry download>Descargar QR</a>
                <p>Cuida este QR y no lo compartas. En una compra real se usa para validar tu entrada en puerta. Este QR de prueba no da acceso al evento.</p>
            </section>`;
        const find = selector => dialog.querySelector(selector);
        const form = find('[data-form]');
        const typeSelect = form.elements.namedItem('type');
        const status = find('[data-status]');
        const timer = find('[role="timer"]');
        const next = find('[data-next]');
        const total = find('[data-total]');
        const buyerPanel = find('[data-buyer]');
        const payment = find('[data-payment]');
        const paid = find('[data-paid]');
        const deadline = Date.now() + 10 * 60 * 1000;
        let seat = '';
        let receipt;
        let phase = 'selection';
        let interval;
        let verification;
        find('h2').textContent = name;
        find('[data-date]').textContent = date;
        types.forEach((type, index) => {
            const option = new Option(type.name + ' · Bs. ' + type.price + (type.soldOut ? ' · Agotado' : ''), String(index));
            option.disabled = Boolean(type.soldOut);
            typeSelect.add(option);
        });

        function qr(payload) {
            const code = qrcode(0, 'M');
            code.addData(payload);
            code.make();
            return code.createDataURL(5, 20);
        }

        function tick() {
            const seconds = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
            timer.textContent = String(Math.floor(seconds / 60)).padStart(2, '0') + ':' + String(seconds % 60).padStart(2, '0');
            if (seconds) return true;
            phase = 'expired';
            clearInterval(interval);
            clearTimeout(verification);
            form.hidden = true;
            payment.hidden = true;
            status.textContent = 'Se agotó el tiempo. Vuelve al evento para empezar una nueva compra de prueba.';
            return false;
        }

        typeSelect.addEventListener('change', () => {
            seat = '';
            next.disabled = true;
            total.hidden = true;
            const seatGroup = find('[data-seats]');
            const seats = find('.checkout-demo-seats');
            seatGroup.hidden = typeSelect.value === '';
            seats.replaceChildren();
            if (seatGroup.hidden) return;
            for (let index = 1; index <= 12; index++) {
                const button = document.createElement('button');
                button.type = 'button';
                button.textContent = String(index);
                button.setAttribute('aria-label', 'Butaca ' + index);
                button.setAttribute('aria-pressed', 'false');
                button.disabled = index % 4 === 0;
                button.addEventListener('click', () => {
                    seats.querySelector('[aria-pressed="true"]')?.setAttribute('aria-pressed', 'false');
                    button.setAttribute('aria-pressed', 'true');
                    seat = String(index);
                    next.disabled = false;
                    total.hidden = false;
                    total.textContent = 'Total simulado: Bs. ' + types[Number(typeSelect.value)].price;
                });
                seats.append(button);
            }
        });

        next.addEventListener('click', () => {
            if (!seat || phase !== 'selection' || !tick()) return;
            phase = 'buyer';
            find('[data-selection]').hidden = true;
            buyerPanel.hidden = false;
            form.elements.namedItem('buyer').focus();
            status.textContent = 'Butaca ' + seat + ' disponible en esta demostración.';
        });

        form.addEventListener('submit', submission => {
            submission.preventDefault();
            if (phase !== 'buyer' || !tick()) return;
            const data = new FormData(form);
            const buyer = String(data.get('buyer')).trim();
            if (!buyer) {
                status.textContent = 'Escribe un nombre para la entrada de prueba.';
                form.elements.namedItem('buyer').focus();
                return;
            }
            const type = types[Number(typeSelect.value)];
            receipt = { Nombre: buyer, Correo: String(data.get('email')), Teléfono: String(data.get('phone')).trim(),
                Evento: name, Función: date, Entrada: type.name, Butaca: seat, Total: 'Bs. ' + type.price };
            find('[data-payment-code]').src = qr('CHECK-DEMO-PAGO:' + crypto.randomUUID());
            form.hidden = true;
            payment.hidden = false;
            phase = 'payment';
            status.textContent = '';
            paid.focus();
        });

        paid.addEventListener('click', () => {
            if (phase !== 'payment' || !tick()) return;
            phase = 'verifying';
            paid.disabled = true;
            status.textContent = 'Verificando el pago simulado…';
            verification = setTimeout(() => {
                if (phase !== 'verifying' || !tick()) return;
                phase = 'accepted';
                clearInterval(interval);
                find('[data-timer]').hidden = true;
                payment.hidden = true;
                const code = 'CHECK-DEMO-ENTRADA:' + crypto.randomUUID();
                const details = find('[data-receipt]');
                for (const [label, value] of Object.entries({ ...receipt, Código: code })) {
                    if (!value) continue;
                    const term = document.createElement('dt');
                    const description = document.createElement('dd');
                    term.textContent = label;
                    description.textContent = value;
                    details.append(term, description);
                }
                const imageUrl = qr(code);
                find('[data-entry-code]').src = imageUrl;
                const download = find('[data-download-entry]');
                download.href = imageUrl;
                download.download = code.replace(':', '-') + '.gif';
                find('[data-result]').hidden = false;
                status.textContent = 'Pago simulado verificado.';
            }, 1400);
        });

        const opener = document.activeElement;
        find('[data-close]').addEventListener('click', () => dialog.close());
        dialog.addEventListener('close', () => {
            clearInterval(interval);
            clearTimeout(verification);
            dialog.remove();
            opener?.focus();
        }, { once: true });
        document.body.append(dialog);
        dialog.showModal();
        tick();
        interval = setInterval(tick, 250);
    });
})();