"""Render decision questions without turning browser drafts into approvals."""

from collections import Counter
from html import escape
import re


OPTIONS = {
    'Q01': ['点击账单默认进入详情，详情内可编辑', '保留点击直接编辑，另设详情入口', '增加可切换的点击行为偏好'],
    'Q04': ['继续只允许新增同币种转账', '4.0 增加跨币种转账，后续确定转入金额与汇率规则'],
    'Q05': ['更多分类只展示当前收支类型', '弹层保留收支切换，并联动主表单'],
    'Q06': ['继续限制为当前账本币种的账户', '允许在其他本位币账本中选择同一外币账户对'],
    'Q07': ['保留分类优先的默认值', '仅新用户默认备注优先，已有用户偏好保持'],
    'Q08': ['本次不新增成功后的批量撤销', '增加批量撤销，再确定附件、同步及退出后的恢复范围'],
    'Q09': ['保留选择账户后打开金额弹层', '改为转账账户与金额在同一页面录入'],
    'Q10': ['分类详情默认全部时间', '分类详情默认本月'],
    'Q11': ['按币种分别汇总', '统一换算为当前账本币种，再确定汇率时点', '只展示分账本金额，不合计跨币种总额'],
    'Q15': ['保留缩略图持续播放', '关闭动效时，缩略图也停止播放'],
    'Q16': ['只支持 TAR.GZ，移除不支持的原始 TAR 入口', '增加原始 TAR 的真实兼容'],
    'Q18': ['已有预算保持原分类，只编辑原有字段', '允许转移分类，再确定目标已有预算时的处理'],
    'Q19': ['保留原用户档案与应用分享模板', '新增独立的全部账本总览海报'],
    'Q20': ['保留完整周期天数或月份的平均值', '按截至今天已经发生的天或月份计算', '两种口径都展示，并明确标注'],
    'Q23': ['保留原账本历史金额，再按查询时汇率汇总', '按每笔记账日的历史汇率汇总', '从交易原币全部按查询时汇率重算'],
    'Q22': ['保留文本输入和原工具授权流程', '新增语音输入', '新增保存前统一预览确认', '语音输入和保存前确认都增加'],
}


def question_panel(root, config):
    source = root / 'docs/development/v4-migration-questions.md'
    records = []
    for line in source.read_text().splitlines():
        if not re.match(r'^\| Q\d+ \|', line):
            continue
        cells = [part.strip() for part in line.strip().strip('|').split('|')]
        assert len(cells) == 5, line
        identifier, area, prompt, handling, status = cells
        if '已确认' in status or '已解决' in status:
            state = 'resolved'
        elif '待确认' in status or '待用户集中确认' in status:
            state = 'pending'
        elif '无需决定' in status or '差异记录' in status:
            state = 'record'
        else:
            state = 'followup'
        records.append(dict(id=identifier, area=area, prompt=prompt,
                            handling=handling, status=status, state=state))
    assert len({row['id'] for row in records}) == len(records)
    blockers = {'Q01'}
    for page in config['pages'].values():
        if page['status'].startswith('部分'):
            blockers.update(re.findall(r'Q\d+', page['status']))
    counts = Counter(row['state'] for row in records)
    labels = {'pending': '待你确认', 'followup': '后续技术核对',
              'record': '仅记录边界', 'resolved': '已确认 / 已解决'}
    cards = []
    for row in sorted(records, key=lambda row: (row['id'] not in blockers, int(row['id'][1:]))):
        identifier = row['id']
        choices = ''.join(
            '<button type="button" class="q-option" data-q-choice="'
            + escape(identifier) + '" data-choice="' + chr(65 + index)
            + '" aria-pressed="false">' + chr(65 + index) + ' · '
            + escape(value) + '</button>'
            for index, value in enumerate(OPTIONS.get(identifier, [])))
        form = ('<div class="q-options">' + choices + '</div>'
                '<label class="q-answer-label" for="answer-' + identifier
                + '">你的答复草稿</label><textarea id="answer-' + identifier
                + '" data-q-answer="' + identifier
                + '" rows="2" placeholder="选 A，或直接写你的想法；也可以补充条件。"></textarea>'
                '<div class="q-copy-row"><button type="button" class="button" data-q-copy="'
                + identifier + '">复制这条答复</button><span data-q-feedback="'
                + identifier + '" aria-live="polite">在聊天中发送后才会记为确认。</span></div>'
                if row['state'] == 'pending' else '')
        block = '<span class="q-blocker">影响入口或整页验收</span>' if identifier in blockers else ''
        cards.append(
            '<details class="q-card" id="question-' + identifier
            + '" data-q-state="' + row['state'] + '" data-q-blocker="'
            + str(identifier in blockers).lower() + '" data-q-search="'
            + escape(identifier + ' ' + row['area'] + ' ' + row['prompt'], quote=True)
            + '"><summary><span class="q-id">' + identifier + '</span><span class="q-title">'
            + escape(row['area']) + '</span><span class="q-status">'
            + labels[row['state']] + '</span>' + block + '</summary><div class="q-body">'
            '<p class="q-prompt">' + escape(row['prompt']) + '</p>'
            '<p><strong>当前处理：</strong>' + escape(row['handling']) + '</p>'
            '<p class="q-original">原记录：' + escape(row['status']) + '</p>'
            + form + '</div></details>')
    tabs = ''.join('<button data-q-filter="' + state + '" aria-pressed="'
                   + str(state == ('pending' if counts['pending'] else 'all')).lower() + '">' + label + ' '
                   + str(counts[state]) + '</button>'
                   for state, label in labels.items() if counts[state] or state == 'pending')
    panel = ('<details class="question-panel" id="questions"><summary>'
             '<strong>问题列表</strong><span>' + str(counts['pending'])
             + ' 项待你确认 · ' + str(counts['followup']) + ' 项后续核对 · '
             + str(counts['record']) + ' 项仅记录 · ' + str(counts['resolved']) + ' 项已确认</span></summary><div class="q-panel-body">'
             '<p class="q-instruction">可以随时在聊天中回复，例如 <code>Q09：选 A</code>。'
             '下面的选项和输入框只保存浏览器草稿；复制到聊天并发送后，我才会记录为确认并修改实现。'
             '问题数与待确认页面数不同，新增能力的选择不一定阻塞现有页面迁移。</p>'
             '<div class="q-toolbar"><nav class="q-tabs">' + tabs
             + '<button data-q-filter="all" aria-pressed="' + str(not counts['pending']).lower() + '">全部 '
             + str(len(records)) + '</button></nav><input type="search" id="question-search" '
             'aria-label="搜索问题" placeholder="搜索 Q09、转账、币种等"><button class="button" '
             'id="copy-all-answers">复制全部答复草稿</button></div><p class="q-result" '
             'id="question-result" role="status"></p>' + ''.join(cards)
             + '<p class="q-copy-status" id="all-answers-feedback" role="status"></p></div></details>')
    css = """
.question-panel{background:white;border-radius:22px;margin:4px 0 20px;scroll-margin-top:180px}.question-panel>summary{display:flex;flex-wrap:wrap;gap:8px 20px;align-items:center;min-height:64px;padding:17px 22px;color:#25282c;list-style:none}.question-panel>summary::after{content:'展开 / 收起';margin-left:auto;color:#8b6d00;font-size:12px}.question-panel>summary strong{font-size:17px}.question-panel>summary>span{font-size:12px;color:#777c82}.q-panel-body{padding:0 22px 22px}.q-instruction{font-size:12px;color:#777c82;line-height:1.8;margin:0 0 16px}.q-instruction code{color:#8b6d00;background:#fff9e5;border-radius:5px;padding:2px 5px}.q-toolbar{display:flex;gap:9px;flex-wrap:wrap;align-items:center}.q-tabs{display:flex;gap:5px;flex-wrap:wrap}.q-tabs button{border:0;border-radius:10px;padding:8px 11px;min-height:40px;background:#f3f4f5;cursor:pointer}.q-tabs button[aria-pressed=true]{background:#fff5cd;color:#8b6d00}.q-toolbar input{min-width:0;flex:1;border:1px solid #e2e5e8;border-radius:12px;padding:9px 12px;min-height:44px}.q-result{font-size:12px;color:#777c82}.q-card{border:1px solid #e8ebee;border-radius:15px;margin-top:10px;color:#25282c;scroll-margin-top:180px}.q-card>summary{list-style:none;padding:14px;display:flex;flex-wrap:wrap;align-items:center;gap:5px 10px;font-size:13px;line-height:1.6}.q-id{font:600 12px ui-monospace,monospace;color:#8b6d00;background:#fff9e5;padding:3px 6px;border-radius:6px}.q-title{font-weight:600;flex:1;min-width:150px}.q-status{font-size:11px;color:#777c82}.q-blocker{font-size:10px;background:#fcf0eb;color:#ae574a;border-radius:5px;padding:2px 6px}.q-body{padding:0 16px 16px;border-top:1px solid #eceeef;font-size:13px;line-height:1.8;overflow-wrap:anywhere}.q-prompt{font-size:14px;font-weight:600}.q-original{font-size:11px;color:#777c82}.q-options{display:flex;flex-wrap:wrap;gap:7px;margin:14px 0}.q-option{border:1px solid #e3e6e9;background:#f8f9fa;border-radius:10px;padding:9px 12px;min-height:44px;color:inherit;cursor:pointer;text-align:left;font-size:12px;max-width:100%}.q-option[aria-pressed=true]{background:#fff5cd;border-color:#d8ad11}.q-answer-label{display:block;color:#777c82;font-size:12px;margin-top:14px}.q-body textarea{display:block;width:100%;resize:vertical;min-height:76px;font:inherit;padding:10px 12px;margin-top:6px;border:1px solid #dfe3e6;border-radius:12px;background:#fbfcfc;color:inherit}.q-copy-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-top:10px}.q-copy-row span,.q-copy-status{color:#777c82;font-size:11px}.question-link{font-size:10px;padding:1px 6px;background:#fff9e5;color:#8b6d00;border-radius:6px;text-decoration:none;display:inline-block;margin:5px 4px 0 0}@media(max-width:760px){.q-panel-body{padding:0 14px 16px}.question-panel>summary{padding:15px 17px}.question-panel>summary::after{margin-left:0}.q-toolbar input{flex-basis:100%}.q-title{min-width:120px}.q-body{padding:0 12px 12px}.q-option{width:100%}.q-tabs button{font-size:11px;padding:8px}.q-copy-row .button{width:100%}}
"""
    script = """
const qPanel=document.getElementById('questions'),qSearch=document.getElementById('question-search');let qFilter='pending';const draftKey='beecount-v4-migration-answer-drafts-v1';let qDrafts={};try{qDrafts=JSON.parse(localStorage.getItem(draftKey)||'{}')}catch{};
function saveDraft(id,value){qDrafts[id]=value;try{localStorage.setItem(draftKey,JSON.stringify(qDrafts))}catch{}}
function markChoices(id,value){for(const button of document.querySelectorAll('[data-q-choice="'+id+'"]'))button.setAttribute('aria-pressed',String(value.startsWith('选 '+button.dataset.choice)));}
for(const field of document.querySelectorAll('[data-q-answer]')){field.value=qDrafts[field.dataset.qAnswer]||'';markChoices(field.dataset.qAnswer,field.value);field.oninput=()=>{saveDraft(field.dataset.qAnswer,field.value);markChoices(field.dataset.qAnswer,field.value)}}
function filterQuestions(){let count=0;for(const card of document.querySelectorAll('.q-card')){card.hidden=!!((qFilter!=='all'&&card.dataset.qState!==qFilter)||(qSearch.value&&!card.dataset.qSearch.toLowerCase().includes(qSearch.value.trim().toLowerCase())));if(!card.hidden)count++;}document.getElementById('question-result').textContent='显示 '+count+' / '+document.querySelectorAll('.q-card').length+' 项；草稿不会自动改变问题状态。';}
for(const button of document.querySelectorAll('[data-q-filter]'))button.onclick=()=>{qFilter=button.dataset.qFilter;for(const other of document.querySelectorAll('[data-q-filter]'))other.setAttribute('aria-pressed',String(other===button));filterQuestions()};qSearch.oninput=filterQuestions;
for(const button of document.querySelectorAll('[data-q-choice]'))button.onclick=()=>{const id=button.dataset.qChoice,field=document.querySelector('[data-q-answer="'+id+'"]');field.value='选 '+button.dataset.choice+'：'+button.textContent.replace(/^[A-Z] · /,'');saveDraft(id,field.value);markChoices(id,field.value)};
async function copyReply(text){if(navigator.clipboard?.writeText){await navigator.clipboard.writeText(text);return}const helper=document.createElement('textarea');helper.value=text;document.body.appendChild(helper);helper.select();const copied=document.execCommand('copy');helper.remove();if(!copied)throw Error('copy unavailable')}
for(const button of document.querySelectorAll('[data-q-copy]'))button.onclick=async()=>{const id=button.dataset.qCopy,field=document.querySelector('[data-q-answer="'+id+'"]'),feedback=document.querySelector('[data-q-feedback="'+id+'"]');if(!field.value.trim()){feedback.textContent='请先选择一个选项或填写答复。';field.focus();return}try{await copyReply(id+'：'+field.value.trim());feedback.textContent='已复制；请粘贴到聊天并发送后生效。'}catch{field.focus();field.select();feedback.textContent='请手动复制，并带上问题编号 '+id+' 发送到聊天。'}};
document.getElementById('copy-all-answers').onclick=async()=>{const values=[...document.querySelectorAll('[data-q-answer]')].filter(field=>field.value.trim()).map(field=>field.dataset.qAnswer+'：'+field.value.trim());const feedback=document.getElementById('all-answers-feedback');if(!values.length){feedback.textContent='还没有答复草稿。';return}try{await copyReply('V4 待确认事项答复：\\n'+values.join('\\n'));feedback.textContent='已复制 '+values.length+' 条草稿；请粘贴到聊天并发送后生效。'}catch{feedback.textContent='无法自动复制，请逐条手动复制到聊天。'}};
function openQuestionHash(){const hash=decodeURIComponent(location.hash);if(hash==='#questions'){qPanel.open=true;return}if(hash.startsWith('#question-')){const card=document.getElementById(hash.slice(1));if(card){qPanel.open=true;card.open=true;qFilter='all';qSearch.value='';for(const button of document.querySelectorAll('[data-q-filter]'))button.setAttribute('aria-pressed',String(button.dataset.qFilter==='all'));filterQuestions();setTimeout(()=>card.scrollIntoView({block:'start'}),0)}}}window.addEventListener('hashchange',openQuestionHash);filterQuestions();openQuestionHash();
"""
    if not counts['pending']:
        script = script.replace("let qFilter='pending'", "let qFilter='all'")
    return {'html': panel, 'css': css, 'script': script,
            'total': len(records), 'pending': counts['pending'],
            'states': {row['id']: row['state'] for row in records}}
