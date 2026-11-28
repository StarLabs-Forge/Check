(() => {
    const canvas = document.getElementById('aurora-canvas');
    const context = canvas?.getContext('2d');
    if (!context) return;

    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const palette = getComputedStyle(document.documentElement);
    const violet = palette.getPropertyValue('--primary-hover').trim();
    const teal = palette.getPropertyValue('--active').trim();
    const bands = [
        { color: violet, height: 0.45, baseline: 0.64, phase: 0.4, speed: 0.53, opacity: 0.51 },
        { color: teal, height: 0.32, baseline: 0.72, phase: 2.2, speed: 0.39, opacity: 0.41 },
        { color: violet, height: 0.28, baseline: 0.43, phase: 3.1, speed: 0.31, opacity: 0.24 }
    ];

    function makeRay(color) {
        const ray = document.createElement('canvas');
        ray.width = 20;
        ray.height = 160;
        const brush = ray.getContext('2d');
        const fade = brush.createLinearGradient(0, 0, 0, ray.height);
        fade.addColorStop(0, 'transparent');
        fade.addColorStop(0.35, color + '26');
        fade.addColorStop(0.66, color + '80');
        fade.addColorStop(0.82, color);
        fade.addColorStop(0.88, color + 'B0');
        fade.addColorStop(1, 'transparent');
        brush.fillStyle = fade;
        brush.fillRect(0, 0, ray.width, ray.height);

        const edges = brush.createLinearGradient(0, 0, ray.width, 0);
        edges.addColorStop(0, 'transparent');
        edges.addColorStop(0.5, 'white');
        edges.addColorStop(1, 'transparent');
        brush.globalCompositeOperation = 'destination-in';
        brush.fillStyle = edges;
        brush.fillRect(0, 0, ray.width, ray.height);
        return ray;
    }

    const rays = bands.map(band => makeRay(band.color));
    const stars = Array.from({ length: 94 }, (_, index) => ({
        x: ((index * 137) % 997) / 997,
        y: ((index * 223 + 57) % 991) / 991,
        size: index % 17 === 0 ? 1 : 0.55,
        opacity: 0.22 + (index % 7) * 0.065
    }));
    const pointer = { x: 0, y: 0 };
    const drift = { x: 0, y: 0, scroll: 0 };
    let frame = 0;
    let lastFrame = 0;
    let time = 0;

    function draw() {
        const { width, height } = canvas;
        context.clearRect(0, 0, width, height);
        context.globalCompositeOperation = 'source-over';
        context.fillStyle = '#E8E7FF';
        for (const star of stars) {
            context.globalAlpha = star.opacity;
            context.fillRect(star.x * width, star.y * height, star.size, star.size);
        }

        context.globalCompositeOperation = 'lighter';
        const columns = width >= 550 ? 112 : 76;
        const spacing = width / columns;

        bands.forEach((band, layer) => {
            const phase = band.phase + time * band.speed;
            const scrollPhase = drift.scroll * (0.31 + 0.08 * layer);
            const parallax = 0.05 + layer * 0.024;
            for (let column = -8; column <= columns + 8; column++) {
                const u = column / columns;
                const wave = u * 6.8 + phase + scrollPhase;
                const fold = Math.sin(wave) * 0.125 + Math.sin(wave * 2.1 - phase) * 0.044;
                const ripple = Math.sin(column * 2.37 + phase * 1.6);
                const length = height * band.height * (0.82 + 0.21 * Math.sin(wave * 1.6) + ripple * 0.13);
                const edge = height * (band.baseline + fold + drift.y * parallax);
                const x = column * spacing + drift.x * width * parallax;
                const shimmer = 0.7 + 0.18 * ripple + 0.12 * Math.sin(column * 4.9 - phase);
                context.globalAlpha = band.opacity * shimmer;
                context.drawImage(rays[layer], x - spacing * 1.25, edge - length * 0.82, spacing * 2.5, length);
            }
        });
        context.globalAlpha = 1;
    }

    function animate(now) {
        if (now - lastFrame >= 30) {
            time += lastFrame ? Math.min((now - lastFrame) / 1000, 0.05) : 0;
            lastFrame = now;
            drift.x += (pointer.x - drift.x) * 0.13;
            drift.y += (pointer.y - drift.y) * 0.13;
            drift.scroll += (window.scrollY / window.innerHeight - drift.scroll) * 0.15;
            draw();
        }
        frame = requestAnimationFrame(animate);
    }

    function syncMotion() {
        cancelAnimationFrame(frame);
        lastFrame = 0;
        if (document.hidden) return;
        if (motion.matches) {
            time = 0;
            Object.assign(drift, { x: 0, y: 0, scroll: 0 });
            draw();
        } else {
            frame = requestAnimationFrame(animate);
        }
    }

    function resize() {
        const scale = Math.min(0.8, 960 / window.innerWidth, 790 / window.innerHeight);
        canvas.width = Math.round(window.innerWidth * scale);
        canvas.height = Math.round(window.innerHeight * scale);
        draw();
    }

    window.addEventListener('pointermove', event => {
        if (event.pointerType === 'touch' || motion.matches) return;
        pointer.x = event.clientX / window.innerWidth * 2 - 1;
        pointer.y = event.clientY / window.innerHeight * 2 - 1;
    }, { passive: true });
    document.documentElement.addEventListener('pointerleave', () => {
        pointer.x = 0;
        pointer.y = 0;
    });
    window.addEventListener('resize', resize, { passive: true });
    document.addEventListener('visibilitychange', syncMotion);
    motion.addEventListener('change', syncMotion);
    resize();
    syncMotion();
})();
