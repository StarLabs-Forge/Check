/* Lenguaje visual: escenario 3D del escáner.
   - Escritorio: al entrar en la sección se reproduce VERDE -> AMARILLO -> ROJO.
     El último resultado queda visible. Al salir de la sección se detiene el
     temporizador; al volver, la secuencia se reproduce de nuevo.
   - Móvil/tablet: el escenario es sticky. Cada paso se activa al pasar por la
     franja central de la pantalla y reproduce solo su estado.
   - Clic en un estado (opcional): detiene la secuencia y muestra su resultado.
   - Sin cursor: no hay ningún listener de puntero que altere la escena.
   - prefers-reduced-motion: escena en estado final, sin temporizadores. */
(function () {
    const section = document.getElementById('estados');
    const stage = document.getElementById('estStage');
    const list = document.getElementById('estSteps');
    if (!section || !stage || !list) return;

    const STATES = ['verde', 'amarillo', 'rojo'];
    const steps = Array.from(list.querySelectorAll('.est-step'));
    const buttons = Array.from(list.querySelectorAll('.est-btn'));
    const dots3d = Array.from(stage.querySelectorAll('.ind3d i'));
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const desktop = window.matchMedia('(min-width: 900px)');

    // Duraciones (ms) dentro del rango de referencia de la especificación
    const T = { lead: 80, approach: 700, scan: 800, process: 350, result: 1900 };

    let timers = [];
    let current = null;      // estado mostrado
    let mobileActive = null; // estado activado por scroll en móvil

    const later = (fn, ms) => { timers.push(setTimeout(fn, ms)); };
    const stopTimers = () => { timers.forEach(clearTimeout); timers = []; };

    function show(state, phase) {
        current = state;
        stage.dataset.state = state;
        stage.dataset.phase = phase;
        const idx = STATES.indexOf(state);
        steps.forEach(st => st.classList.toggle('is-on', st.dataset.state === state));
        buttons.forEach(b => b.setAttribute('aria-pressed', b.dataset.state === state ? 'true' : 'false'));
        dots3d.forEach((d, i) => d.classList.toggle('on', i === idx));
        list.style.setProperty('--p', ((idx + 1) / STATES.length).toFixed(3));
    }

    // Secuencia completa de un estado; si hay siguiente, lo encadena
    function playState(state, then) {
        stopTimers();
        show(state, 'idle');
        let t = T.lead;
        later(() => show(state, 'approach'), t); t += T.approach;
        later(() => show(state, 'scan'), t);     t += T.scan;
        later(() => show(state, 'process'), t);  t += T.process;
        later(() => show(state, 'result'), t);   t += T.result;
        if (then) later(then, t);
    }

    function playChain() {
        playState('verde', () => playState('amarillo', () => playState('rojo')));
    }

    // Resultado directo, sin animación (clic o movimiento reducido)
    function showResult(state) {
        stopTimers();
        show(state, 'result');
    }

    // ---- Clic opcional: detiene la reproducción automática ----
    buttons.forEach(btn => {
        btn.addEventListener('click', () => {
            mobileActive = btn.dataset.state;
            showResult(btn.dataset.state);
        });
    });

    if (reduceMotion) {
        showResult('verde');
        return;
    }

    // ---- Escritorio: reproducción al entrar en la sección ----
    const io = new IntersectionObserver(entries => {
        entries.forEach(entry => {
            if (!desktop.matches) return;
            if (entry.isIntersecting && entry.intersectionRatio >= 0.35) {
                playChain();
            } else if (!entry.isIntersecting) {
                stopTimers();
            }
        });
    }, { threshold: [0, 0.35] });
    io.observe(section);

    // ---- Móvil/tablet: cada estado se activa al llegar su paso ----
    let ticking = false;
    function onScroll() {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
            ticking = false;
            if (desktop.matches) return;
            const vh = window.innerHeight;
            const mid = vh * 0.55;
            let best = null;
            let bestD = Infinity;
            steps.forEach(st => {
                const r = st.getBoundingClientRect();
                const d = Math.abs((r.top + r.height / 2) - mid);
                if (d < bestD) { bestD = d; best = st; }
            });
            const next = best && bestD < vh * 0.3 ? best.dataset.state : null;
            if (next === mobileActive) return;
            mobileActive = next;
            if (next) playState(next);
            else stopTimers(); // fuera de los pasos: no se reproduce nada en segundo plano
        });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);

    // Estado inicial: el escenario muestra VERDE en reposo, sin esperar al scroll
    show('verde', 'idle');
})();
