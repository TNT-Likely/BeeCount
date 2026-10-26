/* Shared only by the two independent selection review boards. */
window.SelectionReview = (() => {
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paths = {
    back:'m15 6-6 6 6 6',right:'m9 6 6 6-6 6',close:'m6 6 12 12M6 18 18 6',more:'M5 12h.01M12 12h.01M19 12h.01',
    search:'M21 21l-5-5M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16',check:'m5 12 4 4L19 6',plus:'M12 5v14M5 12h14',
    lock:'M5 10h14v11H5zM8 10V7a4 4 0 0 1 8 0v3',tag:'M3 3h8l10 10-8 8L3 11V3Zm4 4h.01',
    coffee:'M5 8h12v8a4 4 0 0 1-4 4H9a4 4 0 0 1-4-4V8Zm12 1h1a3 3 0 0 1 0 6h-1M8 3v2m4-2v2',
    edit:'m16 3 5 5-12 12-6 1 1-6L16 3ZM6 13l5 5',file:'M5 2h10l5 5v15H5V2Zm10 0v6h5M9 12h7m-7 4h7',
    wallet:'M4 5h14a2 2 0 0 1 2 2v13H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h12M16 10h6v5h-6z',
    home:'m3 10 9-7 9 7v11H3V10Zm6 11v-7h6v7',chart:'M3 3v18h18M7 16v-4m5 4V7m5 9v-6',user:'M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10ZM3 21a9 9 0 0 1 18 0',
    signal:'M4 18v3m5-7v7m5-12v12m5-17v17',wifi:'M2 8a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0m-11 4a5 5 0 0 1 8 0m-4 4h.01',battery:'M2 6h18v12H2zM22 10v4M5 9h11v6H5z',eye:'M2 12s4-7 10-7 10 7-4 7-10 7S2 12 2 12Zm10 3a3 3 0 1 0 0-6 3 3 0 0 0 0 6',eyeOff:'m3 3 18 18M6 6a18 18 0 0 0-4 6s4 7 10 7a12 12 0 0 0 5-1M10 5a12 12 0 0 1 2 0c6 0 10 7 10 7a18 18 0 0 1-3 4',image:'M3 3h18v18H3zM3 17l5-5 5 5 3-3 5 5M8 7h.01',info:'M12 11v6m0-10h.01M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20'
  };
  const icon = name => `<svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name] || paths.wallet}"></path></svg>`;
  const status = () => `<div class="status-bar"><span>9:41</span><span>${icon('signal')}${icon('wifi')}${icon('battery')}</span></div>`;
  const phone = document.querySelector('.phone');
  let toastTimer;
  function toast(text) {
    phone.querySelector('.toast')?.remove();
    const element = document.createElement('div'); element.className = 'toast'; element.setAttribute('role','status'); element.textContent = text;
    phone.append(element); clearTimeout(toastTimer); toastTimer = setTimeout(() => element.remove(), 2500);
  }
  function bindControls(onChange = () => {}) {
    const params = new URLSearchParams(location.search);
    function update() {
      const [width,height] = document.querySelector('#size').value.split('x');
      phone.style.setProperty('--phone-width',`${width}px`); phone.style.setProperty('--phone-height',`${height}px`);
      phone.dataset.appearance = document.querySelector('[data-appearance][aria-pressed=true]').dataset.appearance;
      phone.dataset.accent = document.querySelector('#accent').value;
      document.querySelector('#size-caption').textContent = `${width} × ${height}`;
      onChange();
    }
    document.querySelector('#size').addEventListener('change',update);
    document.querySelector('#accent').addEventListener('change',update);
    document.querySelectorAll('button[data-appearance]').forEach(button => button.addEventListener('click',() => {
      document.querySelectorAll('button[data-appearance]').forEach(b => b.setAttribute('aria-pressed',String(b === button))); update();
    }));
    if (params.get('size') && [...document.querySelector('#size').options].some(o=>o.value===params.get('size'))) document.querySelector('#size').value=params.get('size');
    if (params.get('appearance')==='dark') document.querySelectorAll('button[data-appearance]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.appearance==='dark')));
    if (['honey','purple','green'].includes(params.get('accent'))) document.querySelector('#accent').value=params.get('accent');
    update();
  }
  return {esc,icon,status,toast,bindControls,phone};
})();
