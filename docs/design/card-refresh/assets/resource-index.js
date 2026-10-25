(() => {
  const storageKey = 'beecount.design-resources.layout.v1';
  const list = document.getElementById('screen-list');
  const query = document.getElementById('query');
  const originalGroup = document.getElementById('group');
  const count = document.getElementById('count');
  const navigation = document.getElementById('group-navigation');
  const empty = document.getElementById('empty-state');
  const buttons = [...document.querySelectorAll('[data-layout]')];
  // Keep the original nodes, order and links when changing display mode.
  const cards = [...list.querySelectorAll('.screen')];
  const sections = [];
  let mode = 'flat';

  try {
    if (localStorage.getItem(storageKey) === 'grouped') mode = 'grouped';
  } catch (_) {
    // Storage may be unavailable for local files, private windows or policy.
  }

  function filter() {
    const term = query.value.trim().toLocaleLowerCase();
    let visible = 0;
    for (const card of cards) {
      card.hidden = !!((term && !card.dataset.title.toLocaleLowerCase().includes(term)) ||
        (originalGroup.value && card.dataset.group !== originalGroup.value));
      if (!card.hidden) visible++;
    }
    let visibleGroups = 0;
    for (const section of sections) {
      const size = [...section.node.querySelectorAll('.screen')].filter(card => !card.hidden).length;
      section.node.hidden = size === 0;
      section.link.hidden = size === 0;
      section.count.textContent = size + ' 个场景';
      section.linkCount.textContent = String(size);
      if (size) visibleGroups++;
    }
    count.textContent = visible + ' 个场景' + (mode === 'grouped' ? ' · ' + visibleGroups + ' 个分组' : '');
    navigation.hidden = mode !== 'grouped' || visible === 0;
    empty.hidden = visible !== 0;
  }

  function render() {
    for (const button of buttons) button.setAttribute('aria-pressed', String(button.dataset.layout === mode));
    list.classList.toggle('is-grouped', mode === 'grouped');
    navigation.replaceChildren();
    sections.length = 0;
    if (mode === 'flat') {
      list.replaceChildren(...cards);
    } else {
      const groups = new Map();
      for (const card of cards) {
        const id = card.dataset.displayGroup;
        if (!groups.has(id)) groups.set(id, { id, title: card.dataset.displayTitle, order: Number(card.dataset.displayOrder), cards: [] });
        groups.get(id).cards.push(card);
      }
      const fragment = document.createDocumentFragment();
      for (const group of [...groups.values()].sort((a, b) => a.order - b.order)) {
        const node = document.createElement('section');
        node.className = 'resource-group';
        node.id = 'resource-group-' + group.id;
        const heading = document.createElement('h2');
        heading.className = 'resource-group-heading';
        heading.id = node.id + '-heading';
        heading.append(document.createTextNode(group.title));
        const groupCount = document.createElement('span');
        groupCount.className = 'group-count';
        heading.append(groupCount);
        node.setAttribute('aria-labelledby', heading.id);
        const grid = document.createElement('div');
        grid.className = 'resource-group-grid';
        grid.append(...group.cards);
        node.append(heading, grid);
        fragment.append(node);
        const link = document.createElement('a');
        link.href = '#' + node.id;
        link.append(document.createTextNode(group.title));
        const linkCount = document.createElement('span');
        linkCount.setAttribute('aria-hidden', 'true');
        link.append(linkCount);
        navigation.append(link);
        sections.push({ node, count: groupCount, link, linkCount });
      }
      list.replaceChildren(fragment);
    }
    filter();
  }

  for (const button of buttons) button.addEventListener('click', () => {
    const next = button.dataset.layout;
    if (next === mode) return;
    mode = next;
    try { localStorage.setItem(storageKey, mode); } catch (_) {}
    render();
  });
  query.addEventListener('input', filter);
  originalGroup.addEventListener('change', filter);
  render();
})();
