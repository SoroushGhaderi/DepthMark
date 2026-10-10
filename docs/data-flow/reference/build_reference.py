#!/usr/bin/env python3
"""Generate the DepthMark warehouse reference as ONE self-contained HTML file.

Run from anywhere:  python3 docs/data-flow/reference/build_reference.py

Output:
  docs/data-flow/warehouse-pipeline-reference.html

The file inlines its stylesheet, script, and search index, and shows one "page" at a time with
CSS :target, so navigation works with scripts disabled and does not rely on links between files.
Edit assets/reference.css and assets/reference.js directly; they are inlined at build time.

Every cross-page link is written as @@anchor@@ or @@page:slug@@ and resolved here; an unknown
token stops the build, so broken links cannot be generated.
"""
import html
import json
import os
import posixpath
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))
DATA = 'docs/data-flow'
REF = 'docs/data-flow/reference'
INDEX_PATH = 'docs/data-flow/warehouse-pipeline-reference.html'
GH = 'https://github.com/SoroushGhaderi/DepthMark/blob/main/'
VERIFIED = '2026-10-10'

PAGES = [
    # slug, title, group, colour
    ('index', 'Overview', 'Start', 'var(--accent)'),
    ('concepts', 'Concepts & glossary', 'Start', 'var(--accent)'),
    ('fotmob', 'FotMob', 'Sources', 'var(--fotmob)'),
    ('oddspedia', 'Oddspedia', 'Sources', 'var(--oddspedia)'),
    ('bronze', 'Bronze', 'Layers', 'var(--bronze)'),
    ('silver', 'Silver', 'Layers', 'var(--silver)'),
    ('gold', 'Gold', 'Layers', 'var(--gold)'),
    ('scenarios', 'Scenarios', 'Products', 'var(--gold)'),
    ('signals', 'Signals', 'Products', 'var(--gold)'),
    ('mongodb', 'MongoDB catalogs', 'Products', 'var(--accent)'),
    ('commands', 'Command reference', 'Operate', 'var(--accent)'),
    ('orchestration', 'Orchestration', 'Operate', 'var(--accent)'),
    ('quality', 'Quality & acceptance', 'Operate', 'var(--accent)'),
    ('infrastructure', 'Infrastructure', 'Operate', 'var(--accent)'),
    ('contracts', 'Contracts & decisions', 'Reference', 'var(--muted)'),
]
PAGE = {s: (t, g, c) for s, t, g, c in PAGES}
CTX = {'index': 'ctx-ops', 'concepts': 'ctx-ops', 'fotmob': 'ctx-fotmob', 'oddspedia': 'ctx-oddspedia',
       'bronze': 'ctx-bronze', 'silver': 'ctx-silver', 'gold': 'ctx-gold', 'scenarios': 'ctx-gold',
       'signals': 'ctx-gold', 'mongodb': 'ctx-ops', 'commands': 'ctx-ops', 'orchestration': 'ctx-ops',
       'quality': 'ctx-ops', 'infrastructure': 'ctx-ops', 'contracts': 'ctx-ops'}

REG = {}        # anchor id -> page slug
SEARCH = []     # search entries
TOC = []        # (id, title) of h2 sections on the current page
CUR = None      # current page slug
SEC_OPEN = [False]


def esc(s):
    return html.escape(s, quote=True)


def page_path(slug):
    return INDEX_PATH if slug == 'index' else f'{REF}/{slug}.html'


def reg(anchor_id, title, level):
    assert anchor_id not in REG, 'duplicate anchor: ' + anchor_id
    REG[anchor_id] = CUR
    text = re.sub(r'<[^>]+>', '', title)
    if level in (2, 3):
        SEARCH.append({'t': text, 'p': PAGE[CUR][0], 'id': anchor_id, 'page': CUR})
    if level == 2:
        TOC.append((anchor_id, text))


def sec(anchor_id, title, lead=None):
    reg(anchor_id, title, 2)
    out = '</section>' if SEC_OPEN[0] else ''
    SEC_OPEN[0] = True
    out += f'<section id="{anchor_id}"><h2>{title}</h2>'
    if lead:
        out += f'<p class="section-lead">{lead}</p>'
    return out


def sub(anchor_id, title):
    reg(anchor_id, title, 3)
    return f'<h3 id="{anchor_id}">{title}</h3>'


def pill(text, cls):
    return f'<span class="pill {cls}">{text}</span>'


def legend(*keys):
    names = {
        'fotmob': ('lg-fotmob', 'FotMob'), 'oddspedia': ('lg-oddspedia', 'Oddspedia'),
        'bronze': ('lg-bronze', 'Bronze'), 'silver': ('lg-silver', 'Silver'), 'gold': ('lg-gold', 'Gold'),
        'serve': ('lg-serve', 'Serving / catalog'), 'ops': ('lg-ops', 'Process / command'),
        'gate': ('lg-gate', 'Gate / check'), 'danger': ('lg-danger', 'Destructive / failure'),
        'planned': ('lg-planned', 'Planned / excluded'), 'source': ('lg-source', 'External input'),
        'artifact': ('lg-artifact', 'Artifact on disk'), 'muted': ('lg-planned', 'Not used by Silver'),
    }
    return '<div class="legend">' + ''.join(f'<span class="{names[k][0]}">{names[k][1]}</span>' for k in keys) + '</div>'


# ---------------------------------------------------------------- diagrams
def _anchors(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    acx, acy = ax + aw / 2, ay + ah / 2
    bcx, bcy = bx + bw / 2, by + bh / 2
    if bx >= ax + aw - 1:
        return (ax + aw, acy), (bx, bcy), 'h'
    if bx + bw <= ax + 1:
        return (ax, acy), (bx + bw, bcy), 'h'
    if by >= ay + ah - 1:
        return (acx, ay + ah), (bcx, by), 'v'
    return (acx, ay), (bcx, by + bh), 'v'


class Dia:
    count = 0

    def __init__(self, w, h, label):
        Dia.count += 1
        self.id = f'dg{Dia.count}'
        self.w, self.h, self.label = w, h, label
        self.parts = []
        self.nodes = {}

    def region(self, x, y, w, h, label, dashed=False):
        cls = 'region dashed' if dashed else 'region'
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="14"/>')
        if label:
            self.parts.append(f'<text class="region-label" x="{x + 16}" y="{y + 22}">{label}</text>')

    def text(self, x, y, s, cls='note', anchor='start'):
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}" text-anchor="{anchor}">{s}</text>')

    def node(self, key, x, y, w, h, title, sub_text='', kind='ops', href=None):
        self.nodes[key] = (x, y, w, h)
        ty = y + h / 2 - 3 if sub_text else y + h / 2 + 5
        inner = (f'<rect class="node-rect" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>'
                 f'<text class="n-title" x="{x + w / 2}" y="{ty}" text-anchor="middle">{title}</text>')
        if sub_text:
            inner += f'<text class="n-sub" x="{x + w / 2}" y="{y + h / 2 + 13}" text-anchor="middle">{sub_text}</text>'
        if href:
            inner = f'<a href="{href}">{inner}</a>'
        self.parts.append(f'<g class="node k-{kind}">{inner}</g>')

    def edge(self, a, b, label=None, style='', lx=None, ly=None):
        (x1, y1), (x2, y2), o = _anchors(self.nodes[a], self.nodes[b])
        if o == 'h':
            mx = (x1 + x2) / 2
            d = f'M{x1} {y1} C{mx} {y1} {mx} {y2} {x2} {y2}'
        else:
            my = (y1 + y2) / 2
            d = f'M{x1} {y1} C{x1} {my} {x2} {my} {x2} {y2}'
        mk = 'arrow'
        if 'accent' in style:
            mk = 'arrow-accent'
        elif 'danger' in style:
            mk = 'arrow-danger'
        self.parts.append(f'<path class="edge {style}" d="{d}" marker-end="url(#{self.id}-{mk})"/>')
        if label:
            px = lx if lx is not None else (x1 + x2) / 2
            py = ly if ly is not None else (y1 + y2) / 2 - 7
            cls = 'edge-label' + (' accent' if 'accent' in style else '')
            self.parts.append(f'<text class="{cls}" x="{px}" y="{py}" text-anchor="middle">{label}</text>')

    def flag(self, cx, y, label, anchor_y):
        """A dashed flag tag with a leader line down to a stage."""
        w = max(120, len(label) * 7.2 + 18)
        self.parts.append(f'<line x1="{cx}" y1="{y + 24}" x2="{cx}" y2="{anchor_y}" class="leader"/>')
        self.parts.append(
            f'<rect class="flag" x="{cx - w / 2}" y="{y}" width="{w}" height="24" rx="12"/>'
            f'<text class="flag-text" x="{cx}" y="{y + 16}" text-anchor="middle">{label}</text>')

    def render(self, caption, leg=''):
        def marker(name, color):
            return (f'<marker id="{self.id}-{name}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" '
                    f'markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{color}"/></marker>')
        defs = ('<defs>' + marker('arrow', '#94a3b8') + marker('arrow-accent', '#7c3aed')
                + marker('arrow-danger', '#dc2626') + '</defs>')
        svg = (f'<svg viewBox="0 0 {self.w} {self.h}" role="img" aria-label="{esc(self.label)}">'
               + defs + ''.join(self.parts) + '</svg>')
        return (f'<figure class="diagram"><div class="diagram-scroll">{svg}</div>{leg}'
                f'<figcaption>{caption}</figcaption></figure>')


def dia_index():
    d = Dia(1000, 300, 'Pipeline map: FotMob and Oddspedia lanes')
    d.region(10, 8, 980, 122, 'FotMob')
    d.region(10, 150, 980, 140, 'Oddspedia')
    d.node('api', 40, 50, 170, 70, 'FotMob API', 'per-match JSON', 'source', '@@page:fotmob@@')
    d.node('fb', 290, 50, 170, 70, 'Bronze', 'bronze.* · 15 tables', 'bronze', '@@page:bronze@@')
    d.node('fs', 540, 50, 170, 70, 'Silver', 'silver.* · 8 tables', 'silver', '@@page:silver@@')
    d.node('fg', 790, 50, 170, 70, 'Gold', '48 scenarios · 344 signals', 'gold', '@@page:gold@@')
    d.node('src', 40, 200, 170, 70, 'Oddspedia intake', 'discover · scrape', 'oddspedia', '@@page:oddspedia@@')
    d.node('ob', 290, 200, 170, 70, 'Bronze', 'oddspedia_bronze.* · 4', 'bronze', '@@page:oddspedia@@')
    d.node('res', 540, 200, 170, 70, 'Silver resolution', 'resolution edge · 1 table', 'silver', '@@oddspedia-resolution@@')
    d.node('og', 790, 200, 170, 70, 'Gold', 'planned', 'planned', '@@page:oddspedia@@')
    d.edge('api', 'fb')
    d.edge('fb', 'fs')
    d.edge('fs', 'fg')
    d.edge('src', 'ob')
    d.edge('ob', 'res')
    d.edge('res', 'og', style='dashed')
    d.edge('fs', 'res', 'resolution edge · reads silver.match', style='accent', lx=650, ly=160)
    return d.render('Each lane is independent. The only shared surface is the dashed purple resolution edge.',
                    legend('fotmob', 'oddspedia', 'bronze', 'silver', 'gold', 'planned'))


def dia_matrix():
    d = Dia(1000, 470, 'Ownership matrix by layer and source')
    cols = {'f': (150, 270), 'o': (440, 270), 's': (730, 250)}
    rows = {'b': 70, 's': 170, 'g': 270, 'v': 370}
    for k, t in (('f', 'FotMob'), ('o', 'Oddspedia'), ('s', 'Shared')):
        d.text(cols[k][0], 52, t, 'head')
    for k, t in (('b', 'Bronze'), ('s', 'Silver'), ('g', 'Gold'), ('v', 'Serving')):
        d.text(20, rows[k] + 42, t, 'head')
    H = 72
    d.node('bf', 150, 70, 270, H, 'bronze.* · 15 tables', 'historical artifacts → raw facts', 'fotmob', '@@page:bronze@@')
    d.node('bo', 440, 70, 270, H, 'oddspedia_bronze.* · 4', 'artifacts → staged → published', 'oddspedia', '@@page:oddspedia@@')
    d.node('bs', 730, 70, 250, H, 'Shared mechanics', 'scoped staging · checksums · DLQ', 'source', '@@page:orchestration@@')
    d.node('sf', 150, 170, 270, H, 'silver.* · 8 tables', 'silver.match = fixture reference', 'fotmob', '@@page:silver@@')
    d.node('so', 440, 170, 270, H, 'resolution edge · 1 table', 'reads silver.match, never writes it', 'oddspedia', '@@oddspedia-resolution@@')
    d.node('ss', 730, 170, 250, H, 'scope_publication', 'committing · published · failed', 'source', '@@page:silver@@')
    d.node('gf', 150, 270, 270, H, 'gold_scenarios · gold_signals', '48 scenarios · 344 signals', 'fotmob', '@@page:gold@@')
    d.node('go', 440, 270, 270, H, 'Planned', 'own namespace and commands', 'planned', '@@page:oddspedia@@')
    d.node('gs', 730, 270, 250, H, 'gold.* metadata', 'signal_activations · scope_publication', 'source', '@@page:gold@@')
    d.node('vf', 150, 370, 270, H, 'MongoDB signals', 'synced from Git catalogs', 'serve', '@@page:mongodb@@')
    d.node('vo', 440, 370, 270, H, 'Not yet defined', 'no catalog or API', 'planned', '@@page:oddspedia@@')
    d.node('vs', 730, 370, 250, H, 'orbit_content · 5 collections', 'indexes and serving copies', 'serve', '@@page:mongodb@@')
    d.edge('bf', 'sf'); d.edge('sf', 'gf'); d.edge('gf', 'vf')
    d.edge('bo', 'so'); d.edge('so', 'go', style='dashed')
    d.edge('bs', 'ss', style='accent')
    return d.render('Blue cells are FotMob, violet cells are Oddspedia, and dashed cells are planned or not defined.',
                    legend('fotmob', 'oddspedia', 'bronze', 'silver', 'gold', 'serve', 'source', 'planned'))


def dia_scope():
    d = Dia(1000, 250, 'Output scope: date, month, and full history')
    rows = [
        ('DATE RUN', 'D = day 3. Replaces one date.', 40, 2, 'keeps the other dates'),
        ('MONTH RUN', 'Replaces the month partition.', 120, None, 'other months untouched'),
        ('FULL HISTORY', 'Explicit only. Whole-table exchange.', 200, None, 'EXCHANGE TABLES'),
    ]
    for title, sub_t, y, hi, note in rows:
        d.text(20, y + 22, title, 'head')
        d.text(20, y + 40, sub_t, 'note')
        for i in range(6):
            x = 300 + i * 112
            if hi is None or i == hi:
                kind, lab = 'hi', ('replaced')
            else:
                kind, lab = 'keep', 'kept'
            d.node(f'{title[:2]}{i}{y}', x, y, 104, 48, f'day {i + 1}', lab, kind)
        d.text(300, y + 66, note, 'note')
    return d.render('Scope decides what a run may replace. Anything outside the scope is never touched.',
                    '<div class="legend"><span class="lg-serve">Replaced by this run</span>'
                    '<span class="lg-source">Kept</span></div>')


def dia_lineage():
    d = Dia(1000, 520, 'FotMob Bronze to Silver lineage')
    d.text(20, 36, 'BRONZE · 15 tables', 'head')
    d.text(370, 36, 'SILVER · 8 tables', 'head')
    d.text(720, 36, 'GOLD', 'head')
    bronze = ['general', 'timeline', 'venue', 'player', 'shotmap', 'goal', 'cards', 'red_card',
              'period', 'momentum', 'starters', 'substitutes', 'coaches', 'team_form', 'match_reference']
    unused = {'goal', 'red_card', 'starters', 'match_reference'}
    for i, b in enumerate(bronze):
        kind = 'muted' if b in unused else 'bronze'
        d.node('b_' + b, 20, 50 + i * 30, 200, 24, f'bronze.{b}', '', kind, '@@page:bronze@@')
    silver = ['match', 'period_stat', 'player_match_stat', 'momentum', 'shot', 'card', 'match_personnel', 'team_form']
    for j, s in enumerate(silver):
        d.node('s_' + s, 370, 50 + j * 58, 200, 34, f'silver.{s}', '', 'silver', '@@page:silver@@')
    d.node('gold', 720, 210, 250, 70, 'Gold SQL', '48 scenarios · 344 signals', 'gold', '@@page:gold@@')
    mapping = [
        ('general', 'match'), ('timeline', 'match'), ('venue', 'match'), ('period', 'period_stat'),
        ('player', 'player_match_stat'), ('momentum', 'momentum'), ('shotmap', 'shot'), ('cards', 'card'),
        ('coaches', 'match_personnel'), ('substitutes', 'match_personnel'), ('team_form', 'team_form'),
    ]
    for b, s in mapping:
        d.edge('b_' + b, 's_' + s)
    for s in silver:
        d.edge('s_' + s, 'gold', style='dashed')
    d.text(720, 320, 'Gold reads all Silver tables', 'note')
    d.text(20, 512, 'Greyed Bronze tables have no current Silver input (ADR-level contract needed to add one).', 'note')
    return d.render('Each arrow is a direct Bronze input to a Silver table (from the DML scripts). '
                    'Dashed arrows show Gold reading the Silver layer as a whole.',
                    legend('bronze', 'silver', 'gold', 'planned'))


def dia_gold():
    d = Dia(1000, 440, 'How FotMob Gold is built')
    d.node('silver', 30, 160, 190, 80, 'silver.* · 8', 'conformed FotMob facts', 'silver', '@@page:silver@@')
    d.node('scen', 330, 40, 230, 70, 'Scenario SQL · 48', 'gold_scenarios.scenario_*', 'gold', '@@page:scenarios@@')
    d.node('sig', 330, 160, 230, 70, 'Signal SQL · 344', 'gold_signals.sig_*', 'gold', '@@page:signals@@')
    d.node('cat', 330, 290, 230, 70, 'Active catalogs', 'signal catalogs *.md', 'source', '@@page:mongodb@@')
    d.node('reb', 650, 205, 230, 70, 'Activation rebuild', 'build_signal_activations.py', 'ops', '@@gold-activation@@')
    d.node('act', 650, 60, 230, 70, 'gold.signal_activations', 'one serving table', 'gold', '@@gold-activation@@')
    d.node('meta', 650, 330, 230, 60, 'gold.scope_publication', 'batch status per scope', 'source', '@@page:gold@@')
    d.edge('silver', 'scen')
    d.edge('silver', 'sig')
    d.edge('sig', 'reb', 'if signals pass', lx=606, ly=194)
    d.edge('cat', 'reb', 'active only', lx=606, ly=318)
    d.edge('reb', 'act', 'replaces the scope', lx=790, ly=150)
    d.text(30, 412, 'Scenario runs never rebuild activations. A failed signal job skips the rebuild entirely.', 'note')
    return d.render('Scenarios and signals are independent products. Only signals feed the activation table.',
                    legend('silver', 'gold', 'ops', 'source'))


def dia_scenario():
    d = Dia(1000, 270, 'Scenario package: SQL, table, catalog, and DDL')
    d.node('in', 30, 90, 200, 70, 'silver.* inputs', 'conformed FotMob tables', 'silver', '@@page:silver@@')
    d.node('sql', 300, 90, 220, 70, 'scenario_*.sql', 'deterministic pattern', 'ops', '@@page:scenarios@@')
    d.node('tbl', 600, 90, 260, 70, 'gold_scenarios.scenario_*', 'output at declared grain', 'gold', '@@page:scenarios@@')
    d.node('cat', 300, 200, 220, 56, 'Catalog entry', 'purpose · thresholds · assets', 'source', '@@page:scenarios@@')
    d.node('ddl', 600, 200, 260, 56, 'Table DDL', 'schema and ORDER BY', 'source', '@@page:scenarios@@')
    d.edge('in', 'sql')
    d.edge('sql', 'tbl')
    d.edge('sql', 'cat', style='dashed')
    d.edge('ddl', 'tbl', style='dashed')
    return d.render('One production unit: the SQL, its table, its catalog entry, and its DDL change together.',
                    legend('silver', 'ops', 'gold', 'source'))


def dia_signal_name():
    d = Dia(1000, 220, 'Signal name anatomy')
    parts = [
        ('sig', 'prefix', 40, 90, 'source'),
        ('team', 'entity', 150, 120, 'fotmob'),
        ('shooting', 'family', 290, 150, 'silver'),
        ('goals', 'subfamily', 460, 120, 'gold'),
        ('efficiency_peak', 'name', 600, 230, 'ops'),
    ]
    for word, label, x, w, kind in parts:
        d.node('p_' + word, x, 50, w, 60, word, label, kind)
    for sep_x in (134, 274, 444, 584):
        d.text(sep_x, 86, '_', 'head', 'middle')
    d.text(40, 150, 'sig_{entity}_{family}_{subfamily}_{name}', 'head')
    d.text(40, 180, 'Example: sig_team_shooting_goals_efficiency_peak. Family and subfamily come from the catalog frontmatter; '
           'the Gold runner selects jobs by filename.', 'note')
    return d.render('Each part of the name has one meaning. Entity, family, and subfamily are the taxonomy used for selection.',
                    legend('source', 'fotmob', 'silver', 'gold', 'ops'))


def dia_identity():
    d = Dia(1000, 260, 'Activation identity composition')
    d.node('v1', 20, 40, 100, 60, 'v1', 'scheme version', 'ops')
    d.node('sid', 140, 40, 140, 60, 'signal_id', 'sig_team_…', 'gold')
    d.node('mid', 300, 40, 120, 60, 'match_id', 'row_identity[0]', 'fotmob')
    d.node('side', 440, 40, 150, 60, 'triggered_side', 'row_identity[1]', 'fotmob')
    d.node('join', 640, 40, 170, 60, 'joined string', 'pipe-separated', 'source')
    d.node('sha', 850, 40, 130, 60, 'SHA-256', 'hex digest', 'ops')
    d.node('out', 640, 170, 340, 60, 'signal_instance_id', 'activation identity', 'gold')
    for k in ('v1', 'sid', 'mid', 'side'):
        d.edge(k, 'join')
    d.edge('join', 'sha')
    d.edge('sha', 'out')
    d.text(20, 150, 'Grain sets the row_identity list. Team grain: match_id, triggered_side.', 'note')
    d.text(20, 200, 'Player grain: match_id, triggered_player_id, triggered_team_id.', 'note')
    d.text(20, 240, 'The v1 prefix versions the scheme. It is not a signal definition version.', 'note')
    return d.render('The identity is a hash of the ordered row_identity values. Changing their order changes every ID.',
                    legend('ops', 'gold', 'fotmob', 'source'))


def dia_mongo():
    d = Dia(1000, 380, 'Catalog authority flow')
    d.region(20, 20, 960, 130, 'Git · authority')
    d.node('cat', 40, 60, 240, 70, 'Catalog markdown', 'frontmatter + body', 'source')
    d.node('sync', 360, 60, 240, 70, 'sync_signal_catalogs.py', 'validate · hash · upsert', 'ops', '@@cmd-catalogs@@')
    d.node('mongo', 660, 60, 300, 70, 'MongoDB signals', 'orbit_content · synced serving copy', 'serve', '@@page:mongodb@@')
    d.node('prod', 40, 270, 280, 70, 'Product / BI reads', 'catalog metadata', 'ops')
    d.node('act', 620, 270, 340, 70, 'gold.signal_activations', 'triggered rows · ClickHouse', 'gold', '@@gold-activation@@')
    d.edge('cat', 'sync', 'parse + check')
    d.edge('sync', 'mongo', 'upsert by SHA-256')
    d.edge('mongo', 'prod', 'signal metadata', style='accent', lx=400, ly=228)
    d.edge('act', 'prod', 'triggered rows', lx=470, ly=318)
    return d.render('Two owners, two stores: Git owns metadata, ClickHouse owns analytical rows. Consumers read both.',
                    legend('source', 'ops', 'serve', 'gold'))


def dia_commands():
    d = Dia(1080, 520, 'Command dependency map')
    d.region(10, 10, 1060, 190, 'FotMob')
    d.region(10, 210, 1060, 190, 'Oddspedia')
    d.region(10, 410, 1060, 100, 'Shared')
    W, H = 170, 50
    d.node('f_setup', 40, 40, W, H, 'setup FotMob', 'create tables (DDL)', 'ops', '@@cmd-fotmob-setup@@')
    d.node('f_scrape', 250, 40, W, H, 'scrape FotMob', 'writes Historical', 'fotmob', '@@cmd-fotmob-scrape@@')
    d.node('f_bronze', 460, 40, W, H, 'load Bronze', 'bronze.*', 'bronze', '@@cmd-fotmob-bronze@@')
    d.node('f_silver', 670, 40, W, H, 'load Silver', 'silver.* · 8', 'silver', '@@cmd-fotmob-silver@@')
    d.node('f_gold', 880, 40, W, H, 'load Gold', 'scenarios · signals', 'gold', '@@cmd-fotmob-gold@@')
    d.node('f_act', 880, 130, W, H, 'activations', 'after signals succeed', 'gold', '@@cmd-activations@@')
    d.node('o_setup', 40, 240, W, H, 'setup Oddspedia', 'create tables (DDL)', 'ops', '@@cmd-oddspedia-setup@@')
    d.node('o_disc', 250, 240, W, H, 'discover', 'event inventory', 'oddspedia', '@@cmd-oddspedia-discover@@')
    d.node('o_prio', 460, 240, W, H, 'prioritize', 'needs window flag', 'gate', '@@cmd-oddspedia-prioritize@@')
    d.node('o_scr', 670, 240, W, H, 'scrape Oddspedia', 'match artifacts', 'oddspedia', '@@cmd-oddspedia-scrape@@')
    d.node('o_bron', 880, 240, W, H, 'load Oddspedia', 'publish batch', 'bronze', '@@cmd-oddspedia-bronze@@')
    d.node('o_res', 880, 330, W, H, 'resolve', 'reads published only', 'silver', '@@cmd-oddspedia-resolve@@')
    d.node('s_health', 40, 440, W, H, 'health check', 'preflight', 'ops', '@@cmd-health@@')
    d.node('s_rep', 250, 440, W, H, 'report scraping', 'observational', 'ops', '@@cmd-report@@')
    d.node('s_sync', 460, 440, W, H, 'sync catalogs', 'dry-run first', 'serve', '@@cmd-catalogs@@')
    d.node('s_q', 670, 440, W, H, 'data quality', 'after Silver and Gold', 'gate', '@@cmd-quality@@')
    d.node('s_s3', 880, 440, W, H, 'S3 archive', 'optional, independent', 'planned', '@@cmd-s3@@')
    d.edge('f_scrape', 'f_bronze')
    d.edge('f_bronze', 'f_silver')
    d.edge('f_silver', 'f_gold')
    d.edge('f_gold', 'f_act')
    d.edge('o_disc', 'o_prio')
    d.edge('o_prio', 'o_scr')
    d.edge('o_scr', 'o_bron')
    d.edge('o_bron', 'o_res')
    d.text(40, 318, 'Without the readiness flag, prioritize and the intake pipeline refuse to run.', 'note')
    return d.render('Arrows show the data a command needs from the command before it. '
                    'Setup must run once before any load, but it has no data arrow.',
                    legend('ops', 'fotmob', 'oddspedia', 'bronze', 'silver', 'gold', 'gate', 'serve', 'planned'))


def dia_pipeline():
    d = Dia(1000, 340, 'FotMob pipeline stages and skip flags')
    stages = [
        ('p_scrape', 30, 'Scrape', 'scrape_fotmob.py', 'fotmob', '--skip-bronze', 'skips scraping'),
        ('p_bronze', 230, 'Bronze', 'load_fotmob_bronze.py', 'bronze', '--skip-clickhouse', 'no Bronze load'),
        ('p_silver', 430, 'Silver', 'load_fotmob_silver.py', 'silver', '--skip-silver', 'no Silver'),
        ('p_gold', 630, 'Gold', '4a scenarios · 4b signals', 'gold', '--skip-gold', 'no Gold or activations'),
    ]
    for key, x, title, sub_t, kind, flag, flag_note in stages:
        d.node(key, x, 120, 150, 70, title, sub_t, kind)
        d.flag(x + 75, 56, flag, 120)
        d.text(x + 84, 104, flag_note, 'note', 'start')
    d.node('p_act', 830, 120, 140, 70, 'Activations', '4c rebuild', 'gold')
    d.edge('p_scrape', 'p_bronze')
    d.edge('p_bronze', 'p_silver')
    d.edge('p_silver', 'p_gold')
    d.edge('p_gold', 'p_act')
    d.parts.append('<line x1="30" y1="222" x2="970" y2="222" class="bracket"/>')
    d.flag(500, 232, '--skip-fotmob', 240)
    d.text(640, 248, 'skips every FotMob stage', 'note', 'start')
    modes = [
        ('--bronze-only', 'stops after scrape'),
        ('--silver-only', 'Silver only · needs Bronze'),
        ('--gold-only', 'Gold only · needs Silver'),
        ('--full-history', 'Bronze → Gold · no scrape'),
    ]
    for i, (m, note) in enumerate(modes):
        d.node(f'm{i}', 30 + i * 240, 272, 220, 52, m, note, 'source')
    return d.render('Stages run left to right. Skip flags remove one stage; the stages after it keep their normal writes. '
                    'Mode flags select a window of stages.',
                    legend('fotmob', 'bronze', 'silver', 'gold', 'source'))


def dia_quality():
    d = Dia(1000, 470, 'Quality gate chain and exit codes')
    gates = [
        ('g_h', 30, 'Health check', 'reachability · storage · disk', 'ops'),
        ('g_b', 100, 'Bronze contract', 'assert_bronze_dataframe_contract', 'ops'),
        ('g_s', 170, 'Silver contract', 'assert_silver_layer_contracts', 'ops'),
        ('g_d', 240, 'Logical duplicates', 'FINAL · strict failure', 'danger'),
        ('g_p', 310, 'Physical row versions', 'diagnostic only', 'planned'),
        ('g_r', 380, 'Bronze ↔ Silver reconciliation', 'missing and unexpected identities', 'gate'),
    ]
    for key, y, t, s, k in gates:
        d.node(key, 40, y, 360, 54, t, s, k)
    for a, b in (('g_h', 'g_b'), ('g_b', 'g_s'), ('g_s', 'g_d'), ('g_d', 'g_p'), ('g_p', 'g_r')):
        d.edge(a, b)
    d.node('r_op', 640, 30, 320, 54, 'Exit 1 · operational', 'failure in any gate', 'danger')
    d.node('r_dup', 640, 240, 320, 54, 'Exit 1 · strict', 'logical duplicates found', 'danger')
    d.node('r_diag', 640, 310, 320, 54, 'Exit 0 · diagnostic', 'physical versions never fail', 'planned')
    d.node('r_rec', 640, 380, 320, 54, 'Exit 1 · strict', 'reconciliation mismatch', 'danger')
    d.edge('g_h', 'r_op', style='danger', lx=520, ly=40)
    d.edge('g_d', 'r_dup', style='danger')
    d.edge('g_p', 'r_diag', style='dashed')
    d.edge('g_r', 'r_rec', style='danger')
    return d.render('Gates run top to bottom. Only the danger gates can fail a strict run; the physical check is a diagnostic.',
                    legend('ops', 'danger', 'gate', 'planned'))


def dia_infra():
    d = Dia(1000, 400, 'Runtime topology')
    d.region(20, 20, 300, 360, 'Host')
    d.region(360, 20, 300, 360, 'Docker Compose')
    d.region(700, 20, 280, 360, 'External')
    d.node('data', 50, 60, 240, 70, 'data/ · logs/', 'artifacts · manifests · locks', 'artifact')
    d.node('env', 50, 170, 240, 70, '.env · credentials.json', 'local only · never committed', 'artifact')
    d.node('dlq', 50, 280, 240, 70, 'data/dlq/', 'failed Bronze inserts (JSONL)', 'artifact')
    d.node('ch', 400, 62, 220, 80, 'depthmark-clickhouse', ':8123 HTTP · :9000 native', 'bronze', '@@page:bronze@@')
    d.node('sc', 400, 172, 220, 80, 'depthmark-scraper', 'scrape · orchestrate · SQL', 'ops', '@@page:orchestration@@')
    d.node('mg', 400, 286, 220, 80, 'depthmark-mongodb', ':27017 · orbit_content', 'serve', '@@page:mongodb@@')
    d.node('s3', 730, 172, 220, 80, 'S3-compatible storage', 'optional · Historical archives', 'source', '@@page:bronze@@')
    d.edge('data', 'sc', 'reads and writes')
    d.edge('sc', 'ch', 'SQL + loads')
    d.edge('sc', 'mg', 'catalog sync')
    d.edge('sc', 's3', 'sync_s3.py only', style='dashed')
    return d.render('All state lives in three places: host files, ClickHouse, and MongoDB. S3 is an optional side channel.',
                    legend('artifact', 'bronze', 'ops', 'serve', 'source'))


def dia_bootstrap():
    d = Dia(1000, 170, 'Bootstrap sequence')
    steps = [
        ('b0', 'bootstrap.sh', '--local · --env-only', 'source'),
        ('b1', '.env', 'secrets · environment', 'artifact'),
        ('b2', 'compose up', 'three services', 'ops'),
        ('b3', 'health check', 'before any DDL', 'gate'),
        ('b4', 'source DDL', 'FotMob + Oddspedia', 'bronze'),
        ('b5', 'indexes + schedule', 'MongoDB · cron', 'serve'),
    ]
    for i, (k, t, s, kind) in enumerate(steps):
        d.node(k, 20 + i * 165, 40, 150, 84, t, s, kind)
    for i in range(5):
        d.edge(steps[i][0], steps[i + 1][0])
    d.text(20, 158, 'Pass --no-schedule to skip the schedule. Setup creates tables only and loads no data.', 'note')
    return d.render('Run once per host. Each step is safe to repeat; setup never drops a table.',
                    legend('source', 'artifact', 'ops', 'gate', 'bronze', 'serve'))


def dia_s3():
    d = Dia(1000, 280, 'Historical archive transfer')
    d.node('hist', 30, 90, 200, 80, 'Historical files', 'data/fotmob/historical/', 'artifact')
    d.node('gate', 290, 90, 220, 80, 'Completeness gate', 'listing proves every match', 'gate')
    d.node('tar', 570, 90, 190, 80, 'Archive', 'YYYYMM/YYYYMMDD.tar.gz', 'ops')
    d.node('s3', 800, 90, 170, 80, 'S3 object', 'bronze/fotmob/…', 'source')
    d.node('rest', 800, 210, 170, 60, 'Restore', 'staging · SHA-256 check', 'ops')
    d.node('live', 30, 210, 200, 60, 'Live files', 'never uploaded', 'muted')
    d.edge('hist', 'gate')
    d.edge('gate', 'tar')
    d.edge('tar', 's3', 'upload')
    d.edge('s3', 'rest', 'download', style='dashed')
    return d.render('Upload only moves Historical date archives. Live files are never uploaded; the scraper never touches S3.',
                    legend('artifact', 'gate', 'ops', 'source', 'planned'))


def dia_oddspedia():
    d = Dia(1000, 520, 'Oddspedia intake, publication, and resolution')
    d.node('brw', 30, 130, 160, 70, 'Browser evidence', 'events · detail pages', 'source')
    d.node('disc', 230, 130, 170, 70, 'discover', 'event inventory', 'oddspedia', '@@cmd-oddspedia-discover@@')
    d.node('gate', 430, 20, 220, 70, 'FotMob reference window', 'D−1 · D · D+1 Bronze and Silver', 'gate', '@@cmd-oddspedia-prioritize@@')
    d.node('prio', 430, 130, 200, 70, 'prioritize', 'readiness flag required', 'oddspedia', '@@cmd-oddspedia-prioritize@@')
    d.node('scr', 630, 130, 170, 70, 'scrape', 'match details', 'oddspedia', '@@cmd-oddspedia-scrape@@')
    d.node('art', 670, 20, 190, 70, 'Artifacts on disk', 'data/oddspedia/historical/', 'artifact')
    d.node('bro', 830, 130, 150, 70, 'oddspedia_bronze.*', 'staging → published', 'bronze', '@@cmd-oddspedia-bronze@@')
    d.node('fsil', 430, 290, 240, 70, 'FotMob silver.match', 'canonical fixtures · read only', 'fotmob', '@@page:silver@@')
    d.node('res', 830, 290, 150, 70, 'resolve', 'published batches only', 'silver', '@@cmd-oddspedia-resolve@@')
    d.node('edge', 760, 420, 220, 70, 'resolution edge', 'silver.oddspedia_match_resolution', 'silver', '@@oddspedia-resolution@@')
    d.node('plan', 30, 420, 260, 70, 'Oddspedia Gold', 'planned · own namespace', 'planned', '@@oddspedia-planned@@')
    d.edge('brw', 'disc')
    d.edge('disc', 'prio')
    d.edge('gate', 'prio', style='dashed')
    d.edge('prio', 'scr')
    d.edge('scr', 'art', 'writes')
    d.edge('art', 'bro', 'loader reads')
    d.edge('bro', 'res')
    d.edge('fsil', 'res', 'reads silver.match', style='accent')
    d.edge('res', 'edge')
    return d.render('Intake writes artifacts. Bronze publishes them only after validation. Resolution reads published batches, and '
                    'compares them with FotMob fixtures.',
                    legend('source', 'oddspedia', 'gate', 'artifact', 'bronze', 'fotmob', 'silver', 'planned'))


def dia_state(kind):
    d = Dia(760, 230, 'Publication state machine')
    if kind == 'load':
        d.node('st', 40, 80, 190, 70, 'staging', 'facts written, not readable', 'artifact')
        d.node('pub', 420, 40, 230, 70, 'published', 'readable by resolution', 'bronze')
        d.node('fail', 420, 140, 230, 70, 'failed', 'recorded when possible', 'danger')
        d.edge('st', 'pub', 'validated, all 3 tables replaced', style='accent', lx=330, ly=60)
        d.edge('st', 'fail', 'any failure', style='danger', lx=330, ly=170)
        d.text(40, 220, 'Resolution reads only the latest state = published. Rerunning the same date converges.', 'note')
        cap = 'Each Oddspedia date batch moves from staging to published, or to failed.'
        leg = legend('artifact', 'bronze', 'danger')
    else:
        d.node('st', 40, 90, 190, 70, 'committing', 'recorded before the first commit', 'artifact')
        d.node('pub', 420, 40, 230, 70, 'published', 'every target committed', 'silver')
        d.node('fail', 420, 150, 230, 70, 'failed', 'lists committed tables and error', 'danger')
        d.edge('st', 'pub', 'all targets committed', style='accent', lx=330, ly=60)
        d.edge('st', 'fail', 'a commit failed', style='danger', lx=330, ly=190)
        d.text(40, 225, 'A staging failure records nothing, because no target changed.', 'note')
        cap = 'Silver and Gold batches record a publication state so a mixed partition is visible.'
        leg = legend('artifact', 'silver', 'danger')
    return d.render(cap, leg)


def dia_mongo_collections():
    return None


# ---------------------------------------------------------------- components
def table(caption, heads, rows, rowattrs=None):
    th = ''.join(f'<th scope="col">{h}</th>' for h in heads)
    trs = []
    for i, r in enumerate(rows):
        attr = rowattrs[i] if rowattrs else ''
        cells = f'<th scope="row">{r[0]}</th>' + ''.join(f'<td>{c}</td>' for c in r[1:])
        trs.append(f'<tr{attr}>{cells}</tr>')
    return (f'<div class="table-wrap"><table><caption>{caption}</caption>'
            f'<thead><tr>{th}</tr></thead><tbody>{"".join(trs)}</tbody></table></div>')


def facts(rows):
    return '<dl class="facts">' + ''.join(f'<dt>{dt}</dt><dd>{dd}</dd>' for dt, dd in rows) + '</dl>'


def callout(kind, body):
    cls = 'callout' + (' ' + kind if kind else '')
    return f'<div class="{cls}">{body}</div>'


def stepper(items, cls=''):
    lis = []
    for title, body, color in items:
        style = f' style="--c:{color}"' if color else ''
        lis.append(f'<li{style}><strong>{title}</strong><span>{body}</span></li>')
    return f'<ol class="stepper {cls}">' + ''.join(lis) + '</ol>'


def cards(items, grid=True):
    out = []
    for title, body, ctx, href in items:
        inner = f'<h3>{title}</h3><p>{body}</p>'
        if href:
            out.append(f'<a class="card {ctx}" href="{href}">{inner}<span class="more">Open →</span></a>')
        else:
            out.append(f'<article class="card {ctx}">{inner}</article>')
    return '<div class="grid">' + ''.join(out) + '</div>'


def cmd(cid, title, source, pills_html, rows, code):
    reg(cid, title, 3)
    text = re.sub(r'<[^>]+>', ' ', title + ' ' + ' '.join(d + ' ' + v for d, v in rows))
    search = esc(' '.join(text.lower().split()))
    return (f'<details class="cmd" id="{cid}" data-source="{source}" data-search="{search}">'
            f'<summary><span class="cmd-title">{title}</span>{pills_html}</summary>'
            f'<div class="cmd-body">{facts(rows)}<pre><code>{esc(code)}</code></pre></div></details>')


def kpi(num, label, where, ctx, href=None):
    inner = f'<div class="num">{num}</div><div class="label">{label}</div><div class="where">{where}</div>'
    if href:
        return f'<a class="kpi {ctx}" href="{href}">{inner}</a>'
    return f'<div class="kpi {ctx}">{inner}</div>'


# ---------------------------------------------------------------- pages
def page_index():
    b = []
    b.append(sec('pipeline-map', 'Two source pipelines, one explicit seam',
                 'FotMob and Oddspedia each run their own Bronze → Silver → Gold path with their own raw contracts. '
                 'Click any box to open its reference.'))
    b.append(dia_index())
    b.append(sec('inventory', 'Inventory in this checkout', 'Counts of checked-in assets. Each tile links to its reference page.'))
    b.append('<div class="kpis">'
             + kpi(15, 'FotMob Bronze tables', 'bronze.*', 'ctx-bronze', '@@page:bronze@@')
             + kpi(8, 'FotMob Silver tables', 'silver.* incl. silver.match', 'ctx-silver', '@@page:silver@@')
             + kpi(48, 'Scenario SQL jobs', '23 team · 25 player', 'ctx-gold', '@@page:scenarios@@')
             + kpi(344, 'Signal SQL jobs', 'match 93 · player 129 · team 122', 'ctx-gold', '@@page:signals@@')
             + kpi(4, 'Oddspedia Bronze tables', 'oddspedia_bronze.*', 'ctx-bronze', '@@page:oddspedia@@')
             + kpi(1, 'Resolution table', 'silver.oddspedia_match_resolution', 'ctx-silver', '@@oddspedia-resolution@@')
             + kpi(26, 'Command entries', 'CLI and scripts', 'ctx-ops', '@@page:commands@@')
             + kpi(5, 'MongoDB collections', 'orbit_content', 'ctx-ops', '@@page:mongodb@@')
             + '</div>')
    b.append(sub('status', 'Implementation status'))
    b.append(table('Status by source and layer', ['Source', 'Bronze', 'Silver', 'Gold'], [
        ['<span class="pill fotmob">FotMob</span>', '<span class="pill implemented">Implemented</span>',
         '<span class="pill implemented">Implemented</span>', '<span class="pill implemented">Implemented</span>'],
        ['<span class="pill oddspedia">Oddspedia</span>', '<span class="pill implemented">Implemented</span>',
         '<span class="pill partial">Partial</span> resolution edge only', '<span class="pill planned">Planned</span>'],
    ]))
    b.append(sec('where', 'Where to find what', 'Each page covers one question. Start with the question you have.'))
    items = [
        ('Concepts &amp; glossary', 'Terms, ownership, and how the layers relate.', 'ctx-ops', '@@page:concepts@@'),
        ('FotMob', 'The FotMob route from API to products.', 'ctx-fotmob', '@@page:fotmob@@'),
        ('Oddspedia', 'Intake, publication, and the resolution edge.', 'ctx-oddspedia', '@@page:oddspedia@@'),
        ('Bronze', 'Source-fidelity tables, storage, and archives.', 'ctx-bronze', '@@page:bronze@@'),
        ('Silver', 'Conformed tables, lineage, and publication state.', 'ctx-silver', '@@page:silver@@'),
        ('Gold', 'Namespaces, dependencies, and activations.', 'ctx-gold', '@@page:gold@@'),
        ('Scenarios', 'Narrative products and their package.', 'ctx-gold', '@@page:scenarios@@'),
        ('Signals', 'Naming, taxonomy, and activation identity.', 'ctx-gold', '@@page:signals@@'),
        ('MongoDB catalogs', 'Who owns catalog metadata and how it syncs.', 'ctx-ops', '@@page:mongodb@@'),
        ('Commands', 'Scope, preview, and effect for every command.', 'ctx-ops', '@@page:commands@@'),
        ('Orchestration', 'Pipeline stages, skip flags, and recovery.', 'ctx-ops', '@@page:orchestration@@'),
        ('Quality', 'Gates, exit codes, and acceptance.', 'ctx-ops', '@@page:quality@@'),
        ('Infrastructure', 'Topology, bootstrap, credentials, and S3.', 'ctx-ops', '@@page:infrastructure@@'),
        ('Contracts &amp; decisions', 'Authority per question and the ADR index.', 'ctx-ops', '@@page:contracts@@'),
    ]
    b.append(cards(items))
    b.append(callout('', '<p><strong>Ownership rule.</strong> SQL holds analytical logic. Python discovers, executes, validates, '
                         'and reports. Every derived stage stages and validates its scope before committing, so a rerun of the '
                         'same scope converges.</p>'))
    return ''.join(b)


def page_concepts():
    b = []
    b.append(sec('matrix', 'Ownership matrix',
                 'Read down a column to follow one source through the layers. Read across to see what is shared.'))
    b.append(dia_matrix())
    b.append(sec('scope', 'Output scope', 'Every derived run declares the scope it may replace. Nothing outside it changes.'))
    b.append(dia_scope())
    b.append(sec('glossary', 'Glossary', 'Each term links to the page or decision that governs it.'))
    rows = [
        ['Source domain', 'FotMob and Oddspedia each own their artifacts, raw contracts, conformed entities, and products. '
         'No shared provider framework.', 'ADR 0021, 0023'],
        ['Medallion layer', 'Bronze preserves, Silver conforms, Gold materializes. Each source has all three, even where a '
         'layer is still planned.', '<a href="@@page:bronze@@">Bronze</a> · <a href="@@page:silver@@">Silver</a> · <a href="@@page:gold@@">Gold</a>'],
        ['Historical and Live', 'Historical holds completed dates and is the only input to Bronze loading and S3 archive '
         'transfer. Live is a refreshable snapshot of the current date. Future dates are rejected.', '<a href="@@page:fotmob@@">FotMob</a> · ADR 0017'],
        ['Canonical fixture', '<code>silver.match</code> is the FotMob fixture reference.', '<a href="@@page:silver@@">Silver</a>'],
        ['Resolution edge', '<code>silver.oddspedia_match_resolution</code> records at most one FotMob fixture per Oddspedia '
         'event, with audit evidence. It never rewrites FotMob records.', '<a href="@@oddspedia-resolution@@">Resolution</a> · ADR 0022'],
        ['Output scope', 'The date, month, or full history a run replaces. SQL may read wider history without widening the scope.',
         'ADR 0018'],
        ['Staging and commit', 'Every target is staged and validated before any commit. A staging failure changes nothing. '
         'A failed commit can leave a partial batch; rerunning the same scope converges.',
         '<a href="@@page:orchestration@@">Orchestration</a> · ADR 0028'],
        ['Grain and row identity', 'Grain is what one row represents. Ordered <code>row_identity</code> fields identify an activation.',
         '<a href="@@page:signals@@">Signals</a>'],
        ['Logical duplicate vs physical version', 'A logical duplicate breaks business identity and fails strict checks. '
         'A physical version is an unmerged storage row, a diagnostic only.', '<a href="@@page:quality@@">Quality</a> · ADR 0019'],
        ['Published batch', 'An Oddspedia date batch in state <code>published</code>. Resolution reads only published batches.',
         '<a href="@@oddspedia-publication@@">Publication state</a> · ADR 0028'],
        ['Date lock and dry run', 'Mutating Oddspedia commands serialize per sport and date. Dry runs take no lock and change nothing.',
         '<a href="@@page:commands@@">Commands</a>'],
        ['Scenario', 'A narrative analytical pattern in <code>gold_scenarios.scenario_*</code>.', '<a href="@@page:scenarios@@">Scenarios</a>'],
        ['Signal', 'A granular detection in <code>gold_signals.sig_*</code>.', '<a href="@@page:signals@@">Signals</a>'],
        ['Activation', 'A triggered signal row, enriched with identity, catalog metadata, and fixture context, in '
         '<code>gold.signal_activations</code>.', '<a href="@@gold-activation@@">Activation rebuild</a> · ADR 0014'],
        ['Catalog', 'Git markdown frontmatter is the authority for signal metadata. MongoDB holds a synchronized copy.',
         '<a href="@@page:mongodb@@">MongoDB catalogs</a> · ADR 0008'],
        ['DLQ and archive', 'Failed FotMob Bronze inserts keep diagnostic payloads in <code>data/dlq/</code> for replay. '
         'The S3 archive is optional and independent. Neither is a data layer.', 'ADR 0012'],
    ]
    b.append(table('Core terms', ['Term', 'Meaning', 'Read more'], rows))
    b.append(sec('axes', 'Four axes to keep apart',
                 'A source, a layer, a platform, and a product answer different questions. Do not treat them as one thing.'))
    b.append(cards([
        ('Source domain', 'Who owns the raw contract? FotMob or Oddspedia. Raw contracts never merge.', 'ctx-fotmob', None),
        ('Warehouse layer', 'What transformation applies? Bronze preserves, Silver conforms, Gold materializes.', 'ctx-bronze', None),
        ('Runtime platform', 'Where state lives or computation runs. Platforms never redefine ownership.', 'ctx-ops', '@@page:infrastructure@@'),
        ('Product surface', 'What consumers query. Gold tables and MongoDB catalogs are downstream of warehouse truth.', 'ctx-gold', '@@page:mongodb@@'),
    ]))
    b.append(sec('platforms', 'Platforms and what each owns'))
    b.append(table('Runtime platforms', ['Platform', 'Owns', 'Does not own'], [
        ['Filesystem', 'Source artifacts in <code>data/fotmob/</code> and <code>data/oddspedia/</code>, manifests, locks, DLQ files, run logs',
         'Silver or Gold tables'],
        ['Python runtime', 'Scraping, orchestration, contract validation, SQL execution, reporting', 'Business logic, which lives in SQL'],
        ['ClickHouse', 'Structured Bronze facts, all Silver and Gold tables', 'Raw artifact authority, catalog authoring'],
        ['MongoDB', 'Synchronized catalog serving state in <code>orbit_content</code>', 'Analytical transformations'],
        ['S3 (optional)', 'FotMob Historical archives, moved by an operator', 'Pipeline success, Live storage, Oddspedia data'],
    ]))
    return ''.join(b)


def page_fotmob():
    b = []
    b.append(sec('fotmob-route', 'Route', 'FotMob owns its source artifacts, conformed fixtures, scenarios, signals, and activations. '
                 'Oddspedia reads <code>silver.match</code> through the resolution edge and never changes it.'))
    b.append(stepper([
        ('FotMob API', 'One request per match, sequential', 'var(--fotmob)'),
        ('<a href="@@page:bronze@@">Bronze</a>', 'Historical files and <code>bronze.*</code>', 'var(--bronze)'),
        ('<a href="@@page:silver@@">Silver</a>', '8 conformed tables', 'var(--silver)'),
        ('<a href="@@page:gold@@">Gold</a>', 'Scenarios, signals, activations', 'var(--gold)'),
    ]))
    b.append(sec('fotmob-facts', 'At a glance'))
    b.append(facts([
        ('Input', 'FotMob API payloads, stored as completed-date Historical files'),
        ('Output', '<code>bronze.*</code> → <code>silver.*</code> → <code>gold_scenarios.*</code>, <code>gold_signals.*</code>, '
                   '<code>gold.signal_activations</code>'),
        ('Boundary', 'Warehouse loading reads Historical only. Live refresh and S3 transfer are separate.'),
    ]))
    b.append(sec('fotmob-interfaces', 'Interfaces', 'Each boundary has one canonical script. The command cards give the options.'))
    b.append(table('Canonical script per boundary', ['Boundary', 'Script', 'Reference'], [
        ['Source artifacts', '<code>data/fotmob/{historical,live}/</code>', '<a href="@@page:bronze@@">Bronze</a>'],
        ['Bronze facts', '<code>scripts/bronze/load_fotmob_bronze.py</code>', '<a href="@@cmd-fotmob-bronze@@">Command</a>'],
        ['Silver entities', '<code>scripts/silver/load_fotmob_silver.py</code>', '<a href="@@cmd-fotmob-silver@@">Command</a>'],
        ['Gold products', '<code>scripts/gold/load_fotmob_gold.py</code>', '<a href="@@cmd-fotmob-gold@@">Command</a>'],
        ['Pipeline', '<code>scripts/orchestration/run_fotmob_pipeline.py</code>', '<a href="@@page:orchestration@@">Orchestration</a>'],
    ]))
    b.append(sec('fotmob-daily', 'Daily workflow'))
    b.append(stepper([
        ('Prepare', 'Configure the runtime, create tables once, confirm service health.', None),
        ('Collect', 'Scrape completed dates into Historical. Use <code>--today</code> only for Live.', None),
        ('Preview', 'Dry-run the Bronze, Silver, and Gold loaders for the target date.', None),
        ('Run', 'Run the pipeline, or the layers in dependency order.', None),
        ('Verify', 'Inspect the scraping report, then run scoped strict checks.', None),
        ('Publish', 'Sync changed signal catalogs. Archive transfer is a separate task.', None),
    ]))
    b.append(callout('', '<p><strong>Scraping constraints.</strong> One match is fetched at a time to protect API reliability. '
                         'When the API blocks requests, <code>scripts/refresh_turnstile.py</code> refreshes the local challenge cookie. '
                         'Historical matches are stored compressed (<code>match_*.json.gz</code>). The scraper never touches S3.</p>'))
    return ''.join(b)


def page_oddspedia():
    b = []
    b.append(sec('oddspedia-flow', 'Intake to resolution',
                 'Intake, Bronze publication, and Silver resolution are three separate operations. Bronze and resolution are implemented. '
                 'Gold is planned and must not reuse FotMob Gold commands.'))
    b.append(dia_oddspedia())
    b.append(sub('oddspedia-stages', 'Stages and status'))
    b.append(table('Oddspedia stages', ['Stage', 'Command', 'Output', 'Status'], [
        ['1a · Discover events', '<code>discover_oddspedia_events.py</code>', 'Event inventory in <code>data/oddspedia/historical/</code>',
         '<span class="pill implemented">Implemented</span>'],
        ['1b · Prioritize', '<code>prioritize_oddspedia_events.py</code>', 'Priority decisions and manifests',
         '<span class="pill implemented">Implemented</span>'],
        ['1c · Scrape details', '<code>scrape_oddspedia_matches.py</code>', 'Match payloads and completeness evidence',
         '<span class="pill implemented">Implemented</span>'],
        ['2 · Bronze publication', '<code>load_oddspedia_bronze.py</code>', '<code>oddspedia_bronze.*</code>, staging → published',
         '<span class="pill implemented">Implemented</span>'],
        ['3 · Silver resolution', '<code>resolve_oddspedia_events.py</code>', '<code>silver.oddspedia_match_resolution</code>',
         '<span class="pill implemented">Implemented</span>'],
        ['4 · Source analytics', 'None yet', 'Further Silver entities, then Gold odds products', '<span class="pill planned">Planned</span>'],
    ]))
    b.append(sec('oddspedia-gates', 'Fail-closed rules',
                 'Admission is strict on purpose. A date that cannot be verified does not reach Silver.'))
    b.append(callout('warn', '<p><strong>Discovery</strong> accepts complete pagination or a verified empty date, with checksums.</p>'
                     '<p><strong>Reference window.</strong> Prioritization and the intake pipeline require <code>--silver-reference-window-ready</code>. '
                     'It verifies the FotMob window and never creates missing fixtures.</p>'
                     '<p><strong>Publication.</strong> Bronze sets <code>published</code> only after all three fact tables replace.</p>'
                     '<p><strong>Resolution</strong> reads only published batches. Month and range commands exit non-zero if any date fails.</p>'))
    b.append(sec('oddspedia-publication', 'Publication state',
                 'Downstream code can trust a date only when its batch is published. Failed batches are visible, not silently skipped.'))
    b.append(dia_state('load'))
    b.append(sec('oddspedia-artifacts', 'Persisted artifacts',
                 'The JSON schemas describe the existing shape. Scraped files gain no envelope field, and adopting a contract never rewrites them.'))
    b.append(table('Artifacts and their schemas (<code>schemas/oddspedia/</code>)', ['Artifact', 'Schema', 'Compatibility'], [
        ['<code>match_links.json</code>', '<code>match_links.schema.json</code>', 'Event links. An accepted empty inventory stays <code>[]</code>.'],
        ['<code>matches/…/&lt;event_id&gt;.json</code>', '<code>match_payload.schema.json</code>',
         'Score, odds-line, coverage, statistics. Extra compatible fields are kept.'],
        ['<code>manifest.json</code>', '<code>scrape_manifest.schema.json</code>', 'Known states validated. Unknown compatible fields round-trip.'],
    ]))
    b.append(sec('oddspedia-resolution', 'Resolution edge',
                 '<code>silver.oddspedia_match_resolution</code> links one event to at most one FotMob fixture, with audit evidence. '
                 'It is the only cross-source table in the warehouse.'))
    b.append(table('Resolution outcomes', ['Outcome', 'Meaning'], [
        ['Matched', 'One FotMob fixture is linked.'],
        ['Ambiguous', 'More than one candidate; nothing is linked.'],
        ['Unmatched', 'The window is verified and no candidate exists.'],
        ['Not covered', 'Recorded only with the readiness flag; the window is verified and the fixture is missing.'],
        ['Unresolved', 'Without the readiness flag, a no-candidate event stays unresolved.'],
    ]))
    b.append(sec('oddspedia-planned', 'Planned Gold',
                 'Oddspedia Gold has no execution surface yet. A new Oddspedia product needs explicit source ownership in its tables, SQL, catalogs, and commands.'))
    b.append(callout('', '<p>Until then, <code>load_fotmob_gold.py</code> must not be used as an Oddspedia substitute.</p>'))
    return ''.join(b)


def page_bronze():
    b = []
    b.append(sec('bronze-sources', 'By source',
                 'The only filesystem-backed layer. FotMob and Oddspedia keep separate raw contracts, paths, and ClickHouse databases.'))
    b.append(table('Bronze by source', ['Source', 'Filesystem', 'ClickHouse', 'Admission'], [
        ['<span class="pill fotmob">FotMob</span>', '<code>data/fotmob/{historical,live}/</code>', '15 tables, <code>bronze.*</code>',
         'Pydantic extraction, dataframe contracts, DLQ, <code>ReplacingMergeTree(inserted_at)</code>'],
        ['<span class="pill oddspedia">Oddspedia</span>', '<code>data/oddspedia/{historical,live}/</code>', '4 tables, <code>oddspedia_bronze.*</code>',
         'JSON schemas, atomic writes, checksummed manifests, staged publication'],
    ]))
    b.append(sec('bronze-load', 'FotMob loading route'))
    b.append(stepper([
        ('Raw JSON', '<code>historical/matches/YYYYMM/YYYYMMDD/</code>, one file per match', 'var(--bronze)'),
        ('Extract', 'Pydantic and <code>SafeFieldExtractor</code> build 14 entity DataFrames', 'var(--bronze)'),
        ('Assert', '<code>assert_bronze_dataframe_contract()</code> runs before any write', 'var(--gate, var(--partial))'),
        ('Upsert', '15 <code>bronze.*</code> tables. Failed inserts go to <code>data/dlq/</code>.', 'var(--bronze)'),
    ]))
    b.append(sec('bronze-tables', 'FotMob Bronze tables',
                 'Logical row identity is the sort key from the DDL. Physical versions can coexist until maintenance runs.'))
    tbl = [
        ['<code>general</code>', '<code>match_id</code>', 'Match metadata, league, season'],
        ['<code>timeline</code>', '<code>match_id</code>', 'Event timeline'],
        ['<code>venue</code>', '<code>match_id</code>', 'Stadium'],
        ['<code>player</code>', '<code>match_id, player_id</code>', 'Player profiles'],
        ['<code>shotmap</code>', '<code>match_id, shot_id</code>', 'Shot locations and xG'],
        ['<code>goal</code>', '<code>match_id, event_id</code>', 'Goal events'],
        ['<code>cards</code>', '<code>match_id, event_id</code>', 'Yellow and red cards'],
        ['<code>red_card</code>', '<code>match_id, event_id</code>', 'Red card details'],
        ['<code>period</code>', '<code>match_id, period</code>', 'Period statistics'],
        ['<code>momentum</code>', '<code>match_id, minute</code>', 'Momentum per minute'],
        ['<code>starters</code>', '<code>match_id, player_id</code>', 'Starting lineups'],
        ['<code>substitutes</code>', '<code>match_id, player_id</code>', 'Substitutions'],
        ['<code>coaches</code>', '<code>match_id, coach_id</code>', 'Managers'],
        ['<code>team_form</code>', '<code>match_id, team_id, form_position</code>', 'Form streaks'],
        ['<code>match_reference</code>', '<code>match_id</code>', 'Lookup and join helper'],
    ]
    b.append(table('15 FotMob Bronze tables', ['Table', 'Row identity', 'Content'], tbl))
    b.append(sec('bronze-storage', 'Storage layout',
                 'Artifacts are partitioned by source, then Historical or Live, then artifact type, month, and date.'))
    b.append('<pre><code>data/fotmob/\n├─ historical/  daily_listings/YYYYMM/YYYYMMDD/  matches/YYYYMM/YYYYMMDD/\n'
             '└─ live/        daily_listings/YYYYMM/YYYYMMDD/  matches/YYYYMM/YYYYMMDD/\n\n'
             'data/oddspedia/\n├─ historical/  daily_listings/  link_priorities/  matches/  manifests/   (YYYYMM/YYYYMMDD)\n'
             '├─ live/        daily_listings/  matches/  manifests/\n└─ locks/       operational state, excluded from publication\n\n'
             'data/dlq/       FotMob Bronze failed inserts (JSONL)</code></pre>')
    b.append(callout('', '<p>Re-running a date converges because the version column (<code>inserted_at</code>) decides the winner. '
                         'Setup runs no full-table compaction. Exact filenames and archive members are in '
                         '<a href="https://github.com/SoroushGhaderi/DepthMark/blob/main/docs/data-flow/source-artifact-storage.md" '
                         'target="_blank" rel="noopener">source-artifact-storage.md</a>.</p>'))
    b.append(sec('bronze-s3', 'Historical archive transfer',
                 'An explicit operator workflow, isolated from scraping and from pipeline success.'))
    b.append(dia_s3())
    b.append(facts([
        ('Object', '<code>bronze/fotmob/YYYYMM/YYYYMMDD.tar.gz</code>. A transfer never changes local compression or deletes artifacts.'),
        ('Completeness', 'Upload needs a listing that proves every expected match is stored or unavailable. '
                         '<code>--allow-incomplete</code> is an explicit override.'),
        ('Overwrite', 'Kept unless <code>--force</code> is passed.'),
        ('Download', 'Checks SHA-256 metadata, rejects unsafe paths, restores through staging.'),
        ('Batches', 'Independent dates continue after a failure. Any failure exits non-zero.'),
    ]))
    return ''.join(b)


def page_silver():
    b = []
    b.append(sec('silver-lineage', 'Lineage: Bronze → Silver',
                 'Silver standardizes keys, types, and entities within each source. Eleven of the fifteen Bronze tables feed it directly.'))
    b.append(dia_lineage())
    b.append(sec('silver-run', 'Scoped replacement',
                 'Silver reads all Bronze history as analytical context, but replaces only the selected scope.'))
    b.append(stepper([
        ('Run DML', 'Scripts run in numeric order, <code>01</code> to <code>08</code>.', 'var(--silver)'),
        ('Stage', 'ClickHouse calculates and validates each output in staging.', 'var(--silver)'),
        ('Replace', '<code>REPLACE PARTITION</code> for a date or month. <code>EXCHANGE TABLES</code> for full history.', 'var(--silver)'),
        ('Check', 'Post-load contract checks and the summary report.', 'var(--silver)'),
    ]))
    b.append(callout('', '<p>A date run keeps the other dates in its month. <code>goal</code>, <code>red_card</code>, <code>starters</code>, '
                         'and <code>match_reference</code> have no current Silver input; a future use needs an explicit layer contract.</p>'))
    b.append(sec('silver-publication', 'Publication state',
                 '<code>silver.scope_publication</code> records each scoped batch, so a partition that committed only in part is visible (ADR 0028).'))
    b.append(dia_state('scope'))
    return ''.join(b)


def page_gold():
    b = []
    b.append(sec('gold-namespaces', 'Three namespaces',
                 'FotMob Gold is implemented in three ClickHouse namespaces. Each namespace has its own ownership boundary.'))
    b.append(cards([
        ('gold_scenarios.*', '48 scenario tables. Narrative patterns that evolve as products.', 'ctx-gold', '@@page:scenarios@@'),
        ('gold_signals.*', '344 signal tables. Granular detections on an analytical cadence.', 'ctx-gold', '@@page:signals@@'),
        ('gold.*', '<code>signal_activations</code>, the unified serving table, and <code>scope_publication</code>.', 'ctx-gold',
         '@@gold-activation@@'),
    ]))
    b.append(sec('gold-dependency', 'How Gold is built',
                 'Scenarios and signals read Silver. Only signal outputs feed the activation table.'))
    b.append(dia_gold())
    b.append(sec('gold-jobs', 'Job execution',
                 'The bulk loader and the selected-job runner share SQL discovery and staged replacement.'))
    b.append(stepper([
        ('Bulk or selected', '<code>load_fotmob_gold.py</code> for a scope, or <code>run_gold_sql_jobs.py</code> for chosen jobs.', 'var(--gold)'),
        ('Stage', 'All selected jobs are staged and validated.', 'var(--gold)'),
        ('Commit', 'Per table. The bulk loader then rebuilds activations after successful signals.', 'var(--gold)'),
    ]))
    b.append(sec('gold-activation', 'Activation rebuild',
                 '<code>gold.signal_activations</code> is rebuilt for the requested scope. Only full history replaces the whole table.'))
    b.append(stepper([
        ('Scan catalogs', 'Active signals from <code>scripts/gold/signal/catalogs/*.md</code>.', 'var(--gold)'),
        ('Read identity', 'The <code>row_identity</code> fields for each signal.', 'var(--gold)'),
        ('Stage', 'Activations for the selected history, built in a staging table.', 'var(--gold)'),
        ('Replace', 'The scope of <code>gold.signal_activations</code> is replaced. Skipped if any signal job failed.', 'var(--gold)'),
    ]))
    b.append(callout('', '<p><strong>Identity version.</strong> The <code>v1</code> prefix versions the hash scheme, not a signal definition '
                         '(ADR 0006). Identity details are on <a href="@@signals-identity@@">Signals</a>.</p>'))
    return ''.join(b)


def page_scenarios():
    b = []
    b.append(sec('scenarios-package', 'One production unit',
                 'Narrative patterns at team/match or player grain. Scenario runs never rebuild signals or activations.'))
    b.append(dia_scenario())
    b.append(sec('scenarios-run', 'Execution and inventory'))
    b.append('<div class="kpis">' + kpi(48, 'Scenario SQL jobs', 'all scenarios', 'ctx-gold')
             + kpi(23, 'Team / match', 'grain: team and match', 'ctx-gold')
             + kpi(25, 'Player', 'grain: player', 'ctx-gold') + '</div>')
    b.append(stepper([
        ('Date or month', 'Stages and validates the selected scope before replacing it.', 'var(--gold)'),
        ('Full history', 'Requires an explicit scope and whole-table exchange.', 'var(--gold)'),
        ('Bulk', 'Enabled with <code>--part scenarios</code> or <code>--part all</code>, superseding ADR 0004.', 'var(--gold)'),
    ]))
    b.append(sub('scenarios-contract', 'Contract'))
    b.append(callout('', '<p>The contract is in <a href="https://github.com/SoroushGhaderi/DepthMark/blob/main/scripts/gold/scenario/SCENARIOS_CONTRACT.md" '
                         'target="_blank" rel="noopener">SCENARIOS_CONTRACT.md</a>. Scenario rows must produce a valid <code>match_id</code>.</p>'))
    return ''.join(b)


def page_signals():
    b = []
    b.append(sec('signals-name', 'Naming',
                 'Each signal package ties together its SQL, its <code>gold_signals.*</code> table, its catalog, and its index entry.'))
    b.append(dia_signal_name())
    b.append(sec('signals-taxonomy', 'Taxonomy in this checkout', '344 signal SQL files. The Gold runner selects by filename.'))
    b.append(table('Family and subfamily', ['Family', 'Subfamily', 'Signals'], [
        ['shooting', 'goals', '96'], ['possession', 'passing', '79'], ['goalkeeping', 'defense', '63'],
        ['discipline', 'cards', '60'], ['creativity', 'playmaking', '46'],
    ]))
    b.append('<p class="small muted">Entities: <code>match</code> (93), <code>player</code> (129), <code>team</code> (122).</p>')
    b.append(sec('signals-frontmatter', 'Required catalog frontmatter',
                 'The MongoDB sync rejects any catalog missing one of these keys.'))
    b.append(table('Required keys', ['Key', 'Rule'], [
        ['<code>signal_id</code>', 'Must match the SQL filename and table name exactly'],
        ['<code>status</code>', 'Only <code>active</code> signals enter activations'],
        ['<code>entity</code>, <code>family</code>, <code>subfamily</code>', 'Taxonomy for discovery and filtering'],
        ['<code>grain</code>', '<code>match_team</code> or <code>match_player</code>. Sets the hash columns.'],
        ['<code>row_identity</code>', 'List of strings. Order is part of the hash input.'],
        ['<code>asset_paths</code>', 'Paths to SQL, DDL, and table. Must use <code>gold_signals.*</code>.'],
    ]))
    b.append(sec('signals-identity', 'Activation identity',
                 'Identifiers are deterministic and stay stable across full rebuilds. The order of <code>row_identity</code> is part of the input.'))
    b.append(dia_identity())
    b.append('<pre><code>team grain:   v1|sig_team_...|match_id|triggered_side\n'
             'player grain: v1|sig_player_...|match_id|triggered_player_id|triggered_team_id</code></pre>')
    return ''.join(b)


def page_mongodb():
    b = []
    b.append(sec('mongodb-flow', 'Authority flow',
                 'MongoDB serves synchronized catalog metadata. ClickHouse keeps the triggered analytical rows. Keep the two apart.'))
    b.append(dia_mongo())
    b.append(sec('mongodb-collections', 'Collections',
                 'The sync writes only <code>signals</code>. The other collections are created and indexed by the bootstrap.'))
    b.append(table('orbit_content collections', ['Collection', 'Unique key', 'Purpose'], [
        ['<code>signals</code>', '<code>signal_id</code>', 'Signal metadata, SQL hashes, taxonomy. Synced from Git.'],
        ['<code>scenarios</code>', '<code>scenario_id</code>', 'Scenario metadata'],
        ['<code>channel_templates</code>', 'template ID', 'Delivery templates per channel'],
        ['<code>content_versions</code>', 'none', 'Audit trail of catalog versions'],
        ['<code>scenario_signal_map</code>', 'none', 'Scenario-to-signal relationships'],
    ]))
    b.append(sec('mongodb-sync', 'Sync route'))
    b.append(stepper([
        ('Read', 'Frontmatter and body of each catalog file.', 'var(--accent)'),
        ('Validate', 'Required keys present, and assets use <code>gold_signals.*</code>.', 'var(--accent)'),
        ('Upsert', 'Into <code>signals</code>. A SHA-256 content hash makes reruns idempotent.', 'var(--accent)'),
    ]))
    b.append(callout('ok', '<p><strong>Preview first.</strong> Run <code>sync_signal_catalogs.py --dry-run</code>. It validates and writes nothing.</p>'))
    b.append(callout('warn', '<p><strong>Two owners.</strong> Read catalog metadata from MongoDB. Read triggered analytical rows from '
                             '<code>gold.signal_activations</code>. A catalog description and a triggered row are different kinds of state.</p>'))
    return ''.join(b)


CMD_FILTER = ('<div class="toolbar">'
              '<input class="input" type="search" placeholder="Filter commands by name or option" aria-label="Filter commands" '
              'data-filter-input data-scope="#commands-cards">'
              '<div class="group" data-filter-group data-scope="#commands-cards" role="group" aria-label="Filter by source">'
              '<button class="chip" type="button" data-value="all" aria-pressed="true">All</button>'
              '<button class="chip" type="button" data-value="fotmob" aria-pressed="false">FotMob</button>'
              '<button class="chip" type="button" data-value="oddspedia" aria-pressed="false">Oddspedia</button>'
              '<button class="chip" type="button" data-value="shared" aria-pressed="false">Shared</button>'
              '</div>'
              '<div class="group"><span class="count" data-count-for="#commands-cards" data-count-label="commands"></span>'
              '<button class="btn" type="button" data-expand="open" data-scope="#commands-cards">Expand all</button>'
              '<button class="btn" type="button" data-expand="close" data-scope="#commands-cards">Collapse all</button>'
              '</div></div>')


def pill_src(src):
    return {'fotmob': pill('FotMob', 'fotmob'), 'oddspedia': pill('Oddspedia', 'oddspedia'), 'shared': pill('Shared', 'shared')}[src]


def page_commands():
    b = []
    b.append(sec('commands-graph', 'Dependency map',
                 'Arrows show which command needs data from the one before it. Click a box to open its card.'))
    b.append(dia_commands())
    b.append(sec('commands-scope', 'Scope compatibility',
                 'Each command family accepts its own selectors. Keep one scope selector per command.'))
    b.append(table('Selectors per command family', ['Family', 'Date', 'Month', 'Range', 'Full history', 'Preview'], [
        ['FotMob scrape', 'Positional, <code>--single-date</code>', '<code>--month</code>', 'Two positional dates, or <code>--days</code>', '—', '—'],
        ['FotMob Bronze', '<code>--date</code>', '<code>--month</code>', '<code>--start-date</code> + <code>--end-date</code>', '<code>--full-history</code>', '<code>--dry-run</code>'],
        ['FotMob pipeline', 'Positional, <code>--date</code>', '<code>--month</code>', 'Start and end date', '<code>--full-history</code> (no scrape)', '—'],
        ['FotMob Silver, Gold, SQL', '<code>--date</code>', '<code>--month</code>', '—', '<code>--full-history</code>', '<code>--dry-run</code>'],
        ['Oddspedia intake', '<code>--date</code>, default today', '<code>--month</code>', 'Start and end date', '—', 'Prioritize only'],
        ['Oddspedia Bronze, resolver', '<code>--date</code>', '<code>--month</code>', 'Start and end date', '—', '<code>--dry-run</code>'],
        ['Scraping report', '<code>--date</code>, default today', '<code>--month</code>', 'Start and end date', '—', 'Observational'],
        ['FotMob S3', '<code>--date</code>', '<code>--month</code>', 'Start and end date', '<code>--all</code>', '<code>--dry-run</code>'],
        ['FotMob quality', '<code>--date</code>', '<code>--month</code>', '—', 'Default', 'Observational'],
    ]))
    b.append(sec('commands-list', 'Command cards',
                 'Filter by name or source, then expand a card. Every card has a link that can be shared, such as '
                 '<code>#cmd-fotmob-bronze</code>.'))
    b.append(CMD_FILTER)
    cards_html = []
    specs = [
        ('cmd-health', 'Health check', 'shared', pill('Shared', 'shared') + pill('Observational', 'neutral'),
         [('Interface', '<code>depthmark health-check</code> · <code>scripts/health_check.py</code>'),
          ('Scope', 'No date. Optional <code>--storage</code> paths and ClickHouse overrides.'),
          ('Preview', 'Not applicable, read-only.'),
          ('Effect', 'Checks service reachability and free disk. Not a data-quality gate.')],
         'depthmark health-check --storage-only --storage data data/fotmob'),
        ('cmd-report', 'Scraping reports', 'shared', pill('Shared', 'shared') + pill('Observational', 'neutral'),
         [('Interface', '<code>depthmark report-scraping</code> · <code>scripts/report_scraping.py</code>'),
          ('Scope', '<code>--date</code>, <code>--month</code>, or a range. Default today.'),
          ('Options', '<code>--source all|fotmob|oddspedia</code>, <code>--format summary|markdown|json</code>, <code>--output</code>, '
                      '<code>--fail-on-attention</code>'),
          ('Effect', 'Reads evidence only. Writes a file only with <code>--output</code>. <code>--fail-on-attention</code> exits 1 for attention states.')],
         'depthmark report-scraping --source all --date 20260301'),
        ('cmd-fotmob-setup', 'FotMob warehouse setup', 'fotmob', pill('FotMob', 'fotmob') + pill('Executes DDL', 'destructive'),
         [('Interface', '<code>depthmark setup-fotmob-warehouse</code> · <code>scripts/orchestration/setup_fotmob_warehouse.py</code>'),
          ('Scope', 'None. No <code>--dry-run</code>.'),
          ('Effect', 'Creates missing Bronze, Silver, and Gold objects in dependency order. Never drops or alters a table. Exits non-zero on schema drift before creating anything.')],
         'depthmark setup-fotmob-warehouse'),
        ('cmd-fotmob-scrape', 'FotMob scraping', 'fotmob', pill('FotMob', 'fotmob') + pill('Writes artifacts', 'neutral'),
         [('Interface', '<code>depthmark scrape-fotmob</code> · <code>scripts/bronze/scrape_fotmob.py</code>'),
          ('Scope', 'Positional date or range, <code>--single-date</code>, <code>--month</code>, <code>--today</code>, <code>--yesterday</code>, <code>--days N</code>. No <code>--dry-run</code>.'),
          ('Effect', 'Completed dates go to Historical. <code>--today</code> goes to Live. <code>--force</code> re-scrapes processed matches.')],
         'depthmark scrape-fotmob 20251201 --days 7'),
        ('cmd-fotmob-bronze', 'FotMob Bronze loading', 'fotmob', pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark load-fotmob-bronze</code> · <code>scripts/bronze/load_fotmob_bronze.py</code>'),
          ('Scope', 'Date, range, month, or <code>--full-history</code>'),
          ('Preview', '<code>--dry-run</code> previews the plan. <code>--stats</code> is observational.'),
          ('Effect', 'Loads Historical facts into <code>bronze.*</code>. Live is excluded. <code>--force</code> reloads. <code>--truncate</code> clears the selected tables and is broader than a date, so read its dry run first.')],
         'depthmark load-fotmob-bronze --date 20251208 --dry-run'),
        ('cmd-fotmob-silver', 'FotMob Silver loading', 'fotmob', pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark load-fotmob-silver</code> · <code>scripts/silver/load_fotmob_silver.py</code>'),
          ('Scope', 'Exactly one of <code>--date</code>, <code>--month</code>, <code>--full-history</code>. No range.'),
          ('Effect', 'Stages SQL output, validates it, replaces the selected scope. Bronze must be loaded first.')],
         'depthmark load-fotmob-silver --month 202512 --dry-run'),
        ('cmd-fotmob-gold', 'FotMob Gold loading', 'fotmob', pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark load-fotmob-gold</code> · <code>scripts/gold/load_fotmob_gold.py</code>'),
          ('Scope', 'Exactly one of date, month, full history. <code>--part all|scenarios|signals</code>.'),
          ('Effect', 'Stages and commits Gold tables. <code>--part scenarios</code> skips signals and activations. <code>--part signals</code> rebuilds activations after success.')],
         'depthmark load-fotmob-gold --month 202512 --part scenarios --dry-run'),
        ('cmd-fotmob-pipeline', 'FotMob pipeline', 'fotmob', pill('FotMob', 'fotmob') + pill('Executes workflow', 'neutral'),
         [('Interface', '<code>depthmark run-fotmob-pipeline</code> · <code>scripts/orchestration/run_fotmob_pipeline.py</code>'),
          ('Scope', 'Date, range, month, or <code>--full-history</code>. No <code>--dry-run</code>.'),
          ('Effect', 'Runs scrape, Bronze, Silver, Gold, and activations by mode and skip flags. See <a href="@@orch-skip@@">Orchestration</a>.')],
         'depthmark run-fotmob-pipeline --date 20251208'),
        ('cmd-oddspedia-setup', 'Oddspedia warehouse setup', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Executes DDL', 'destructive'),
         [('Interface', '<code>depthmark setup-oddspedia-warehouse</code> · <code>scripts/oddspedia/setup_oddspedia_warehouse.py</code>'),
          ('Preview', '<code>--dry-run</code> prints the DDL paths without connecting to ClickHouse.'),
          ('Effect', 'Creates missing Bronze and resolution tables. Never drops. Non-zero on drift.')],
         'depthmark setup-oddspedia-warehouse --dry-run'),
        ('cmd-oddspedia-discover', 'Oddspedia event discovery', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Writes artifacts', 'neutral'),
         [('Interface', '<code>depthmark discover-oddspedia-events</code> · <code>scripts/oddspedia/discover_oddspedia_events.py</code>'),
          ('Scope', 'Date, month, or range. Default today.'),
          ('Preview', 'None.'),
          ('Effect', 'Writes inventories under the date lock. <code>--retry-incomplete</code> retries incomplete discovery. An empty date is valid only when completeness is proven.')],
         'depthmark discover-oddspedia-events --date 20260301'),
        ('cmd-oddspedia-prioritize', 'Oddspedia priority planning', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark prioritize-oddspedia-events</code> · <code>scripts/oddspedia/prioritize_oddspedia_events.py</code>'),
          ('Scope', '<code>--silver-reference-window-ready</code> is required.'),
          ('Preview', '<code>--dry-run</code> writes no artifacts, manifests, logs, or locks.'),
          ('Effect', 'Computes priority decisions. The flag verifies the D−1, D, D+1 FotMob window. It never fills missing fixtures.')],
         'depthmark prioritize-oddspedia-events --date 20260301 --silver-reference-window-ready --dry-run'),
        ('cmd-oddspedia-scrape', 'Oddspedia match scraping', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Writes artifacts', 'neutral'),
         [('Interface', '<code>depthmark scrape-oddspedia-matches</code> · <code>scripts/oddspedia/scrape_oddspedia_matches.py</code>'),
          ('Scope', 'Date, range, or month. <code>--priority-tier xG|ratings|lower|unmatched</code>, default <code>lower</code>.'),
          ('Effect', 'Extracts match artifacts and completeness evidence. <code>--workers N</code> sets Chrome workers (default 1). <code>--retry-failed</code> retries failed extractions.')],
         'depthmark scrape-oddspedia-matches --date 20260301 --priority-tier lower --workers 3'),
        ('cmd-oddspedia-pipeline', 'Oddspedia intake pipeline', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Executes intake', 'neutral'),
         [('Interface', '<code>depthmark run-oddspedia-pipeline</code> · <code>scripts/oddspedia/run_oddspedia_pipeline.py</code>'),
          ('Scope', 'Date, range, or month. <code>--silver-reference-window-ready</code> required. No <code>--full-history</code>, no <code>--dry-run</code>.'),
          ('Effect', 'Discovery, prioritization, scraping. Bronze and resolution are separate commands.')],
         'depthmark run-oddspedia-pipeline --date 20260301 --silver-reference-window-ready'),
        ('cmd-oddspedia-bronze', 'Oddspedia Bronze publication', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark load-oddspedia-bronze</code> · <code>scripts/oddspedia/load_oddspedia_bronze.py</code>'),
          ('Scope', 'One date, range, or month. No <code>--full-history</code>.'),
          ('Preview', '<code>--dry-run</code> plans from local artifacts. No ClickHouse writes, no mutation lock.'),
          ('Effect', 'Admits audited artifacts, stages facts, replaces the date, records publication state.')],
         'depthmark load-oddspedia-bronze --date 20260301 --dry-run'),
        ('cmd-oddspedia-resolve', 'Oddspedia Silver resolution', 'oddspedia', pill('Oddspedia', 'oddspedia') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>depthmark resolve-oddspedia-events</code> · <code>scripts/oddspedia/resolve_oddspedia_events.py</code>'),
          ('Scope', 'One date, range, or month. Readiness flag recommended for final outcomes.'),
          ('Preview', '<code>--dry-run</code> still reads ClickHouse.'),
          ('Effect', 'Reads published Bronze and FotMob Silver, then persists the resolution edge unless dry-run.')],
         'depthmark resolve-oddspedia-events --date 20260301 --silver-reference-window-ready --dry-run'),
        ('cmd-gold-jobs', 'Selected Gold SQL jobs', 'fotmob',
         pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented') + pill('Script only', 'neutral'),
         [('Interface', '<code>scripts/gold/run_gold_sql_jobs.py</code>'),
          ('Scope', 'Exactly one of date, month, full history. <code>--kind scenario|signal</code>, or omit for both.'),
          ('Selectors', 'One of <code>--id</code>, <code>--entity match|player|team</code>, <code>--family</code>. Entity and family apply to signals only. '
                        '<code>shooting</code> selects the family; <code>shooting_goals</code> narrows to one subfamily.'),
          ('Effect', 'Stages and replaces the selected outputs. Does not rebuild activations.')],
         'python3 scripts/gold/run_gold_sql_jobs.py --date 20251208 --kind signal --family shooting_goals --dry-run'),
        ('cmd-activations', 'Signal activation rebuild', 'fotmob',
         pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented') + pill('Script only', 'neutral'),
         [('Interface', '<code>scripts/gold/activations/build_signal_activations.py</code>'),
          ('Scope', 'Exactly one of date, month, full history.'),
          ('Options', '<code>--catalog-dir</code>, <code>--source-db</code>, <code>--target-db</code>, <code>--verbose</code>'),
          ('Effect', 'Replaces <code>gold.signal_activations</code> in the scope. Run after successful signal commits. A bounded scope preserves other dates.')],
         'python3 scripts/gold/activations/build_signal_activations.py --month 202512 --dry-run'),
        ('cmd-gold-setup', 'Gold schema setup', 'fotmob',
         pill('FotMob', 'fotmob') + pill('Executes DDL', 'destructive') + pill('Script only', 'neutral'),
         [('Interface', '<code>scripts/gold/setup_clickhouse_gold.py</code>'),
          ('Scope', '<code>--part all</code> (default), <code>scenarios</code>, or <code>signals</code>.'),
          ('Effect', 'Creates Gold DDL. Materializes no rows. A Gold load is still required.')],
         'python3 scripts/gold/setup_clickhouse_gold.py --part signals'),
        ('cmd-s3', 'Historical archive transfer', 'fotmob',
         pill('FotMob', 'fotmob') + pill('Dry-run', 'implemented') + pill('Script only', 'neutral'),
         [('Interface', '<code>scripts/bronze/sync_s3.py</code>, using the <code>S3_*</code> environment'),
          ('Scope', '<code>upload</code> or <code>download</code>, plus one date, month, range, or <code>--all</code>'),
          ('Options', '<code>--force</code> replaces a destination. <code>--allow-incomplete</code> is an upload-only override.'),
          ('Effect', 'Moves Historical archives only. Independent of pipeline success.')],
         'python3 scripts/bronze/sync_s3.py download --start-date 20251201 --end-date 20251207 --dry-run'),
        ('cmd-quality', 'Warehouse data quality', 'fotmob', pill('FotMob', 'fotmob') + pill('Observational', 'neutral'),
         [('Interface', '<code>scripts/quality/check_data_quality.py</code>'),
          ('Scope', 'Date, month, or full history. Omitted scope checks full history.'),
          ('Options', '<code>--layers bronze,silver,gold|all</code>, <code>--reconciliation-checks auto|all|none|names</code>, <code>--sample-limit N</code>, <code>--strict</code>'),
          ('Effect', 'Logical duplicates and FotMob Bronze-to-Silver reconciliation. Not an Oddspedia acceptance check. Exit codes: <a href="@@page:quality@@">Quality</a>.')],
         'python3 scripts/quality/check_data_quality.py --month 202512 --strict'),
        ('cmd-logging', 'Logging style check', 'shared', pill('Shared', 'shared') + pill('Source check', 'neutral'),
         [('Interface', '<code>scripts/quality/check_logging_style.py</code>. No arguments.'),
          ('Effect', 'Checks runtime logging conventions in the Python source. Does not inspect data.')],
         'python3 scripts/quality/check_logging_style.py'),
        ('cmd-indexes', 'MongoDB index bootstrap', 'shared', pill('Shared', 'shared') + pill('Creates indexes', 'neutral'),
         [('Interface', '<code>scripts/mongodb/init_indexes.py</code>'),
          ('Effect', 'Creates content collection indexes. Separate from catalog sync.')],
         'python3 scripts/mongodb/init_indexes.py'),
        ('cmd-catalogs', 'Signal catalog synchronization', 'shared', pill('Shared', 'shared') + pill('Dry-run', 'implemented'),
         [('Interface', '<code>scripts/mongodb/sync_signal_catalogs.py</code>'),
          ('Preview', '<code>--dry-run</code> validates and makes no writes.'),
          ('Effect', 'Writes only the <code>signals</code> collection. Does not rebuild ClickHouse signals or activations.')],
         'python3 scripts/mongodb/sync_signal_catalogs.py --dry-run'),
        ('cmd-maintenance', 'ClickHouse optimization', 'shared', pill('Shared', 'shared') + pill('Preview by default', 'implemented'),
         [('Interface', '<code>scripts/maintenance/optimize_clickhouse.py</code>'),
          ('Scope', '<code>--layer bronze|silver|gold|all</code>, <code>--database</code>, optional <code>--table</code>'),
          ('Preview', 'Default. Nothing changes without <code>--execute</code>.'),
          ('Effect', 'Prints <code>OPTIMIZE TABLE … FINAL DEDUPLICATE</code>. Does not fix incorrect logic.')],
         'python3 scripts/maintenance/optimize_clickhouse.py --layer gold --database gold_signals'),
        ('cmd-recreate', 'ClickHouse table recreation', 'shared', pill('Shared', 'shared') + pill('Drops with --execute', 'destructive'),
         [('Interface', '<code>scripts/maintenance/recreate_clickhouse_tables.py</code>'),
          ('Scope', '<code>--drifted</code>, <code>--table</code>, <code>--database</code>, or <code>--layer</code>'),
          ('Preview', 'Default. Lists tables and current row counts.'),
          ('Effect', '<code>--execute</code> drops and recreates empty from setup DDL. Never reloads rows; rerun the layer loader afterward. The only supported drift fix.')],
         'python3 scripts/maintenance/recreate_clickhouse_tables.py --drifted'),
        ('cmd-turnstile', 'FotMob token refresh', 'fotmob', pill('FotMob', 'fotmob') + pill('Updates local credentials', 'neutral'),
         [('Interface', '<code>scripts/refresh_turnstile.py</code>. No arguments.'),
          ('Effect', 'Reads the challenge cookie from Chrome and updates the local <code>credentials.json</code>. Keep that file local.')],
         'python3 scripts/refresh_turnstile.py'),
    ]
    for cid, title, src, pills_html, rows, code in specs:
        cards_html.append(cmd(cid, title, src, pills_html, rows, code))
    b.append('<div id="commands-cards" data-scope-root>' + ''.join(cards_html) + '</div>')
    b.append('<p class="count" style="margin-top:0.6rem">26 command entries: 15 canonical CLI commands plus script-only tools.</p>')
    b.append(sec('commands-dropping', 'Dropping utilities',
                 'These scripts drop warehouse tables. They sit outside this matrix. Read each script before use.'))
    b.append(callout('danger', '<p><code>scripts/bronze/drop_clickhouse.py</code>, <code>scripts/silver/drop_clickhouse.py</code>, and '
                               '<code>scripts/gold/drop_clickhouse_scenarios.py</code> drop tables. Schema drift is handled by table recreation, '
                               'and setup never drops tables.</p>'))
    return ''.join(b)


def page_orchestration():
    b = []
    b.append(sec('orch-pipeline', 'FotMob pipeline with skip flags',
                 'The pipeline runs four stages in order. A failed date skips its downstream stages; other dates may continue.'))
    b.append(dia_pipeline())
    b.append(sec('orch-modes', 'Modes', 'The three mode flags are mutually exclusive. <code>--full-history</code> cannot combine with <code>--bronze-only</code>.'))
    b.append(table('Pipeline modes', ['Mode', 'Behavior'], [
        ['Date or range', 'Full route for each date.'],
        ['<code>--month</code>', 'Scrapes completed dates, then loads Bronze and runs Silver and Gold once for the month.'],
        ['<code>--full-history</code>', 'Reuses local Historical files, skips scraping. Cannot combine with <code>--bronze-only</code>.'],
        ['<code>--bronze-only</code>', 'Scrapes only.'],
        ['<code>--silver-only</code> / <code>--gold-only</code>', 'Runs one layer for the scope. Requires the layer below to exist.'],
    ]))
    b.append(sec('orch-skip', 'Skip flags', 'Each skip flag removes one stage. Stages that remain keep their normal writes.'))
    b.append(table('Skip flags', ['Flag', 'Effect'], [
        ['<code>--skip-fotmob</code>', 'Skips every FotMob stage.'],
        ['<code>--skip-bronze</code>', 'Skips <em>scraping</em>. Loads existing Historical files into Bronze.'],
        ['<code>--skip-clickhouse</code>', 'Skips the ClickHouse Bronze load. Scraping still runs.'],
        ['<code>--skip-silver</code>', 'Skips Silver.'],
        ['<code>--skip-gold</code>', 'Skips Gold, including activations.'],
    ]))
    b.append(callout('warn', '<p><strong>Naming trap.</strong> <code>--skip-bronze</code> skips scraping, not the Bronze load. '
                             '<code>--skip-clickhouse</code> skips the Bronze load. <code>--bronze-only</code> means scraping only.</p>'))
    b.append(sec('orch-recovery', 'Recovery', 'Rerun the narrowest failed command with the same scope. Identical reruns converge after a partial commit.'))
    b.append(table('Recovery by failure', ['Failure', 'Recovery'], [
        ['FotMob scraping', 'Read the report, refresh a challenged token, re-scrape the dates.'],
        ['FotMob Bronze', 'Fix parsing or contracts, preview, reload the date, then reconcile Silver.'],
        ['Oddspedia scrape', 'Retry incomplete discovery or failed extraction with the matching selector.'],
        ['Oddspedia Bronze or resolution', 'Repair evidence, republish the date, verify the FotMob window, resolve again.'],
        ['Silver or scenario SQL', 'Fix SQL, preview the same scope, rerun the layer or job.'],
        ['Signal SQL or activations', 'Rerun the signal job, then rebuild activations for the same scope.'],
        ['Catalog metadata', 'Fix the Git catalog, dry-run, then synchronize.'],
        ['Commit fails mid-batch', 'Some tables may be committed. Fix the cause and rerun the same scope.'],
    ]))
    b.append(sub('orch-troubleshooting', 'Troubleshooting'))
    b.append(cards([
        ('Date selector rejected', 'Each family takes its own selector. FotMob scraping takes a positional date or <code>--single-date</code>, '
                                   'not <code>--date</code>. See <a href="@@commands-scope@@">scope compatibility</a>.', 'ctx-ops', None),
        ('Reference window not ready', 'Prepare FotMob Bronze and Silver for D−1, D, D+1. The flag verifies; it does not load missing references.',
         'ctx-oddspedia', None),
        ('Resolution refuses a date', 'The latest <code>load_status</code> must be <code>published</code>. Scraping alone does not publish.',
         'ctx-oddspedia', None),
        ('Old activations after a fix', 'Rerun the corrected signal, then rebuild activations for that scope. The job runner does not rebuild them.',
         'ctx-gold', None),
        ('Physical versions remain', 'Expected after a successful run. Check logical duplicates separately. Optimize only after previewing.',
         'ctx-silver', None),
        ('Catalog edit, rows unchanged', 'Catalog sync updates only MongoDB. Rebuild SQL or activations only when the changed assets require it.',
         'ctx-ops', None),
    ]))
    b.append(sec('orch-schedule', 'Scheduling'))
    b.append(callout('', '<p><code>scripts/install_schedule.sh</code> writes a host crontab block. <code>scripts/orchestration/run_scheduled_job.py</code> '
                         'runs named jobs such as <code>fotmob-daily</code> under a lock. Scheduling is external (ADR 0027). Bootstrap installs '
                         'it unless <code>--no-schedule</code> is passed (ADR 0030).</p>'))
    return ''.join(b)


def page_quality():
    b = []
    b.append(sec('quality-gates', 'Gates in order',
                 'Each gate has a scope and a different failure meaning. Only the danger gates can fail a strict run.'))
    b.append(dia_quality())
    b.append(sec('quality-proves', 'What each gate proves'))
    b.append(table('Scope and limits', ['Gate', 'Proves', 'Does not prove'], [
        ['Service health', 'Reachability, storage, free disk', 'Artifact completeness, correctness'],
        ['Scraping report', 'Discovery and scrape evidence, attention states', 'Bronze publication, warehouse validity'],
        ['Oddspedia admission', 'Complete discovery, audited payloads, published state', 'Anything beyond published dates'],
        ['FotMob quality', 'Logical duplicates, Bronze-to-Silver reconciliation', 'Bronze-to-Gold row parity (Gold has its own grain)'],
        ['Reference window', 'FotMob fixture reconciliation across D−1, D, D+1', 'Dates outside that window'],
        ['Catalog validation', 'Frontmatter and assets meet the contract', 'SQL execution, consumer APIs'],
    ]))
    b.append(sec('quality-exit', 'Exit codes', '<code>check_data_quality.py</code> returns these codes.'))
    b.append(cards([
        ('0 · clean', 'No failures, or only non-strict findings.', 'ctx-silver', None),
        ('1 · failure', 'Strict mode found logical duplicates or a reconciliation mismatch, or an operational error. Physical versions never fail.',
         'ctx-oddspedia', None),
        ('2 · usage', 'Invalid arguments.', 'ctx-ops', None),
    ]))
    b.append('<p class="small muted"><code>report_scraping.py --fail-on-attention</code> exits 1 on incomplete or error states. '
             'Review the report before treating it as acceptance.</p>')
    b.append(sec('quality-acceptance', 'Acceptance sequence'))
    b.append(stepper([
        ('Health', 'Check service health, preview the loader for the scope.', 'var(--ok)'),
        ('Source', 'Inspect the scraping report. Resolve incomplete evidence.', 'var(--ok)'),
        ('Commit', 'Confirm layer commits. For Oddspedia, confirm <code>published</code>.', 'var(--ok)'),
        ('Strict check', 'Run FotMob quality with an explicit scope and <code>--strict</code>.', 'var(--ok)'),
        ('Activations', 'After signal fixes, rebuild activations and validate catalogs.', 'var(--ok)'),
    ]))
    return ''.join(b)


def page_infrastructure():
    b = []
    b.append(sec('infra-topology', 'Topology',
                 'State lives in three places: host files, ClickHouse, and MongoDB. S3 is an optional side channel.'))
    b.append(dia_infra())
    b.append(sec('infra-bootstrap', 'Bootstrap',
                 'Run once per host. Setup creates tables only and loads no data. New steps belong in the bootstrap (ADR 0030).'))
    b.append(dia_bootstrap())
    b.append('<pre><code>scripts/bootstrap.sh            # server: generated .env, stack, setup, MongoDB, schedule\n'
             'scripts/bootstrap.sh --local    # local development\n'
             'scripts/bootstrap.sh --env-only # only prepare .env\n'
             'scripts/bootstrap.sh --no-schedule</code></pre>')
    b.append(sec('infra-credentials', 'Credentials and ports', 'Local and production differ on purpose. Never run local credentials in production.'))
    b.append(table('Local and production policy (ADR 0005)', ['Setting', 'Local', 'Production'], [
        ['<code>DEPTHMARK_ENV</code>', '<code>local</code>', '<code>production</code>'],
        ['Passwords', 'Required from <code>.env</code>', 'Non-default, required'],
        ['Published ports', 'On <code>DEPTHMARK_BIND_ADDRESS</code> (default <code>127.0.0.1</code>)', 'Explicit network policy'],
        ['Secrets', '<code>.env</code>', 'Secrets management'],
    ]))
    b.append(callout('danger', '<p><strong>Never run local credentials in production.</strong> <code>DEPTHMARK_ENV</code> controls all credential validation.</p>'))
    b.append(sec('infra-s3', 'S3 variables', 'Optional. Used only by the explicit transfer command.'))
    b.append(table('S3 environment', ['Variable', 'Requirement', 'Purpose'], [
        ['<code>S3_ENDPOINT</code>', 'Required', 'Endpoint URL'],
        ['<code>S3_ACCESS_KEY</code>, <code>S3_SECRET_KEY</code>', 'Required', 'Credentials. Never commit.'],
        ['<code>S3_BUCKET</code>', 'Optional', 'Otherwise inferred from a virtual-hosted endpoint'],
        ['<code>S3_REGION</code>', 'Optional', 'Defaults to <code>ir-tbz-sh1</code>'],
    ]))
    return ''.join(b)


ADRS = [
    ('0001', 'Use generic Gold SQL runners', 'implemented', 'Accepted'),
    ('0002', 'Orchestrate layer entrypoints via CLI', 'implemented', 'Accepted'),
    ('0003', 'Split Gold ClickHouse namespaces', 'implemented', 'Accepted'),
    ('0004', 'Keep Gold scenario bulk disabled until validated', 'superseded', 'Superseded: scenario bulk is enabled'),
    ('0005', 'Local dev credentials vs production policy', 'implemented', 'Accepted'),
    ('0006', 'Version signal activation identity scheme', 'implemented', 'Accepted'),
    ('0007', 'SQL owns analytical transformations', 'implemented', 'Accepted'),
    ('0008', 'Author signal catalogs in markdown', 'implemented', 'Accepted'),
    ('0009', 'Retire legacy Gold per-output runners', 'implemented', 'Accepted'),
    ('0010', 'Introduce src application services behind script entrypoints', 'implemented', 'Accepted'),
    ('0011', 'Use full-table Gold activation rebuilds', 'partial', 'Superseded for scoped runs by ADR 0018'),
    ('0012', 'Bronze filesystem retention and DLQ replay policy', 'implemented', 'Accepted'),
    ('0013', 'FotMob-only provider scope', 'superseded', 'Superseded by ADR 0021'),
    ('0014', 'Single enriched signal activation serving table', 'implemented', 'Accepted'),
    ('0015', 'Redesign Telegram notification module', 'implemented', 'Accepted'),
    ('0016', 'Unify configuration systems', 'implemented', 'Accepted'),
    ('0017', 'Split FotMob Bronze Live and Historical storage', 'implemented', 'Accepted'),
    ('0018', 'Use scope-aware warehouse replacement', 'implemented', 'Accepted'),
    ('0019', 'Separate logical duplicates from physical row versions', 'implemented', 'Accepted'),
    ('0020', 'Keep ClickHouse optimization out of setup', 'implemented', 'Accepted'),
    ('0021', 'Add Oddspedia as an isolated source domain', 'implemented', 'Accepted'),
    ('0022', 'Prioritize Oddspedia links against DepthMark Silver', 'implemented', 'Accepted'),
    ('0023', 'Model FotMob and Oddspedia as parallel medallion pipelines', 'implemented', 'Accepted'),
    ('0024', 'Use source-qualified operational script names', 'implemented', 'Accepted, amended'),
    ('0025', 'Unify scraping status and reports', 'implemented', 'Accepted, amended'),
    ('0026', 'Make warehouse setup non-destructive', 'implemented', 'Accepted'),
    ('0027', 'Use an external scheduler', 'implemented', 'Accepted'),
    ('0028', 'Record scoped publication status', 'implemented', 'Accepted'),
    ('0029', 'Split ClickHouse identities and isolate staging', 'implemented', 'Accepted'),
    ('0030', 'Automate server bootstrap', 'implemented', 'Accepted'),
]


def page_contracts():
    b = []
    b.append(sec('contracts-authority', 'Who owns which question',
                 'This reference owns concepts, source ownership, and the command matrix. Detailed contracts live in the documents below.'))
    b.append(table('Authoritative reference per question', ['Question', 'Authority'], [
        ['What does a concept mean?', 'This reference. Layer details in <code>docs/data-flow/*.md</code>.'],
        ['How is a workflow run?', '<code>docs/DEVELOPMENT_ARCHITECTURE.md</code>: command surface and runbook'],
        ['What scripts exist?', '<code>scripts/README.md</code>'],
        ['What must a script preserve?', '<code>docs/SCRIPTS_CONTRACT.md</code>'],
        ['What is a valid scenario or signal?', '<code>scripts/gold/scenario/SCENARIOS_CONTRACT.md</code>, '
         '<code>scripts/gold/signal/contracts/</code>, and the SQL, DDL, and catalogs'],
        ['Who authors signal metadata?', 'Git catalogs in <code>scripts/gold/signal/catalogs/</code>'],
        ['What is a valid Oddspedia artifact?', '<code>schemas/oddspedia/*.schema.json</code>'],
        ['Why was a boundary chosen?', '<code>docs/adr/</code>. Supersede rather than edit when a contract changes.'],
    ]))
    b.append(sec('contracts-adr', 'Decision index', 'Filter by number or topic. Titles are as written in <code>docs/adr/</code>.'))
    b.append('<div class="toolbar"><input class="input" type="search" placeholder="Filter decisions" aria-label="Filter decisions" '
             'data-filter-input data-scope="#adr-list"><span class="count" data-count-for="#adr-list" data-count-label="decisions"></span></div>')
    rows, attrs = [], []
    pills = {'implemented': 'implemented', 'partial': 'partial', 'superseded': 'superseded'}
    for num, title, state, status in ADRS:
        rows.append([num, title, f'<span class="pill {pills[state]}">{status}</span>'])
        attrs.append(f' data-search="{esc((num + " " + title + " " + status).lower())}"')
    b.append('<div id="adr-list" data-scope-root>' + table('Architecture decision records', ['ADR', 'Title', 'Status'], rows, attrs) + '</div>')
    b.append(sec('contracts-keeping', 'Keeping this reference accurate'))
    b.append('<ul><li>Update the affected page in the same change as concepts, source maturity, layer ownership, scripts, SQL jobs, '
             'or platform boundaries.</li><li>Counts describe checked-in assets. Re-count them when the inventory changes.</li>'
             '<li>Diagrams are generated from one definition per figure. A structural change means updating the figure, not only the text.</li></ul>')
    b.append(callout('', f'<p><strong>Verification.</strong> Last verified {VERIFIED} against <code>src/cli.py</code>, the scripts, '
                         'ClickHouse DDL and DML, the MongoDB collection definitions, and <code>docs/adr/</code>. Replacement details, the S3 '
                         'archive policy, and Oddspedia artifact field details were carried over and not re-checked line by line.</p>'))
    return ''.join(b)


BUILDERS = {
    'index': (page_index, 'Overview', 'Start here', 'DepthMark warehouse reference',
              'The source of truth for DepthMark concepts, source ownership, warehouse layers, and operator commands. '
              'Start here, then open the page for the question you have.'),
    'concepts': (page_concepts, 'Concepts & glossary', 'Start', 'Concepts and ownership',
                 'Shared terms and the ownership matrix. Use these definitions to read every other page.'),
    'fotmob': (page_fotmob, 'FotMob', 'Source domain', 'FotMob source domain',
               'The FotMob path from API payloads to analytical products. Implemented through Gold.'),
    'oddspedia': (page_oddspedia, 'Oddspedia', 'Source domain', 'Oddspedia source domain',
                  'Intake, Bronze publication, and the Silver resolution edge. Gold is planned.'),
    'bronze': (page_bronze, 'Bronze', 'Layer 1 · Preserve', 'Bronze: source fidelity',
               'Source artifacts as received, loaded into raw facts with no business joins.'),
    'silver': (page_silver, 'Silver', 'Layer 2 · Conform', 'Silver: conformed entities',
               'Standardized keys, types, and entities, plus the publication state of each batch.'),
    'gold': (page_gold, 'Gold', 'Layer 3 · Materialize', 'Gold: product outputs',
             'Scenarios, signals, and the activation serving table, and how they depend on Silver.'),
    'scenarios': (page_scenarios, 'Scenarios', 'Product · Gold', 'Scenarios',
                  'Narrative analytical patterns, packaged with their SQL, table, and catalog.'),
    'signals': (page_signals, 'Signals', 'Product · Gold', 'Signals and activation identity',
                'Naming, taxonomy, catalog rules, and how activation identifiers are built.'),
    'mongodb': (page_mongodb, 'MongoDB catalogs', 'Serving', 'Catalog serving in MongoDB',
                'Git owns catalog metadata; MongoDB serves a synchronized copy.'),
    'commands': (page_commands, 'Command reference', 'Operate', 'Command reference',
                 'Dependencies, scope rules, and a card for every command, with its preview and effect.'),
    'orchestration': (page_orchestration, 'Orchestration', 'Operate', 'Orchestration and recovery',
                      'Pipeline stages, skip flags, modes, and how to recover from each failure.'),
    'quality': (page_quality, 'Quality & acceptance', 'Operate', 'Quality and acceptance',
                'Quality gates, exit codes, and the acceptance sequence for a run.'),
    'infrastructure': (page_infrastructure, 'Infrastructure', 'Operate', 'Infrastructure',
                       'Runtime topology, bootstrap order, credentials, and the optional S3 archive.'),
    'contracts': (page_contracts, 'Contracts & decisions', 'Reference', 'Contracts and decisions',
                  'Who owns which question, and the index of architecture decision records.'),
}


def read_asset(name):
    with open(os.path.join(ROOT, REF, 'assets', name), encoding='utf-8') as f:
        return f.read()


def search_json():
    entries = [{'t': e['t'], 'p': PAGE[e['page']][0], 'id': e['id']} for e in SEARCH]
    # Escape '<' so the JSON can never close the surrounding script tag.
    return json.dumps(entries, ensure_ascii=False).replace('<', '\\u003c')


def page_switch_css():
    """Show one page at a time with :target; body.js-nav switches to script-driven navigation."""
    rules = [
        '/* Page switching: pure CSS by default; body.js-nav is set by script in embedded viewers */',
        '.page { display: none; scroll-margin-top: calc(var(--header) + 1rem); }',
        'body:not(.js-nav) .page:target, body:not(.js-nav) .page:has(:target) { display: block; }',
        'body:not(.js-nav) main:not(:has(.page:target)):not(:has(.page :target)) #index { display: block; }',
        'body.js-nav .page.is-active { display: block; }',
        '@supports not selector(:has(*)) { body:not(.js-nav) .page { display: block; } }',
        '@media print { .page { display: block !important; } }',
    ]
    sel = []
    for slug in PAGE:
        sel.append(f'body:not(.js-nav):has(#{slug}:target) .sidebar a[data-page="{slug}"]')
        sel.append(f'body:not(.js-nav):has(#{slug} :target) .sidebar a[data-page="{slug}"]')
    sel.append('body:not(.js-nav):not(:has(.page:target)):not(:has(.page :target)) .sidebar a[data-page="index"]')
    rules.append(',\n'.join(sel) + ' { background: var(--accent-soft); color: var(--accent); '
                 'font-weight: 650; border-left-color: var(--accent); }')
    return '\n'.join(rules)


ALIASES = {'index': 'overview', 'gold': 'gold/activation-rebuild'}   # anchors used by older links


def render_article(slug, body, toc, section_open):
    title, eyebrow, h1, lead = BUILDERS[slug][1], BUILDERS[slug][2], BUILDERS[slug][3], BUILDERS[slug][4]
    order = [p[0] for p in PAGES]
    i = order.index(slug)
    toc_html = ''
    if toc:
        toc_html = '<nav class="toc" aria-label="On this page">' + ''.join(
            f'<a href="#{a}">{t}</a>' for a, t in toc) + '</nav>'
    pager = '<nav class="pager" aria-label="Pages">'
    if i > 0:
        pager += f'<a class="prev" href="#{order[i - 1]}"><div class="dir">Previous</div>{PAGE[order[i - 1]][0]}</a>'
    if i < len(order) - 1:
        pager += f'<a class="next" href="#{order[i + 1]}"><div class="dir">Next</div>{PAGE[order[i + 1]][0]}</a>'
    pager += '</nav>'
    crumbs = (f'<p class="crumbs"><a href="#index">Reference</a> / {PAGE[slug][1]} / {title}</p>'
              if slug != 'index' else '<p class="crumbs">Reference / Overview</p>')
    alias = f'<span id="{ALIASES[slug]}"></span>' if slug in ALIASES else ''
    return (f'<article class="page {CTX[slug]}" id="{slug}">{alias}{crumbs}'
            f'<header class="page-head"><p class="eyebrow">{eyebrow}</p><h1>{h1}</h1>'
            f'<p class="lead">{lead}</p>{toc_html}</header>{body}'
            + ('</section>' if section_open else '') + pager
            + f'<footer>DepthMark · Warehouse reference · Last verified {VERIFIED} · '
              f'<a href="#{slug}">Back to top</a></footer></article>')


def render_document(bodies):
    css = read_asset('reference.css') + '\n' + page_switch_css()
    js = read_asset('reference.js')
    groups = []
    for g in ['Start', 'Sources', 'Layers', 'Products', 'Operate', 'Reference']:
        links = [f'<a href="#{s}" data-page="{s}"><span class="dot" style="--c:{c}"></span>{t}</a>'
                 for s, t, gg, c in PAGES if gg == g]
        groups.append(f'<div class="nav-group"><p class="nav-title">{g}</p>' + ''.join(links) + '</div>')
    articles = ''.join(render_article(s, *bodies[s]) for s in [p[0] for p in PAGES])
    top = ('<header class="topbar">'
           '<a class="brand" href="#index" aria-label="Warehouse reference overview"><span class="brand-mark" aria-hidden="true">DM</span>'
           '<span class="brand-text">Warehouse reference</span></a>'
           '<div class="search" role="search"><label class="sr-only" for="global-search">Search the reference</label>'
           '<input id="global-search" type="search" placeholder="Search tables, commands, concepts…" autocomplete="off">'
           '<kbd aria-hidden="true">/</kbd><div id="global-results" class="results" hidden></div></div>'
           '<button id="theme" class="theme-toggle" type="button" aria-pressed="false">Dark mode</button></header>')
    side = '<aside class="sidebar" aria-label="Reference pages">' + ''.join(groups) + '</aside>'
    doc = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
           '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
           '<base href="about:srcdoc">\n'
           '<script>if (location.href !== "about:srcdoc") { var b = document.querySelector("base"); if (b) b.remove(); }</script>\n'
           '<title>DepthMark warehouse reference</title>\n'
           '<meta name="description" content="Source of truth for DepthMark concepts, source ownership, warehouse layers, '
           'operator commands, quality gates, and decisions.">\n'
           f'<style>\n{css}\n</style>\n</head>\n<body>\n' + top
           + '<div class="layout">' + side + '<main id="content">' + articles + '</main></div>\n'
           f'<script>window.DM_SEARCH = {search_json()};</script>\n<script>\n{js}\n</script>\n</body>\n</html>\n')
    return doc


def resolve(text):
    def repl(m):
        tok = m.group(1)
        if tok.startswith('page:'):
            slug = tok[5:]
            if slug not in PAGE:
                raise SystemExit(f'unknown page token {tok}')
            return '#' + slug
        if tok not in REG:
            raise SystemExit(f'unknown anchor {tok}')
        return '#' + tok
    return re.sub(r'@@([^@]+)@@', repl, text)


def main():
    global CUR
    bodies = {}
    for slug in [p[0] for p in PAGES]:
        CUR = slug
        TOC.clear()
        SEC_OPEN[0] = False
        bodies[slug] = (BUILDERS[slug][0](), list(TOC), SEC_OPEN[0])
    clash = [s for s in PAGE if s in REG] + [a for a in ALIASES.values() if a in REG]
    if clash:
        raise SystemExit(f'page/alias ids collide with section anchors: {clash}')
    html_out = resolve(render_document({s: bodies[s] for s in bodies}))
    target = os.path.join(ROOT, INDEX_PATH)
    with open(target, 'w', encoding='utf-8') as f:
        f.write(html_out)
    print('wrote', INDEX_PATH, f'({len(html_out) // 1024} KB);', len(PAGES), 'pages;', len(REG), 'anchors;', len(SEARCH), 'search entries')


if __name__ == '__main__':
    main()
