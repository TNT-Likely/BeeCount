// Independent guide behavior. Append after guide.js; no App state or file I/O.
document.addEventListener('click',event=>{
  const source=event.target.closest('[data-im87-demo-source]');
  if(!source)return;
  const host=source.closest('.im87-guide');
  host.querySelectorAll('[data-im87-demo-source]').forEach(button=>button.setAttribute('aria-pressed',String(button===source)));
  host.querySelector('[data-im87-demo-event]').textContent='示例来源已选择 '+source.textContent+'，不读取文件或写入账本';
});
document.addEventListener('change',event=>{
  if(!event.target.matches('[data-im87-demo-map]'))return;
  const host=event.target.closest('.im87-guide');
  host.querySelector('[data-im87-demo-event]').textContent='示例映射已选择 '+event.target.value+'，不写入账本';
});
