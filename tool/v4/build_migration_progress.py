"""Build the standalone Chinese page dashboard from the migration inventory."""

from datetime import datetime
from pathlib import Path
from urllib.parse import urlencode
from zoneinfo import ZoneInfo
import collections
import html
import json
import re
from migration_question_dashboard import question_panel


def build_progress_page(root, config, inventory_rows, scenes):
    root = Path(root)
    inventory = {row['source']: row for row in inventory_rows}
    rows = []
    for source, page in config['pages'].items():
        path = 'lib/pages/' + source
        rows.append({**inventory.get(path, {}), **page, 'source': path})
    for page in config['plannedPages']:
        rows.append({**page, 'planned': True})
    assert len({row['source'] for row in rows}) == len(rows)
    assert all(re.search(r'[\u4e00-\u9fff]', row['name']) for row in rows)

    def kind(row):
        status = row['status']
        if status == '已完成':
            return 'done'
        if status.startswith('部分'):
            return 'partial'
        if status.startswith('迁移中'):
            return 'active'
        if status in ('待迁移', '待新增'):
            return 'todo'
        raise ValueError('Unmapped page status: ' + status)

    labels = {'done': '整页验收完成', 'active': '迁移中',
              'partial': '部分完成 · 待确认', 'todo': '未开始'}
    counts = collections.Counter(kind(row) for row in rows)
    done, total = counts['done'], len(rows)
    ratio = round(100 * done / total, 1)
    current = config.get('currentProgress', config['lastProgressReport'])
    engineering = current['engineeringEstimatePercent']
    estimate_range = current.get('engineeringEstimateRange', [engineering] * 2)
    last_report = config['lastProgressReport']
    hours = current.get('remainingEffortEstimateHours', last_report['remainingEffortEstimateHours'])
    time_kind = current.get('remainingEffortEstimateKind', '实际工作小时')
    estimate_at = current.get('updatedAt', last_report['reportedAt']) if 'remainingEffortEstimateHours' in current else last_report['reportedAt']
    report_time = datetime.fromisoformat(estimate_at).astimezone(
        ZoneInfo('Asia/Shanghai')).strftime('%m月%d日 %H:%M')
    timestamp = datetime.now(ZoneInfo('Asia/Shanghai')).strftime('%Y-%m-%d %H:%M')
    pr_state = config.get('pullRequest', {}).get('state', '')
    pr_label = '暂时关闭，准备就绪后再开' if pr_state == 'CLOSED' else '已打开' if pr_state == 'OPEN' else '尚未创建'
    esc = lambda value: html.escape(str(value), quote=True)
    titles = {scene['route']: scene['title'] for scene in scenes}
    by_slug = {scene['slug']: scene for scene in scenes}
    questions = question_panel(root, config)

    def render_row(row):
        state = kind(row)
        badge = labels[state]
        if state == 'active' and row.get('implementationStage') == 'implemented':
            badge = '代码已实现 · 待验收'
        if row.get('planned') and state == 'todo':
            badge = '待新增'
        percent = ' · 100%' if state == 'done' else ''
        question_ids = sorted(set(re.findall(r'Q\d+', row['status'])))
        if row.get('planned') and row['name'] == '账单详情':
            question_ids = ['Q01']
        chips = ''.join('<a class="question-link" href="#question-' + esc(q) + '">'
                        + esc(q) + (' 已确认' if questions['states'].get(q) == 'resolved' else ' 待确认')
                        + '</a>' for q in question_ids)
        routes = row.get('designRoutes', [])
        links = []
        previews = []
        for index, route in enumerate(routes):
            assert isinstance(route, str) and 0 < len(route) < 200 and not re.search(r'[\x00-\x1f]', route), route
            if route in titles:
                params, title = {'page': route}, titles[route]
            elif route in by_slug:
                scene = by_slug[route]
                params, title = {'page': scene['route'], 'scene': scene['slug']}, scene['title']
            else:
                continue
            url = 'prototype/demo.html?' + urlencode(params)
            previews.append(url)
            links.append('<a href="' + esc(url)
                         + '" target="_blank" rel="noopener">' + esc(title) + '</a>')
        primary_link = (
            '<a class="design-link" href="'
            + esc(previews[0])
            + '" target="_blank" rel="noopener">交互设计 ↗</a>'
            if previews else '<span class="muted">交互设计待补齐</span>')
        reason = esc(row.get('reason', ''))
        acceptance = esc(row.get('acceptance', '尚未完成正式页面与整页隔离验收。'))
        detail = ('<details><summary>查看进度依据</summary><div class="evidence">'
                  '<p><strong>当前记录：</strong>' + esc(row['status']) + '</p>'
                  '<p>' + reason + '</p><p><strong>验收记录 / 要求：</strong>'
                  + acceptance + '</p><p class="source">' + esc(row['source'])
                  + '</p><nav class="state-links">' + ''.join(links)
                  + '</nav></div></details>')
        hint = ('已计入完整页数' if state == 'done' else
                '待集成或整页验收，不计完整页' if state == 'active' else
                '尚未计入完整页数' if state == 'partial' else
                '新增页面，尚未开始' if row.get('planned') else '尚未开始迁移')
        planned = '<span class="new-page">新增页面</span>' if row.get('planned') else ''
        return ('<tr class="page-row" data-kind="' + state + '" data-priority="'
                + esc(row['priority']) + '" data-name="' + esc(row['name']) + '">'
                '<td class="page-cell"><div class="page-name">' + esc(row['name'])
                + planned + '</div>' + detail + '</td><td class="status-cell">'
                '<span class="badge ' + state + '"><i></i>' + badge + percent
                + '</span><small>' + hint + '</small>' + chips + '</td>'
                '<td class="action-cell">' + primary_link + '</td></tr>')

    sections = []
    priority_counts = {}
    order = {'active': 0, 'partial': 1, 'todo': 2, 'done': 3}
    for priority in ('P0', 'P1', 'P2'):
        subset = sorted([row for row in rows if row['priority'] == priority],
                        key=lambda row: (order[kind(row)], row['source']))
        priority_counts[priority] = len(subset)
        completed = sum(kind(row) == 'done' for row in subset)
        sections.append('<section class="priority-section" data-priority="' + priority
                        + '"><header class="section-header"><div><h2>' + priority
                        + ' <span>' + {'P0': '核心记账流程', 'P1': '主要业务流程',
                                      'P2': '辅助与设置页面'}[priority] + '</span></h2>'
                        '<p>整页完成 ' + str(completed) + ' / ' + str(len(subset))
                        + ' 页 · <span class="shown">' + str(len(subset))
                        + '</span> 页显示中</p></div><progress aria-label="'
                        + priority + ' 整页完成进度" value="' + str(completed)
                        + '" max="' + str(len(subset)) + '"></progress></header>'
                        '<table><thead><tr><th>页面名称</th><th>当前进度</th><th>预览</th>'
                        '</tr></thead><tbody>' + ''.join(render_row(row) for row in subset)
                        + '</tbody></table></section>')

    revision_cards = []
    for task in config.get('parallelDesignTasks', []):
        url = task.get('url', '')
        link = ('<a class="design-link" href="' + esc(url)
                + '" target="_blank" rel="noopener">交互设计 ↗</a>') if url else ''
        revision_cards.append('<article class="summary-card"><strong>'
                              + esc(task['id'] + ' · ' + task['name'])
                              + '</strong><p>' + esc(task['status']) + '</p>'
                              + link + '</article>')
    revisions = ('<section id="design-revisions" aria-label="新增设计修订"><h2>新增设计修订</h2>'
                 '<p class="muted">上方页数按原迁移基线的已封存版本统计。以下新修订单独验收，'
                 '不能用旧版整页通过或局部测试代替新版通过。</p>'
                 '<div class="revision-grid">' + ''.join(revision_cards) + '</div></section>') if revision_cards else ''

    css = """
*{box-sizing:border-box}html{color-scheme:light}body{margin:0;background:#f5f6f7;color:#25282c;font:14px/1.6 -apple-system,BlinkMacSystemFont,'PingFang SC',system-ui,sans-serif}button,input,select{font:inherit}button,a,input,select,summary{-webkit-tap-highlight-color:transparent}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:2px solid #a37f00;outline-offset:3px}main{max-width:1180px;margin:auto;padding:32px 22px 64px}h1{font-size:29px;line-height:1.25;letter-spacing:-.7px;margin:8px 0 12px}h2{margin:0;font-size:20px}h2 span{font-size:14px;font-weight:500;margin-left:6px}.eyebrow{color:#777c82;font-size:12px;letter-spacing:1px}.intro,.muted{color:#777c82}.intro{max-width:790px;margin:0}.top{display:flex;justify-content:space-between;gap:20px;align-items:start}.tools{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}.button,.tools a,.design-link{display:inline-flex;align-items:center;justify-content:center;min-height:44px;border-radius:13px;padding:8px 13px;background:white;border:1px solid #e4e7e9;color:inherit;text-decoration:none;cursor:pointer}.button.primary{background:#f8c91c;border-color:#f8c91c}.summary-grid{display:grid;grid-template-columns:1.55fr repeat(3,1fr);gap:12px;margin:24px 0 14px}.summary-card{background:white;border-radius:22px;padding:20px;min-width:0}.summary-card .label{display:block;color:#777c82;font-size:12px}.number{font-size:34px;line-height:1.3;font-weight:700;font-variant-numeric:tabular-nums;margin:9px 0 5px}.number small{font-size:17px;font-weight:500;color:#777c82}.caption{font-size:12px;color:#777c82}.summary-card.done-card .number{color:#25856d}.estimate{display:flex;gap:12px 22px;align-items:center;justify-content:space-between;background:#fff9e5;border-radius:16px;padding:14px 18px;font-size:12px}.estimate strong{font-size:14px}.estimate p{margin:0}.meta{display:flex;gap:12px;flex-wrap:wrap;font-size:12px;color:#777c82;margin:13px 0 20px}.filters{position:sticky;top:0;z-index:2;display:flex;align-items:center;gap:10px;flex-wrap:wrap;background:#f5f6f7ed;backdrop-filter:blur(12px);padding:12px 0}.tabs{display:flex;gap:5px;background:#eceeef;padding:4px;border-radius:14px}.tabs button{border:0;border-radius:10px;padding:9px 12px;min-height:38px;cursor:pointer;background:transparent;color:inherit;white-space:nowrap}.tabs button[aria-pressed=true]{background:white;box-shadow:0 1px 4px #0000000a}.filters input[type=search],.filters select{border:1px solid #e2e5e8;background:white;border-radius:13px;min-height:44px;padding:9px 12px;color:inherit;max-width:100%;min-width:0}.filters input[type=search]{flex:1;min-width:180px}.unfinished{display:flex;align-items:center;gap:7px;font-size:12px;min-height:44px;cursor:pointer}.unfinished input{accent-color:#c39c00}.result{font-size:12px;color:#777c82;margin:0 0 12px}.priority-section{border-radius:22px;background:white;overflow:hidden;margin:0 0 18px}.section-header{display:flex;align-items:center;justify-content:space-between;gap:20px;padding:20px 22px;border-bottom:1px solid #eceeef}.section-header p{margin:4px 0 0;color:#777c82;font-size:12px}progress{appearance:none;height:7px;width:170px;border:0;border-radius:8px;overflow:hidden;background:#eceeef;accent-color:#25856d}progress::-webkit-progress-bar{background:#eceeef}progress::-webkit-progress-value{background:#25856d;border-radius:8px}progress::-moz-progress-bar{background:#25856d}.done-card progress{width:100%;margin-top:10px}table{border-collapse:collapse;width:100%;table-layout:fixed}th{font-size:11px;color:#777c82;text-align:left;font-weight:500;padding:11px 22px;background:#fbfcfc}th:first-child{width:55%}th:nth-child(2){width:29%}th:last-child{width:16%}td{padding:15px 22px;vertical-align:top;border-top:1px solid #eceeef}.page-name{font-weight:600;overflow-wrap:anywhere}.status-cell small{display:block;color:#777c82;font-size:11px;margin-top:5px}.badge{display:inline-flex;align-items:center;gap:7px;font-size:12px;border-radius:8px;padding:4px 8px;white-space:nowrap}.badge i{width:6px;height:6px;border-radius:50%;background:currentColor}.done{color:#25856d;background:#edf7f3}.active{color:#8c7000;background:#fff7d7}.partial{color:#ae574a;background:#fcf0eb}.todo{color:#777c82;background:#f3f4f5}.question,.new-page{display:inline-block;background:#f3f4f5;color:#777c82;border-radius:6px;font-size:10px;padding:1px 6px;margin:6px 4px 0 0}.new-page{margin-left:8px;vertical-align:middle}.design-link{font-size:12px;min-height:36px;background:#fff9e5;border-color:transparent;white-space:nowrap}details{margin-top:6px;font-size:12px;color:#777c82}summary{cursor:pointer;min-height:24px;line-height:24px}.evidence{padding:9px 12px;margin-top:8px;background:#f8f9fa;border-radius:12px;color:#53585d;overflow-wrap:anywhere}.evidence p{margin:7px 0;white-space:pre-line}.source{font:10px/1.6 ui-monospace,SFMono-Regular,monospace;color:#777c82}.state-links{display:flex;flex-direction:column;gap:5px;margin:12px 0}.state-links a{color:#8b6d00;text-decoration:none;min-height:26px}.empty{padding:40px;text-align:center;color:#777c82;border-radius:22px;background:white}.footer{color:#777c82;font-size:12px;line-height:1.8;margin-top:24px}.footer a{color:#826505}.footer code{overflow-wrap:anywhere}.page-row[hidden],.priority-section[hidden],[hidden]{display:none!important}@media(max-width:760px){main{padding:24px 14px 48px}.top{display:block}.tools{justify-content:flex-start;margin-top:18px}h1{font-size:25px}.summary-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.summary-card{padding:16px}.summary-card:first-child{grid-column:1/-1}.summary-card:nth-child(4){grid-column:1/-1}.estimate{display:block}.estimate p+p{margin-top:8px}.filters{gap:8px}.tabs{width:100%;justify-content:space-between}.tabs button{padding:8px 9px}.filters input[type=search]{width:100%;flex-basis:100%}.filters select{flex:1}.section-header{padding:17px;align-items:flex-start}.section-header progress{width:82px;margin-top:13px;flex:0 0 82px}thead{display:none}table,tbody{display:block}.page-row{display:grid;grid-template-columns:minmax(0,1fr) auto;padding:15px 17px;border-top:1px solid #eceeef;gap:9px}.page-row:first-child{border-top:0}td{padding:0;border:0;display:block;min-width:0}.page-cell{grid-column:1/-1}.status-cell{grid-column:1;align-self:center}.action-cell{grid-column:2;align-self:start}.badge{font-size:11px}.page-name{font-size:14px}.evidence{font-size:12px}.tools a,.tools button{font-size:12px}.number{font-size:32px}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}
"""
    css += '#design-revisions{margin:24px 0}.revision-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,250px),1fr));gap:12px}.revision-grid p{font-size:12px;color:#777c82;overflow-wrap:anywhere}'
    css += questions['css']
    script = """
const search=document.getElementById('search'),status=document.getElementById('status'),unfinished=document.getElementById('unfinished');let priority='';
function filter(){let visible=0;for(const row of document.querySelectorAll('.page-row')){row.hidden=!!((priority&&row.dataset.priority!==priority)||(status.value&&row.dataset.kind!==status.value)||(unfinished.checked&&row.dataset.kind==='done')||(search.value&&!row.dataset.name.toLowerCase().includes(search.value.trim().toLowerCase())));if(!row.hidden)visible++;}for(const section of document.querySelectorAll('.priority-section')){const count=section.querySelectorAll('.page-row:not([hidden])').length;section.hidden=count===0;section.querySelector('.shown').textContent=count;}document.getElementById('result').textContent='显示 '+visible+' / '+document.querySelectorAll('.page-row').length+' 页';document.getElementById('empty').hidden=visible!==0;}
for(const button of document.querySelectorAll('[data-priority-filter]'))button.onclick=()=>{priority=button.dataset.priorityFilter;for(const other of document.querySelectorAll('[data-priority-filter]'))other.setAttribute('aria-pressed',String(other===button));filter();};
search.oninput=filter;status.onchange=filter;unfinished.onchange=filter;document.getElementById('refresh').onclick=()=>location.reload();filter();
"""
    script += questions['script']
    tabs = '<button data-priority-filter="" aria-pressed="true">全部 ' + str(total) + '</button>'
    tabs += ''.join('<button data-priority-filter="' + key + '" aria-pressed="false">'
                    + key + ' · ' + str(value) + '</button>'
                    for key, value in priority_counts.items())
    page = ('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>蜜蜂记账 4.0 · 页面迁移进度</title><style>' + css + '</style>'
            '<main><header class="top"><div><div class="eyebrow">BEECOUNT / V4</div>'
            '<h1>页面翻新进度</h1><p class="intro">' + str(len(config['pages']))
            + ' 个现有页面 + ' + str(len(config['plannedPages'])) + ' 个待新增页面。'
            '按整页隔离验收统计，组件、设计稿和局部测试通过不算页面完成。</p></div>'
            '<nav class="tools"><a href="index.html">设计总览 ↗</a>'
            '<a href="components/ui-components.html#business">组件规范 ↗</a>'
            '<a href="#questions">待确认问题 ' + str(questions['pending']) + '</a>'
            '<button class="button primary" id="refresh">刷新进度</button></nav></header>'
            '<div class="summary-grid"><article class="summary-card done-card">'
            '<span class="label">整页验收完成</span><div class="number">' + str(done)
            + '<small> / ' + str(total) + ' 页</small></div><span class="caption">'
            + str(ratio) + '% · 已迁移并通过完整验收</span><progress value="'
            + str(done) + '" max="' + str(total) + '" aria-label="整页验收完成进度"></progress>'
            '</article>' + ''.join('<article class="summary-card"><span class="label">'
                                 + label + '</span><div class="number">' + str(counts[state])
                                 + '</div><span class="caption">' + caption + '</span></article>'
                                 for state, label, caption in [
                                     ('active', '正在迁移', '实现或验收尚未收口'),
                                     ('partial', '部分完成 · 待确认', '保留已完成工作，待集中回答'),
                                     ('todo', '尚未开始', '包含待新增页面')]) + '</div>'
            '<aside class="estimate"><p><strong>整体工程估计 ' + str(engineering)
            + '%</strong>（' + str(estimate_range[0]) + '%–' + str(estimate_range[1])
            + '%） · 与整页验收完成率分开记录。</p><p>剩余时间预估：<strong>'
            + str(hours[0]) + '–' + str(hours[1]) + ' 个' + esc(time_kind) + '</strong><br>'
            + esc(report_time) + ' 更新，估算不是交付承诺。</p></aside>'
            '<div class="meta"><span>看板生成：' + esc(timestamp) + '（北京时间）</span>'
            '<span>分支：v4</span><span>PR：' + esc(pr_label) + '</span></div>'
            '<section class="filters" aria-label="筛选页面"><nav class="tabs" aria-label="优先级">'
            + tabs + '</nav><input id="search" type="search" placeholder="搜索中文页面名，例如：记账、导入" aria-label="搜索页面名称">'
            '<select id="status" aria-label="筛选进度"><option value="">全部进度</option>'
            '<option value="done">整页验收完成</option><option value="active">迁移中</option>'
            '<option value="partial">部分完成 · 待确认</option><option value="todo">未开始 / 待新增</option></select>'
            '<label class="unfinished"><input id="unfinished" type="checkbox">只看未完成</label></section>'
            '<p class="result" id="result" role="status" aria-live="polite"></p>'
            + revisions + questions['html'] + ''.join(sections) + '<div class="empty" id="empty" hidden>没有匹配页面，试试其他筛选条件。</div>'
            '<footer class="footer">数据来源：<code>tool/v4/migration-status.json</code>。'
            '每次更新迁移清单后自动重建此看板，打开“进度依据”可核对实现与验收范围。'
            '<br>页面名使用中文；每页的“交互设计”进入对应可操作设计稿。'
            '已实现、部分完成和整页验收完成保持独立，不以设计场景数量代替页面数量。</footer>'
            '</main><script>' + script + '</script></html>')
    output = root / 'docs/design/card-refresh/migration-progress.html'
    output.write_text(page)
    return {'pages': total, 'completed': done, 'inProgress': counts['active'],
            'partial': counts['partial'], 'notStarted': counts['todo'],
            'priorities': priority_counts, 'questions': questions['total'],
            'pendingQuestions': questions['pending'], 'output': str(output.relative_to(root))}


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    config = json.loads((root / 'tool/v4/migration-status.json').read_text())
    inventory = json.loads((root / 'docs/development/v4-page-inventory.json').read_text())
    scenes = json.loads((root / 'docs/design/card-refresh/screens/manifest.json').read_text())
    print(json.dumps(build_progress_page(root, config, inventory['rows'], scenes), ensure_ascii=False))
