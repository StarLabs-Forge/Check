(() => {
    const tour = document.getElementById('check-tour');
    if (!tour) return;
    const panels = Array.from(tour.querySelectorAll('.tour-panel'));
    const controls = tour.querySelector('.tour-controls');
    const next = tour.querySelector('.tour-next');
    let current = 0;

    const buttons = panels.map((panel, index) => {
        panel.id = 'check-tour-step-' + (index + 1);
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = panel.dataset.label;
        button.setAttribute('aria-controls', panel.id);
        button.addEventListener('click', () => show(index));
        controls.append(button);
        return button;
    });

    function show(index) {
        current = index;
        panels.forEach((panel, position) => {
            const selected = position === index;
            panel.hidden = !selected;
            buttons[position].setAttribute('aria-pressed', String(selected));
        });
        next.textContent = index === panels.length - 1 ? 'Volver al primer paso ↺' : 'Siguiente paso →';
    }

    next.addEventListener('click', () => {
        show((current + 1) % panels.length);
        buttons[current].focus({ preventScroll: true });
    });
    show(0);
    controls.hidden = false;
    next.hidden = false;
})();