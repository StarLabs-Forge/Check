/* Escenas animadas de "Lenguaje visual" y "Qué incluye CHECK".
   - Escritorio (puntero fino): al entrar el cursor se enciende el borde y,
     tras ~220 ms, la escena se reproduce una vez. Al salir, vuelve al reposo.
   - Táctil / sin puntero fino: la escena se activa por scroll. Solo una tarjeta
     por grupo queda activa: la más cercana al centro de la pantalla.
   - prefers-reduced-motion: todas las escenas se muestran en su estado final.
   No hay bucles: cada escena se reproduce una vez por activación. */
(function () {
    const scenes = Array.from(document.querySelectorAll('.scene-card'));
    if (!scenes.length) return;

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const finePointer = window.matchMedia('(pointer: fine)').matches;

    if (reduceMotion) {
        scenes.forEach(card => card.querySelector('.scene').classList.add('is-playing'));
        return;
    }

    const sceneOf = card => card.querySelector('.scene');

    if (finePointer) {
        // Escritorio: activación por cursor + parallax interno
        scenes.forEach(card => {
            let timer = null;

            card.addEventListener('pointerenter', () => {
                card.classList.add('is-lit');
                clearTimeout(timer);
                timer = setTimeout(() => sceneOf(card).classList.add('is-playing'), 220);
            });

            card.addEventListener('pointerleave', () => {
                clearTimeout(timer);
                card.classList.remove('is-lit');
                sceneOf(card).classList.remove('is-playing');
                card.style.removeProperty('--px');
                card.style.removeProperty('--py');
            });

            card.addEventListener('pointermove', e => {
                const r = card.getBoundingClientRect();
                card.style.setProperty('--px', ((e.clientX - r.left) / r.width - 0.5).toFixed(3));
                card.style.setProperty('--py', ((e.clientY - r.top) / r.height - 0.5).toFixed(3));
            }, { passive: true });
        });
        return;
    }

    // Táctil: activación progresiva por scroll, una tarjeta activa por grupo
    const groups = Array.from(new Set(scenes.map(c => c.parentElement)));
    const activeByGroup = new Map();
    let ticking = false;

    const update = () => {
        ticking = false;
        const vh = window.innerHeight;
        const mid = vh / 2;
        const reach = vh / 2;

        groups.forEach(group => {
            const list = scenes.filter(c => c.parentElement === group);
            const prev = activeByGroup.get(group) || null;
            let best = null;
            let bestD = Infinity;

            list.forEach(card => {
                const r = card.getBoundingClientRect();
                const d = Math.abs((r.top + r.height / 2) - mid);
                const visible = r.bottom > 0 && r.top < vh;
                // Iluminación progresiva según se acerca al centro
                const glow = Math.max(0, 1 - d / reach);
                card.style.setProperty('--glow', glow.toFixed(3));
                if (visible && d < bestD) { best = card; bestD = d; }
            });

            // Histéresis: la tarjeta activa conserva su turno mientras siga cerca
            if (prev && prev !== best) {
                const r = prev.getBoundingClientRect();
                const dPrev = Math.abs((r.top + r.height / 2) - mid);
                if (dPrev - bestD < vh * 0.08) best = prev;
            }

            const activeCard = best && bestD < vh * 0.3 ? best : null;
            activeByGroup.set(group, activeCard);

            list.forEach(card => {
                const on = card === activeCard;
                card.classList.toggle('is-lit', on);
                sceneOf(card).classList.toggle('is-playing', on);
            });
        });
    };

    const onScroll = () => {
        if (!ticking) { ticking = true; requestAnimationFrame(update); }
    };

    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    update();
})();
