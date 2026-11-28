/* Recorrido "Qué incluye CHECK".
   - La línea de energía avanza según el scroll dentro de la sección.
   - Una sola estación está activa: la más cercana a la franja central de la
     pantalla. Su microescena se reproduce una vez y queda con el resultado.
   - Al salir de la franja, la estación vuelve al reposo; al regresar, se
     reproduce de nuevo.
   - Escritorio: el cursor sobre una estación intensifica la luz y la
     profundidad (solo como refuerzo; la activación depende del scroll).
   - prefers-reduced-motion: todas las estaciones se muestran en estado final. */
(function () {
    const journey = document.getElementById('journey');
    if (!journey) return;

    const stations = Array.from(journey.querySelectorAll('.station'));
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const finePointer = window.matchMedia('(pointer: fine)').matches;

    // ---- Contadores (valor inicial -> final al activarse) ----
    const setCount = (el, v) => { el.textContent = v + (el.dataset.suffix || ''); };
    const countersOf = st => Array.from(st.querySelectorAll('.count'));

    function playCounters(st) {
        countersOf(st).forEach(el => {
            const from = Number(el.dataset.from);
            const to = Number(el.dataset.to);
            const start = performance.now() + 500;
            const dur = 900;
            const step = now => {
                if (!st.classList.contains('is-playing')) return;
                const k = Math.max(0, Math.min(1, (now - start) / dur));
                const eased = 1 - Math.pow(1 - k, 3);
                setCount(el, Math.round(from + (to - from) * eased));
                if (k < 1) requestAnimationFrame(step);
            };
            requestAnimationFrame(step);
        });
    }

    function resetCounters(st) {
        countersOf(st).forEach(el => setCount(el, Number(el.dataset.from)));
    }

    function setPlaying(st, on) {
        if (st.classList.contains('is-playing') === on) return;
        st.classList.toggle('is-playing', on);
        if (on) playCounters(st); else resetCounters(st);
    }

    // ---- Estado inicial: sin movimiento ----
    if (reduceMotion) {
        journey.style.setProperty('--energy', 1);
        stations.forEach(st => {
            st.classList.add('is-playing', 'is-done');
            countersOf(st).forEach(el => setCount(el, Number(el.dataset.to)));
        });
        return;
    }

    // ---- Scroll: energía + estación activa ----
    let activeStation = null;
    let ticking = false;

    function update() {
        ticking = false;
        const vh = window.innerHeight;
        const mid = vh * 0.55;

        const wrap = journey.getBoundingClientRect();
        const progress = Math.max(0, Math.min(1, (mid - wrap.top) / wrap.height));
        journey.style.setProperty('--energy', progress.toFixed(3));

        let best = null;
        let bestD = Infinity;
        let activeD = Infinity;
        stations.forEach(st => {
            const r = st.getBoundingClientRect();
            const d = Math.abs((r.top + r.height / 2) - mid);
            if (d < bestD) { bestD = d; best = st; }
            if (st === activeStation) activeD = d;
        });

        // Histéresis: la estación activa conserva su turno si no está claramente más lejos
        if (activeStation && activeStation !== best && activeD - bestD < vh * 0.08) {
            best = activeStation;
            bestD = activeD;
        }

        // Si el final del recorrido ya está visible, la última estación queda activa:
        // al bajar hasta el final, su centro nunca llega a la franja central.
        if (wrap.bottom > 0 && wrap.bottom <= vh * 0.9) { best = stations[stations.length - 1]; bestD = 0; }

        const next = best && bestD < vh * 0.3 ? best : null;
        if (next !== activeStation) {
            if (activeStation) setPlaying(activeStation, false);
            if (next) setPlaying(next, true);
            activeStation = next;
        }

        // Estaciones ya recorridas: el nodo queda marcado
        const activeIndex = next ? stations.indexOf(next) : -1;
        stations.forEach((st, i) => {
            const passed = i < activeIndex || (activeIndex === -1 && st.getBoundingClientRect().top < mid);
            st.classList.toggle('is-done', passed);
        });
    }

    const onScroll = () => {
        if (!ticking) { ticking = true; requestAnimationFrame(update); }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();

    // ---- Escritorio: refuerzo con el cursor ----
    if (finePointer) {
        stations.forEach(st => {
            st.addEventListener('pointerenter', () => st.classList.add('is-hover'));
            st.addEventListener('pointerleave', () => {
                st.classList.remove('is-hover');
                st.style.removeProperty('--px');
                st.style.removeProperty('--py');
            });
            st.addEventListener('pointermove', e => {
                const r = st.getBoundingClientRect();
                st.style.setProperty('--px', ((e.clientX - r.left) / r.width - 0.5).toFixed(3));
                st.style.setProperty('--py', ((e.clientY - r.top) / r.height - 0.5).toFixed(3));
            }, { passive: true });
        });
    }
})();
