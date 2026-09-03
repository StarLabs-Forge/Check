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
            }

            // Cycle every 6 seconds
            setInterval(() => {
                currentStateIndex = (currentStateIndex + 1) % states.length;
                applyDeviceState(currentStateIndex);
            }, 6000);

            // Initial application
            applyDeviceState(0);

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
