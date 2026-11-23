        document.addEventListener('DOMContentLoaded', () => {
            // 1. Live Clock inside Device Mockup
            const liveClock = document.getElementById('liveClock');
            function updateClock() {
                const now = new Date();
                const hrs = String(now.getHours()).padStart(2, '0');
                const mins = String(now.getMinutes()).padStart(2, '0');
                const secs = String(now.getSeconds()).padStart(2, '0');
                if (liveClock) {
                    liveClock.textContent = `${hrs}:${mins}:${secs}`;
                }
            }
            setInterval(updateClock, 1000);
            updateClock();

            // 2. Door Scanner Device State Cycle (6 Seconds per state)
            const deviceBadge = document.getElementById('deviceBadge');
            const deviceDot = document.getElementById('deviceDot');
            const deviceText = document.getElementById('deviceText');
            const deviceSub = document.getElementById('deviceSub');
            const ticketCode = document.getElementById('ticketCode');
            const qrRing = document.getElementById('qrRing');
            const doorDevice = document.getElementById('doorDevice');

            const states = [
                {
                    color: 'var(--success)',
                    colorHex: '#2ECC71',
                    text: 'VALIDO · INGRESA DIRECTO',
                    sub: 'Camila Ruiz — Mesa VIP 04 (Pagado)',
                    code: 'TK-8842-OK',
                    dotClass: 'v',
                    bg: 'rgba(46, 204, 113, 0.12)',
                    border: 'rgba(46, 204, 113, 0.3)'
                },
                {
                    color: 'var(--warning)',
                    colorHex: '#FFB020',
                    text: 'COBRAR EN PUERTA · Bs 100',
                    sub: 'Diego Mendoza — Entrada General (Pago Pendiente)',
                    code: 'TK-3109-PEND',
                    dotClass: 'a',
                    bg: 'rgba(255, 176, 32, 0.12)',
                    border: 'rgba(255, 176, 32, 0.3)'
                },
                {
                    color: 'var(--error)',
                    colorHex: '#FF5566',
                    text: 'INVALIDO · QR YA USADO',
                    sub: 'Escaneado previamente a las 23:14:02',
                    code: 'TK-0021-DUPL',
                    dotClass: 'r',
                    bg: 'rgba(255, 85, 102, 0.12)',
                    border: 'rgba(255, 85, 102, 0.3)'
                }
            ];

            let currentStateIndex = 0;
            const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
            const resultClasses = ['result-v', 'result-a', 'result-r'];
            const statusMain = document.getElementById('deviceStatusMain');

            // Reinicia una animación CSS añadiendo la clase de nuevo
            function replay(el, cls) {
                if (!el) return;
                el.classList.remove(cls);
                void el.offsetWidth;
                el.classList.add(cls);
            }

            function applyDeviceState(index) {
                const st = states[index];
                if (!deviceBadge) return;

                // Update text content
                deviceText.textContent = st.text;
                deviceSub.textContent = st.sub;
                ticketCode.textContent = st.code;

                // Update styles & classes
                deviceDot.className = `state-dot ${st.dotClass}`;
                deviceBadge.style.backgroundColor = st.bg;
                deviceBadge.style.border = `1px solid ${st.border}`;
                deviceBadge.style.color = st.colorHex;

                // CSS Variable for QR ring & scan beam glow
                doorDevice.style.setProperty('--device-color', st.colorHex);
                qrRing.style.background = `conic-gradient(from 0deg, ${st.colorHex}, transparent 80%)`;
                doorDevice.style.borderColor = st.border;

                // Transición de resultado: flash del color + movimiento propio de cada estado
                doorDevice.classList.remove('is-scanning', ...resultClasses);
                void doorDevice.offsetWidth;
                doorDevice.classList.add(`result-${st.dotClass}`);
                replay(statusMain, 'swap-in');
                replay(deviceSub, 'swap-in');
            }

            // Fase de escaneo: tarjeta neutra y láser rápido antes de mostrar el resultado
            function startScanning() {
                doorDevice.classList.remove(...resultClasses);
                doorDevice.classList.add('is-scanning');
                deviceText.textContent = 'ESCANEANDO…';
                deviceSub.textContent = 'Leyendo código QR';
                deviceDot.className = 'state-dot';
                deviceBadge.style.backgroundColor = 'transparent';
                deviceBadge.style.border = '1px solid var(--line)';
                deviceBadge.style.color = 'var(--muted)';
                doorDevice.style.setProperty('--device-color', 'var(--active)');
                doorDevice.style.borderColor = '';
                qrRing.style.background = '';
                replay(statusMain, 'swap-in');
                replay(deviceSub, 'swap-in');
            }

            // Ciclo de 6 s: ~1.4 s escaneando, el resto mostrando el resultado
            function runCycle() {
                if (reduceMotion) {
                    applyDeviceState(currentStateIndex);
                    currentStateIndex = (currentStateIndex + 1) % states.length;
                    setTimeout(runCycle, 6000);
                    return;
                }
                startScanning();
                setTimeout(() => {
                    applyDeviceState(currentStateIndex);
                    currentStateIndex = (currentStateIndex + 1) % states.length;
                }, 1400);
                setTimeout(runCycle, 6000);
            }

            runCycle();

            // Logo del header: aparece solo cuando el logo del hero sale por arriba
            const header = document.querySelector('.header');
            const heroLogo = document.getElementById('heroLogo');
            if (header && heroLogo && 'IntersectionObserver' in window) {
                new IntersectionObserver(([entry]) => {
                    const passed = !entry.isIntersecting && entry.boundingClientRect.top < 0;
                    header.classList.toggle('logo-in', passed);
                }, { rootMargin: '-70px 0px 0px 0px' }).observe(heroLogo);
            } else if (header) {
                header.classList.add('logo-in');
            }


            // 4. Cómo funciona: el paso activo sigue al scroll + línea de progreso
            const stepsList = document.getElementById('stepsList');
            if (stepsList) {
                const steps = Array.from(stepsList.querySelectorAll('.step-card'));
                let ticking = false;
                document.body.classList.add('js-steps');
                const updateSteps = () => {
                    ticking = false;
                    const line = window.innerHeight * 0.55;
                    let active = -1;
                    steps.forEach((el, i) => { if (el.getBoundingClientRect().top < line) active = i; });
                    steps.forEach((el, i) => {
                        el.classList.toggle('is-active', i === active);
                        el.classList.toggle('is-done', i < active);
                    });
                    const top = stepsList.getBoundingClientRect().top;
                    const px = Math.max(0, Math.min(stepsList.offsetHeight, line - top));
                    stepsList.style.setProperty('--progress', px + 'px');
                };
                const onScroll = () => { if (!ticking) { ticking = true; requestAnimationFrame(updateSteps); } };
                window.addEventListener('scroll', onScroll, { passive: true });
                window.addEventListener('resize', onScroll);
                updateSteps();
            }

            // Header: marca el enlace de la sección donde está el usuario
            const navLinks = Array.from(document.querySelectorAll('.nav-link[href^="#"]'));
            const spySections = Array.from(document.querySelectorAll('section[id]'));
            if (navLinks.length && spySections.length) {
                let spyTicking = false;
                const updateSpy = () => {
                    spyTicking = false;
                    const line = (header ? header.offsetHeight : 72) + window.innerHeight * 0.3;
                    let current = null;
                    spySections.forEach(sec => {
                        const r = sec.getBoundingClientRect();
                        if (r.top <= line && r.bottom > line) current = sec.id;
                    });
                    navLinks.forEach(a => {
                        const on = a.getAttribute('href') === '#' + current;
                        a.classList.toggle('is-current', on);
                        if (on) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current');
                    });
                };
                const onSpy = () => { if (!spyTicking) { spyTicking = true; requestAnimationFrame(updateSpy); } };
                window.addEventListener('scroll', onSpy, { passive: true });
                window.addEventListener('resize', onSpy);
                updateSpy();
            }

            // 5. Botones "Solicitar demo" magnéticos (solo puntero fino y sin reduced-motion)
            if (window.matchMedia('(pointer: fine)').matches && !reduceMotion) {
                document.querySelectorAll('.btn-primary').forEach(btn => {
                    const reach = 70, pull = 0.3;
                    const move = e => {
                        const r = btn.getBoundingClientRect();
                        const dx = e.clientX - (r.left + r.width / 2);
                        const dy = e.clientY - (r.top + r.height / 2);
                        const near = Math.abs(dx) < r.width / 2 + reach && Math.abs(dy) < r.height / 2 + reach;
                        btn.style.setProperty('--mx', near ? (dx * pull).toFixed(1) + 'px' : '0px');
                        btn.style.setProperty('--my', near ? (dy * pull).toFixed(1) + 'px' : '0px');
                    };
                    window.addEventListener('mousemove', move, { passive: true });
                });
            }

            // 3. Scroll Reveal Animation using IntersectionObserver
            const revealElements = document.querySelectorAll('.reveal');

            if ('IntersectionObserver' in window) {
                const revealObserver = new IntersectionObserver((entries, observer) => {
                    entries.forEach(entry => {
                        if (entry.isIntersecting) {
                            entry.target.classList.add('active');
                            observer.unobserve(entry.target);
                        }
                    });
                }, {
                    threshold: 0.08,
                    rootMargin: '0px 0px -8% 0px'
                });

                revealElements.forEach(el => revealObserver.observe(el));
            } else {
                revealElements.forEach(el => el.classList.add('active'));
            }
        });
