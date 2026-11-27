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

            // 6. Spotlight de tarjetas que sigue al puntero (solo puntero fino y sin reduced-motion)
            if (window.matchMedia('(pointer: fine)').matches && !reduceMotion) {
                document.body.classList.add('has-spotlight');
                document.querySelectorAll('.module-card, .state-card, .plan-card').forEach(card => {
                    card.addEventListener('pointermove', e => {
                        const r = card.getBoundingClientRect();
                        card.style.setProperty('--sx', (e.clientX - r.left) + 'px');
                        card.style.setProperty('--sy', (e.clientY - r.top) + 'px');
                    }, { passive: true });
                });
            }

            // 7. Métricas: cuenta hasta el valor real al entrar en pantalla (el texto final no cambia)
            if (!reduceMotion && 'IntersectionObserver' in window) {
                const countObserver = new IntersectionObserver((entries, obs) => {
                    entries.forEach(entry => {
                        if (!entry.isIntersecting) return;
                        obs.unobserve(entry.target);
                        const el = entry.target;
                        const m = el.dataset.final.match(/^(\D*)([\d,]+)(\D*)$/);
                        const end = parseInt(m[2].replace(/,/g, ''), 10);
                        const t0 = performance.now(), dur = 1200;
                        const tick = now => {
                            const k = Math.min(1, (now - t0) / dur);
                            const eased = 1 - Math.pow(1 - k, 3);
                            el.textContent = m[1] + Math.round(end * eased).toLocaleString('en-US') + m[3];
                            if (k < 1) requestAnimationFrame(tick);
                            else el.textContent = el.dataset.final;
                        };
                        requestAnimationFrame(tick);
                    });
                }, { threshold: 0.6 });
                document.querySelectorAll('.metric-num').forEach(el => {
                    const txt = el.textContent.trim();
                    const m = txt.match(/^\D*([\d,]+)\D*$/);
                    if (m && parseInt(m[1].replace(/,/g, ''), 10) >= 10) {
                        el.dataset.final = txt;
                        countObserver.observe(el);
                    }
                });
            }

            // 8. Dispositivo 3D: inclinacion segun el puntero y tilt de tarjetas
            const finePointer = window.matchMedia('(pointer: fine)').matches;
            const tilt = document.getElementById('deviceTilt');
            if (tilt && finePointer && !reduceMotion) {
                const heroSec = document.querySelector('.hero');
                heroSec.addEventListener('pointermove', e => {
                    const r = heroSec.getBoundingClientRect();
                    const nx = (e.clientX - r.left) / r.width - 0.5;
                    const ny = (e.clientY - r.top) / r.height - 0.5;
                    tilt.classList.add('is-live');
                    tilt.style.setProperty('--ry', (nx * 26).toFixed(1) + 'deg');
                    tilt.style.setProperty('--rx', (-ny * 18).toFixed(1) + 'deg');
                }, { passive: true });
                heroSec.addEventListener('pointerleave', () => {
                    tilt.classList.remove('is-live');
                    tilt.style.removeProperty('--ry');
                    tilt.style.removeProperty('--rx');
                });
            }
            if (finePointer && !reduceMotion) {
                document.querySelectorAll('.module-card, .state-card, .plan-card:not(.featured)').forEach(card => {
                    card.addEventListener('pointermove', e => {
                        const r = card.getBoundingClientRect();
                        const nx = (e.clientX - r.left) / r.width - 0.5;
                        const ny = (e.clientY - r.top) / r.height - 0.5;
                        card.style.setProperty('--try', (nx * 10).toFixed(1) + 'deg');
                        card.style.setProperty('--trx', (-ny * 10).toFixed(1) + 'deg');
                    }, { passive: true });
                    card.addEventListener('pointerleave', () => {
                        card.style.removeProperty('--try');
                        card.style.removeProperty('--trx');
                    });
                });
            }

            // 9. Parallax del hero ligado al scroll
            if (!reduceMotion) {
                const heroEl = document.querySelector('.hero');
                const wrapEl = document.querySelector('.device-wrapper');
                let pTick = false;
                const updateParallax = () => {
                    pTick = false;
                    const p = Math.max(0, Math.min(1, window.scrollY / (heroEl.offsetHeight || 1))).toFixed(3);
                    heroEl.style.setProperty('--hero-p', p);
                    if (wrapEl) wrapEl.style.setProperty('--hero-p', p);
                };
                window.addEventListener('scroll', () => { if (!pTick) { pTick = true; requestAnimationFrame(updateParallax); } }, { passive: true });
                updateParallax();
            }

            // 10. Frase del problema: separa palabras para el volteo 3D (el texto accesible no cambia)
            const quoteEl = document.querySelector('.quote-statement');
            if (quoteEl && !reduceMotion) {
                const txt = quoteEl.textContent.trim();
                quoteEl.setAttribute('aria-label', txt);
                quoteEl.textContent = '';
                txt.split(/\s+/).forEach((w, i, arr) => {
                    const span = document.createElement('span');
                    span.className = 'qw';
                    span.setAttribute('aria-hidden', 'true');
                    span.style.setProperty('--i', i);
                    span.textContent = w;
                    quoteEl.appendChild(span);
                    if (i < arr.length - 1) quoteEl.appendChild(document.createTextNode(' '));
                });
            }

            // 11. Abanico 3D: --fan va de 1 (borde de pantalla) a 0 (centrado)
            if (!reduceMotion) {
                const fanGrids = Array.from(document.querySelectorAll('.states-grid, .plans-grid, .modules-grid'));
                let fanTick = false;
                const updateFan = () => {
                    fanTick = false;
                    const mid = window.innerHeight / 2;
                    fanGrids.forEach(g => {
                        const r = g.getBoundingClientRect();
                        const d = Math.abs((r.top + r.height / 2) - mid) / mid;
                        const fan = Math.max(0, Math.min(1, (d - 0.15) / 0.85));
                        g.style.setProperty('--fan', fan.toFixed(3));
                    });
                };
                window.addEventListener('scroll', () => { if (!fanTick) { fanTick = true; requestAnimationFrame(updateFan); } }, { passive: true });
                window.addEventListener('resize', updateFan);
                updateFan();
            }

            // 12. Tilt 3D en contacto y caja del CTA final
            if (finePointer && !reduceMotion) {
                document.querySelectorAll('.contact-info-item, .cta-box').forEach(card => {
                    const k = card.classList.contains('cta-box') ? 6 : 8;
                    card.addEventListener('pointermove', e => {
                        const r = card.getBoundingClientRect();
                        const nx = (e.clientX - r.left) / r.width - 0.5;
                        const ny = (e.clientY - r.top) / r.height - 0.5;
                        card.style.setProperty('--try', (nx * k).toFixed(1) + 'deg');
                        card.style.setProperty('--trx', (-ny * k).toFixed(1) + 'deg');
                    }, { passive: true });
                    card.addEventListener('pointerleave', () => {
                        card.style.removeProperty('--try');
                        card.style.removeProperty('--trx');
                    });
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
