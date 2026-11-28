(() => {
    const landingSections = new Set(['#como-funciona', '#nosotros', '#estados', '#modulos', '#planes', '#contacto']);
    if (landingSections.has(location.hash)) {
        location.replace(new URL('./organizadores.html' + location.search + location.hash, location.href));
        return;
    }

    const panels = document.querySelectorAll('.welcome-panel');
    if (!('IntersectionObserver' in window)) return;
    const observer = new IntersectionObserver(entries => {
        for (const entry of entries) entry.target.classList.toggle('is-visible', entry.isIntersecting);
    }, { threshold: 0.2 });
    panels.forEach(panel => observer.observe(panel));
})();