#!/usr/bin/env python3
"""Pure metadata classification; never opens assets or qualifies a renderer.

Titles and figure-specific contract structure are evidence. Package names,
plotting functions, old broad categories, captions and search_text are not.
Original IDs, titles, paths and source hashes remain untouched.
"""
from __future__ import annotations

import hashlib
import re
import unicodedata


CATEGORY_LABELS = {
    '01_相关性图': '相关性图',
    '02_表达与常规热图': '表达与常规热图',
    '03_气泡图与DotPlot': '气泡图与DotPlot',
    '04_火山图': '火山图',
    '05_柱状图与条形图': '柱状图与条形图',
    '06_折线图与时序图': '折线图与时序图',
    '07_散点图与回归图': '散点图与回归图',
    '08_箱线图': '箱线图',
    '09_小提琴图': '小提琴图',
    '10_云雨图': '云雨图',
    '11_山脊图': '山脊图',
    '12_密度图与等高线图': '密度图与等高线图',
    '13_降维图': '降维图',
    '14_系统树与层级树': '系统树与层级树',
    '15_网络图': '网络图',
    '16_桑基图与冲击图': '桑基图与冲击图',
    '17_UpSet图与Venn图': 'UpSet图与Venn图',
    '18_雷达图': '雷达图',
    '19_三元图': '三元图',
    '20_泳道图': '泳道图',
    '21_森林图': '森林图',
    '22_生存与临床曲线': '生存与临床曲线',
    '23_饼图与层级占比图': '饼图与层级占比图',
    '24_棒棒糖图与哑铃图': '棒棒糖图与哑铃图',
    '25_共线性与序列比对图': '共线性与序列比对图',
    '26_基因组轨道图': '基因组轨道图',
    '27_曼哈顿图与QQ图': '曼哈顿图与QQ图',
    '28_地理地图': '地理地图',
    '29_空间表达图': '空间表达图',
    '30_机制图与示意图': '机制图与示意图',
    '31_表格与图形表': '表格与图形表',
    '32_图像与结构图': '图像与结构图',
    '33_版式与组合图': '版式与组合图',
    '34_富集曲线图': '富集曲线图',
    '35_瀑布图': '瀑布图',
    '36_序列相似度三角图': '序列相似度三角图',
    '97_图码配对待核': '图码配对待核',
    '98_论文与项目总览': '论文与项目总览',
    '99_待分类': '待分类',
}

# Shape expressions, not software names. English words have token boundaries.
_PATTERNS = {
    '01_相关性图': r'相关(?:性)?(?:热图|矩阵|图)|相关性分析矩阵|correlation[- ](?:matrix|heatmap|bubble)|matrix-regression|density-matrix',
    '02_表达与常规热图': r'热图|(?<![a-z])heatmaps?(?![a-z])|contact[- ]map|oncoprint',
    '03_气泡图与DotPlot': r'气泡|点阵|表达点图|(?<![a-z])(?:bubble|bubbles|dotplot)(?![a-z])|dot[- ]matrix',
    '04_火山图': r'火山|(?<![a-z])volcano(?![a-z])',
    '05_柱状图与条形图': r'柱状|柱形|条形|柱图|横条|分组柱|对比柱|并列柱|堆叠柱|堆积柱|(?<![a-z])bars?(?![a-z])|barplot|stacked[- ](?:bar|composition)',
    '06_折线图与时序图': r'折线|点线图|时序图|时间序列|拟合趋势线|平滑曲线|拟合曲线|线条路径|面积图|增长曲线|五列线图|(?<![a-z])time[- ]series(?![a-z])|line[- ](?:charts?|plots?)|pan[- ]core[- ]accumulation|growth[- ]curve|model[- ]curve',
    '07_散点图与回归图': r'散点|蜂群|蜂窝|点簇|(?<![a-z])scatter(?![a-z])|matrix-regression|bubble[- ]regression|regression[- ]panels',
    '08_箱线图': r'箱线|箱式|箱图|箱点图|(?<![a-z])box(?:plot|points|plots)(?![a-z])|box[- ](?:summary|summaries)',
    '09_小提琴图': r'小提琴|(?<![a-z])violin(?![a-z])',
    '10_云雨图': r'云雨|雨云|(?<![a-z])rain[- ]?cloud(?![a-z])',
    '11_山脊图': r'山脊|峰峦|山峦|(?<![a-z])ridge(?:line|lines)?(?![a-z])',
    '12_密度图与等高线图': r'等高线|核密度|联合密度|密度区域|密度水平|分歧.*密度|divergence[- ]density|overlaid.{0,30}densities|distribution[- ]histogram|(?<![a-z])histogram(?![a-z])',
    '13_降维图': r'(?<![a-z])(?:pca|pcoa|nmds|umap|t[- ]?sne)(?![a-z])|主成分|主坐标(?:分析|排序|图|可视化)|shared[- ]embedding|shared[- ]single[- ]cell[- ]embedding',
    '14_系统树与层级树': r'系统发育|时间树|物种树|基因树|家族树|最大似然树|分类层级树|树状图|树状|(?<![a-z])(?:phylogen(?:y|etic)|tree)(?![a-z])|clade[- ]tree|dendrogram|radial[- ]hierarchy|layered[- ]tree',
    '15_网络图': r'网络|(?<![a-z])network(?![a-z])|regulatory[- ]network|fixed[- ]grn|regulome',
    '16_桑基图与冲击图': r'桑基|冲击图|河流图|(?<![a-z])(?:sankey|alluvial)(?![a-z])',
    '17_UpSet图与Venn图': r'(?<![a-z])(?:upset|venn)(?![a-z])|韦恩|维恩|集合交集',
    '18_雷达图': r'雷达|蜘蛛图|(?<![a-z])radar(?![a-z])',
    '19_三元图': r'三元|(?<![a-z])ternary(?![a-z])',
    '20_泳道图': r'泳道|(?<![a-z])swimmer(?![a-z])',
    '21_森林图': r'森林图|(?<![a-z])forest[- ]plot(?![a-z])',
    '22_生存与临床曲线': r'生存曲线|生存图|Kaplan[- ]Meier|(?<![a-z])(?:roc|pr)[- ]?(?:曲线|curve)|决策曲线|限制性立方样条|(?<![a-z])rcs(?![a-z])',
    '23_饼图与层级占比图': r'饼图|甜甜圈|旭日图|沃罗诺伊树图|(?<![a-z])(?:pie|donut|doughnut|sunburst|treemap)(?![a-z])',
    '24_棒棒糖图与哑铃图': r'棒棒糖|哑铃|(?<![a-z])(?:lollipop|dumbbell)(?![a-z])',
    '25_共线性与序列比对图': r'共线|序列比对|蛋白域|膜拓扑|(?<![a-z])(?:synteny|syntenic)(?![a-z])|inversion[- ]zoom|sequence[- ]alignment',
    '26_基因组轨道图': r'基因组轨道|基因轨道|注释轨道|CENP-A轨道|染色体.*分布图|核型|同坐标轨道|基因箭头|genomic[- ](?:signal[- ]|density[- ]|coverage[- ])?tracks?|genome[- ]tracks?|gene[- ]structure[- ]tracks|compartment[- ]tracks?|chromosome[- ]tracks?',
    '27_曼哈顿图与QQ图': r'曼哈顿|(?<![a-z])manhattan(?![a-z])|(?<![a-z])qq[- ]?(?:plot|图)|manhattan[- ]qq',
    '28_地理地图': r'地图|地理分布|(?<![a-z])maps?(?![a-z])|geo[- ](?:network|flow)|geoflow|spatial[- ]grid',
    '29_空间表达图': r'空间转录组|spatial[- ](?:expression|transcriptom)',
    '30_机制图与示意图': r'机制图|示意图|解剖图|(?<![a-z])(?:mechanism|schematic|infographic|pictogram|metaphor)(?![a-z])',
    '31_表格与图形表': r'表格|图形表|(?<![a-z])table1(?![a-z])',
    '32_图像与结构图': r'照片|3D结构|三维结构|预测结构|(?<![a-z])(?:photo|photograph|protein[- ]structure)(?![a-z])',
    '33_版式与组合图': r'嵌套图|局部放大图|全流程|多面板|(?<![a-z])(?:composite|small[- ]multiples|multipanel|two[- ]panel)(?![a-z])|quantitative[_ -]grid|(?:method[- ]comparison|log[- ]model|comparison[- ]plus[- ]model|model[- ]curve|faceted[- ]estimate|multiscale[- ]spatial|matched[- ]map)[- ]grid|[2-9][x×][2-9]\s+grid',
    '34_富集曲线图': r'基因集富集.*图|(?<![a-z])gsea[- ](?:plot|curve)|enrichment[- ]curve',
    '35_瀑布图': r'瀑布图|(?<![a-z])waterfall(?![a-z])',
    '36_序列相似度三角图': r'自比对.*三角|序列相似度|序列相似性三角|sequence[- ]identity|self[- ]identity[- ]triangle|identity[- ]triangle',
}
_COMPILED = {key: re.compile(pattern, re.I) for key, pattern in _PATTERNS.items()}

# Source-derived names for ambiguous dimension titles. These are retrieval
# labels, not a scientific claim or visual/reproduction acceptance record.
_DIMENSION_NAMES = {
    'SCICASE-014': ('01_相关性图', ['01_相关性图'], '相关矩阵_corrplot'),
    'SCICASE-015': ('01_相关性图', ['01_相关性图', '05_柱状图与条形图'], '相关矩阵与柱状图_corrplot'),
    'SCICASE-016': ('01_相关性图', ['01_相关性图'], '相关矩阵与层次聚类_seaborn_Python'),
    'SCICASE-017': ('01_相关性图', ['01_相关性图'], '分组上下三角相关矩阵_同配色'),
    'SCICASE-018': ('01_相关性图', ['01_相关性图'], '分组上下三角相关矩阵_不同配色'),
    'SCICASE-019': ('01_相关性图', ['01_相关性图'], '聚类三角相关矩阵_ggplot2'),
    'SCICASE-020': ('02_表达与常规热图', ['02_表达与常规热图'], '二维变量矩阵热图_pheatmap'),
    'SCICASE-023': ('01_相关性图', ['01_相关性图', '03_气泡图与DotPlot'], '二维变量相关性点图_分面'),
    'SCICASE-024': ('01_相关性图', ['01_相关性图', '03_气泡图与DotPlot'], '相关性气泡矩阵_分组'),
    'SCICASE-025': ('01_相关性图', ['01_相关性图', '07_散点图与回归图'], '相关性与线性回归矩阵_GGally'),
    'SCICASE-026': ('01_相关性图', ['01_相关性图', '15_网络图'], '相关性矩阵与网络_GGally'),
    'SCICASE-027': ('01_相关性图', ['01_相关性图', '12_密度图与等高线图'], '相关性与核密度矩阵_Python_彩虹色'),
    'SCICASE-028': ('01_相关性图', ['01_相关性图', '12_密度图与等高线图'], '相关性与核密度矩阵_Python_红色'),
    'SCICASE-029': ('01_相关性图', ['01_相关性图', '12_密度图与等高线图'], '相关性与核密度矩阵_R_彩虹色'),
    'SCICASE-030': ('01_相关性图', ['01_相关性图', '12_密度图与等高线图'], '相关性与核密度矩阵_R_红色'),
    'SCICASE-031': ('01_相关性图', ['01_相关性图'], '多变量相关性图_linkET'),
}

_STRUCTURE_KEYS = {
    'chart_selection', 'chart', 'type', 'graph_type', 'plot_type', 'chart_type',
    'visual_family', 'family', 'figure_family', 'figure_families',
    'method_family', 'method_families', 'chart_tags', 'required_structure',
    'required_structures', 'visual_observations', 'visible_layout',
    'scientific_mapping', 'panel_mapping', 'keywords', 'name', 'label', 'id',
    'layout', 'layout_and_export', 'preplot_processing', 'data_shape',
    'geometry', 'archetype',
}
_CONTAINERS = {'learned_contract', 'all_method_records', 'figures', 'figure', 'design_spec',
               'contract', 'visual_contract', 'reference_evidence', 'preparation_request',
               'reference_analysis', 'elements'}
_FIELD_PRIORITY = {key: order for order, key in enumerate((
    'chart_selection', 'chart', 'graph_type', 'plot_type', 'chart_type', 'visual_family',
    'figure_family', 'figure_families', 'family', 'method_family', 'method_families',
    'visual_observations', 'visible_layout', 'name', 'label', 'keywords', 'data_shape',
    'required_structure', 'required_structures', 'layout', 'layout_and_export',
    'preplot_processing', 'scientific_mapping', 'panel_mapping', 'geometry', 'archetype', 'id'))}


def _text_values(value):
    if isinstance(value, str):
        # A path or a URL is not evidence about graphical structure.
        if not value.startswith(('/', '../', './')) and '://' not in value:
            yield value
    elif isinstance(value, list):
        for item in value:
            yield from _text_values(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from _text_values(item)


def _contract_fields(value, prefix='contract'):
    if isinstance(value, list):
        for index, item in enumerate(value):
            yield from _contract_fields(item, f'{prefix}[{index}]')
    elif isinstance(value, dict):
        for key, item in value.items():
            if key in _STRUCTURE_KEYS:
                texts = list(_text_values(item))
                # A keyword list is one documented vocabulary, not unrelated
                # snippets that lose explicit compound shapes on separation.
                if key == 'keywords':
                    texts = [' '.join(texts)] if texts else []
                for text in texts:
                    yield f'{prefix}.{key}', text
            elif key in _CONTAINERS:
                yield from _contract_fields(item, f'{prefix}.{key}')


def _shape_text(text):
    # Parenthetical software names do not define the chart. Explicit graph
    # titles outside the parentheses still do.
    text = re.sub(r'[(（][^()（）]*(?:包|库)[^()（）]*[)）]', '', text)
    # Chart-family umbrellas and graphical auxiliaries are not additional
    # chart types. Keep explicit bubble titles, but not the broad scatter-bubble
    # family; a scale/color bar does not claim a column/bar chart.
    text = re.sub(r'(?<![a-z])scatter[- ]bubble(?![a-z])', 'scatter', text, flags=re.I)
    text = re.sub(r'(?<![a-z])synteny[- ]dotplot(?![a-z])', 'synteny', text, flags=re.I)
    text = re.sub(r'(?<![a-z])(?:scale|colou?r)[- ]bars?(?![a-z])', '', text, flags=re.I)
    return re.sub(r'\bgeom_[a-zA-Z0-9_]+\b', '', text)


def _matches(text):
    text = _shape_text(text)
    matches = []
    for order, (category, pattern) in enumerate(_COMPILED.items()):
        match = pattern.search(text)
        if match:
            matches.append((match.start(), order, category))
    categories = [category for _, _, category in sorted(matches)]
    # Molecular/contact/embedding maps share an English noun with geographical
    # maps. Positive geographical context can still identify a genuine map in
    # a composite; molecular map phrases alone cannot.
    molecular_map = re.search(
        r'(?<![a-z])(?:hi-?c|contact|gene|genome|genomic|expression|surface[- ]protein|'
        r'protein|atac|rna|chromvar|feature|embedding|umap|t[- ]?sne).{0,45}\bmaps?\b|'
        r'\bmaps?\b.{0,45}(?:embedding|umap|t[- ]?sne)', text, re.I)
    geographic = re.search(r'地理|世界地图|中国地图|\b(?:world|geographic|choropleth|'
                          r'countries|country|city|cities|basemap)\b|geo[- ]', text, re.I)
    if molecular_map and not geographic:
        categories = [category for category in categories if category != '28_地理地图']
    return categories


def _deduplicate(values):
    return list(dict.fromkeys(values))


def _sanitize(text):
    text = unicodedata.normalize('NFC', str(text))
    text = re.sub(r'[/\\<>:"|?*\x00-\x1f\x7f]', '_', text)
    text = re.sub(r'\s+', '_', text)
    return re.sub(r'_+', '_', text).strip(' ._')


def _byte_prefix(text, length):
    return text.encode('utf-8')[:max(0, length)].decode('utf-8', errors='ignore').rstrip(' ._')


def _friendly_name(primary, usage, method_id):
    original_id = str(method_id)
    stable_id = _sanitize(original_id) or 'UNNAMED'
    # Illegal-character replacement must not collapse two distinct IDs.
    if re.search(r'[/\\<>:"|?*\x00-\x1f\x7f]', original_id) or len(stable_id.encode('utf-8')) > 90:
        digest = hashlib.sha256(original_id.encode('utf-8')).hexdigest()[:10]
        stable_id = _byte_prefix(stable_id, 78) + '_' + digest
    label = CATEGORY_LABELS[primary]
    clean_usage = _sanitize(usage)
    clean_usage = re.sub(r'^跟着[^_]*?学作图_?', '', clean_usage)
    clean_usage = clean_usage.replace(_sanitize(original_id), '').strip(' ._')
    prefix = _sanitize(label) + '_'
    suffix = '_' + stable_id
    budget = 160 - len((prefix + suffix).encode('utf-8'))
    usage = _byte_prefix(clean_usage, budget)
    return prefix + usage + suffix if usage else prefix + stable_id


def _is_locator_title(text, method_id):
    return (not text or text == method_id or bool(re.fullmatch(
        r'(?:[A-Za-z0-9_-]+\s+)?(?:Figure|Fig\.?|S)\s*\d+[a-zA-Z]?(?:[,;].*)?', text, re.I))
        or text.startswith(('biofigure-case-', 'SCIDRAW-', 'PEARSON-FIG', 'RA-FIG', 'POPULUS-FIG'))
        or bool(re.search(r'(?:\.ya?ml|\.json)$', text, re.I)))


def classify_card(card, entry=None):
    """Return portable category/name metadata without mutating input objects.

    METADATA_CLASSIFIED means a chart shape is explicitly documented. It does
    not establish current asset bytes, source/code pairing or render quality.
    Unspecified charts retain their IDs and enter 99_待分类.
    """
    if not isinstance(card, dict):
        raise TypeError('card must be a dictionary')
    method_id = str(card.get('method_id') or (entry or {}).get('method_id') or 'UNNAMED')
    title = str(card.get('title') or (entry or {}).get('title') or '')
    fields = list(_contract_fields(entry or {}))
    fields.sort(key=lambda pair: _FIELD_PRIORITY.get(pair[0].rsplit('.', 1)[-1], 99))
    contract_name = card.get('contract_name')
    if isinstance(contract_name, str):
        fields.insert(0, ('contract_name', contract_name))
    primary, categories, basis, usage = None, [], '', title
    status = 'METADATA_CLASSIFIED'
    warnings = []

    if card.get('collection_overview') or method_id.startswith('PAPER-'):
        primary = '98_论文与项目总览'
        categories = [primary]
        basis = 'collection_overview or paper-level record; preserved as context'
    elif method_id == 'SCICASE-055':
        # Existing title/image and archived source-code sections disagree.
        # Keep the explicit bubble shape, but never certify a false pairing.
        primary = '97_图码配对待核'
        categories = [primary, '03_气泡图与DotPlot', '02_表达与常规热图']
        basis = 'SCICASE-055: ambiguous source sections; correlation/expression pairing needs review'
        status = 'NEEDS_REVIEW'
        warnings.append('SCICASE-055: correlation/expression source image-code pairing needs review')
    elif method_id in _DIMENSION_NAMES and re.search(r'[一二多]维变量', title):
        primary, curated_categories, usage = _DIMENSION_NAMES[method_id]
        categories = list(curated_categories)
        basis = 'source-specific dimension-title mapping; documented chart family and original title'
    else:
        title_categories = [] if title == method_id else _matches(title)
        documented = [(key, text, _matches(text)) for key, text in fields]
        documented = [(key, text, cats) for key, text, cats in documented if cats]
        if title_categories:
            primary = title_categories[0]
            categories = list(title_categories)
            basis = 'explicit title shape'
        elif documented:
            key, text, cats = documented[0]
            primary = cats[0]
            categories = list(cats)
            basis = f'explicit {key} shape'
            if _is_locator_title(title, method_id):
                usage = next((value for _, value, components in documented
                              if primary in components and value != method_id), text)
        if primary:
            # Contract structure contributes explicitly recorded components,
            # never package/function detections or old broad category tags.
            for _, _, cats in documented:
                categories.extend(cats)
            if method_id in {'SCICASE-007', 'SCICASE-008'}:
                primary = '10_云雨图'
                categories.insert(0, primary)
                basis = 'explicit half-violin/box/point raincloud source layout'
            if primary == '01_相关性图':
                # A correlation matrix is already a matrix presentation; its
                # Heatmap spelling does not create an expression-heatmap claim.
                categories = [c for c in categories if c != '02_表达与常规热图']
            if primary == '28_地理地图' and documented and _is_locator_title(title, method_id):
                usage = documented[0][1]
            # A reviewed visual-family record can conflict with the catalogue
            # heading. Keep both candidates; metadata alone cannot decide which
            # record or asset is wrong (notably ASF-V24).
            visual_families = [(text, cats) for key, text, cats in documented
                               if key.rsplit('.', 1)[-1] == 'visual_family']
            if title_categories and visual_families and all(
                    not set(title_categories).intersection(cats) for _, cats in visual_families):
                status = 'NEEDS_REVIEW'
                basis += '; title/visual_family conflict; original asset and chart type need review'
                warnings.append('title/visual_family conflict: title=' + title +
                                '; visual_family=' + ', '.join(text for text, _ in visual_families) +
                                '; preserve candidates and verify original asset/record before selection')
                usage = '图型待核_' + usage
        else:
            primary = '99_待分类'
            categories = [primary]
            status = 'NEEDS_REVIEW'
            basis = 'no explicit figure-specific chart shape; packages/tags/paths excluded'

    categories = _deduplicate([primary] + categories)
    return {'primary_category': primary, 'categories': categories,
            'display_name': _friendly_name(primary, usage, method_id),
            'classification_basis': basis, 'classification_status': status,
            'classification_warnings': warnings}
