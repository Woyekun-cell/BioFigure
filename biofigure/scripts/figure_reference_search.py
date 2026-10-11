#!/usr/bin/env python3
"""Pure, compact figure retrieval. Search never qualifies a renderer or reads assets."""
from __future__ import annotations

import re
from pathlib import PurePosixPath

from figure_library_categories import classify_card


TYPE_ALIASES = {
    'pca': ('pca', 'principal component', '主成分'),
    'pcoa': ('pcoa', 'principal coordinate', '主坐标'),
    'umap': ('umap',), 'tsne': ('tsne', 't-sne'),
    'raincloud': ('raincloud', 'rain cloud', '云雨', '雨云'),
    'violin': ('violin', '小提琴', 'geom_violin'),
    'boxplot': ('boxplot', 'box plot', '箱式', '箱线', 'geom_boxplot'),
    'bubble': ('bubble', 'bubbles', '气泡'),
    'dotplot': ('dotplot', 'dot plot'),
    'heatmap': ('heatmap', '热图', 'complexheatmap', 'geom_tile', 'corrplot'),
    'bar': ('bar', 'barplot', 'bar chart', '柱状', '柱形', '条形', 'geom_bar', 'geom_col'),
    'scatter': ('scatter', '散点'),
    'volcano': ('volcano', '火山'), 'ridge': ('ridge', 'ridgeline', '山脊', '岭线'),
    'sankey': ('sankey', 'alluvial', '桑基', '河流图'),
    'circular': ('circular', 'circos', '环状', '环形'),
    'chord': ('chord', '弦图'), 'network': ('network', '网络'),
    'tree': ('phylogeny', 'phylogenetic', '系统发育'),
    'synteny': ('synteny', '共线'), 'survival': ('survival', 'kaplan-meier', '生存'),
    'swimmer': ('swimmer', '泳道'), 'ternary': ('ternary', '三元'),
    'trajectory': ('trajectory', 'pseudotime', '拟时序', '轨迹'),
    'triangle': ('triangle', 'triangular', '三角'),
    'upper-triangle': ('upper triangle', 'upper-triangle', '上三角'),
    'lower-triangle': ('lower triangle', 'lower-triangle', '下三角'),
}
DOMAIN_ALIASES = {
    'correlation': ('correlation', '相关', 'spearman', 'corrplot'),
    'expression': ('expression', '表达', 'marker expression'),
    'enrichment': ('enrichment', '富集', 'gsea'),
    'pangenome': ('pangenome', 'pan-genome', '泛基因组'),
    'single-cell': ('single-cell', 'single cell', '单细胞'),
    'multi-omics': ('multiomics', 'multi-omics', 'multiomic', '多组学'),
}
SPECIES_ALIASES = {'番茄': 'tomato', '大麦': 'barley', '大麻': 'cannabis'}
# Only semantic fields are admitted. Paths, hashes, URLs, entire contracts,
# arbitrary code, parent resource listings and previous full search_text are not.
SEMANTIC_KEYS = {
    'title', 'name', 'chart_selection', 'project', 'study', 'question', 'intent', 'category', 'keywords',
    'family', 'figure_family', 'figure_families', 'method_family', 'method_families', 'chart', 'chart_tags',
    'domains', 'domain', 'scientific_tasks', 'data_type', 'data_shape', 'unit',
    'required_fields', 'required_structure', 'required_structures', 'input_contract',
    'visual_observations', 'transferable_decisions', 'plot_primitives', 'primitives',
    'packages', 'r_packages', 'core_packages', 'key_functions', 'r_functions',
    'functions', 'plot_packages', 'figure_locator', 'published_reference',
    'advantage_tags', 'layout_tags', 'label', 'id', 'case_id', 'reference',
    'scientific_mapping', 'panel_mapping', 'layout',
}
STRUCTURE_KEYS = {
    'title', 'name', 'chart_selection', 'category', 'family', 'figure_family', 'figure_families', 'method_family', 'method_families',
    'chart', 'chart_tags', 'keywords', 'required_structure', 'required_structures',
    'plot_primitives', 'primitives', 'packages', 'r_packages', 'core_packages',
    'key_functions', 'r_functions', 'functions', 'plot_packages', 'scientific_tasks',
    'panel_mapping', 'layout',
}
DOMAIN_KEYS = {'title', 'name', 'chart_selection', 'category', 'family', 'figure_family', 'figure_families',
               'method_family', 'method_families', 'domains', 'domain', 'scientific_tasks', 'keywords',
               'question', 'intent'}
STOP_WORDS = {
    'plot', 'plots', 'figure', 'figures', 'chart', 'charts', 'make', 'draw', 'nice',
    'samples', 'sample', 'matrix', 'genes', 'gene', 'values', 'value', 'groups',
    'group', 'grouped', 'data', 'with', 'and', 'the', 'for', 'of', 'a', 'in', 'by',
    'from', 'current', 'test', 'unknown', '我要', '一个', '当前', '数据', '请用',
    '请画', '绘制', '作图', '做个', '做一', '图形', '不存在', '存在', '多少',
    '做一个', '我要画', '基因', '样本', '分组', '比较', '能够', '进行',
}
IMAGE_SUFFIXES = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.svg', '.pdf'}
CODE_SUFFIXES = {'.r', '.py', '.rmd', '.ipynb', '.sh', '.jl', '.m'}


def _has(text, alias):
    alias = alias.casefold()
    if re.search(r'[\u4e00-\u9fff]', alias):
        return alias in text
    return bool(re.search(r'(?<![a-z0-9])' + re.escape(alias) + r'(?![a-z0-9])', text))


def _tags(text, aliases):
    text = text.casefold()
    return {tag for tag, words in aliases.items() if any(_has(text, x) for x in words)}


def _values(value):
    """Semantic text values, dropping anything that resembles an asset locator."""
    if isinstance(value, str):
        is_path = (value.startswith(('/', './', '../')) or '\\' in value
                   or re.search(r'\.(?:png|jpe?g|pdf|py|rmd|ipynb|R)\b', value)
                   or ('/' in value and not re.search(r'[\u4e00-\u9fff\s]', value)))
        if '://' not in value and not is_path:
            yield value
    elif isinstance(value, list):
        for item in value:
            yield from _values(item)
    elif isinstance(value, dict):
        for key, item in value.items():
            if key in SEMANTIC_KEYS:
                yield from _values(item)


def _semantic(value, allowed=SEMANTIC_KEYS):
    pieces = []
    if isinstance(value, dict):
        for key, item in value.items():
            if key in allowed:
                if key in {'scientific_mapping', 'panel_mapping', 'layout'} and isinstance(item, dict):
                    for description in item.values():
                        pieces.extend(_values(description))
                elif key == 'reference' and isinstance(item, str) and '/' not in item and '://' not in item:
                    # A documented notebook output title is semantic; its file
                    # extension and cell locator are not search terms.
                    pieces.append(re.sub(r'\.(?:ipynb|png|pdf)\b', '', item, flags=re.I))
                else:
                    pieces.extend(_values(item))
            elif key not in {'parent_source_assets', 'source_assets', 'files', 'search_text', 'material_binding'}:
                if isinstance(item, (dict, list)):
                    pieces.extend(_semantic(item, allowed))
    elif isinstance(value, list):
        for item in value:
            pieces.extend(_semantic(item, allowed))
    return list(dict.fromkeys(pieces))


def _nodes(detail):
    """Figure-specific nodes only; parent_source_assets are whole-paper resources."""
    yield detail
    for key in ('figures', 'all_method_records'):
        for item in detail.get(key, []):
            if isinstance(item, dict):
                yield item


def _assets(entry):
    detail = entry.get('learned_contract', {})
    bound = entry.get('material_binding', {}).get('bound', [])
    by_recorded = {item.get('recorded_path'): item for item in bound if item.get('recorded_path')}
    by_path = {item.get('path'): item for item in bound if item.get('path')}
    images, codes, warnings = [], [], []

    def add(target, value, *, mapping='source-bound-candidate', direct=False, url=None):
        value = {'path': value} if isinstance(value, str) else value
        if not isinstance(value, dict):
            return
        raw = value.get('path') or value.get('local_source') or value.get('local_asset')
        item = by_recorded.get(raw) or by_path.get(raw)
        if not item and raw and direct:
            item = value
        if not item:
            if raw:
                warnings.append('unresolved asset binding: ' + raw)
            return
        asset = {'path': item['path'], 'sha256': item.get('sha256') or value.get('sha256'),
                 'mapping_status': value.get('mapping_status', mapping)}
        for locator in ('start', 'end', 'anchor', 'cell', 'heading'):
            if value.get(locator) is not None:
                asset[locator] = value[locator]
        if url or value.get('source_url'):
            asset['source_url'] = url or value['source_url']
        if asset not in target:
            target.append(asset)
        if 'article-order' in asset['mapping_status']:
            warnings.append('article-order image candidate; exact figure pairing unverified')

    for node in _nodes(detail):
        for key in ('source_reference_images', 'local_reference_images', 'source_image_files', 'source_figures'):
            for value in node.get(key, []):
                add(images, value, direct=key in {'source_reference_images', 'local_reference_images'},
                    mapping='article-order-candidate-unverified' if key == 'source_image_files' else 'source-bound-candidate')
        for key in ('local_reference_image', 'reference', 'source_image', 'source_figure'):
            if node.get(key):
                add(images, node[key], direct=key == 'local_reference_image')
        if node.get('local_asset'):
            add(images, {'path': node['local_asset'], 'sha256': node.get('asset_sha256')},
                url=node.get('asset_url') or node.get('publisher_page'), mapping='figure-level-source-candidate')
        for key in ('source_code_files', 'code_files', 'code_bindings', 'code_locators'):
            for value in node.get(key, []):
                add(codes, value, direct=key == 'source_code_files', mapping='recorded-code-binding')
        for key in ('source_code', 'code_binding'):
            value = node.get(key)
            if isinstance(value, (dict, str)):
                add(codes, value, mapping='recorded-code-binding')
        if node.get('source_path'):
            add(codes, node['source_path'], mapping='recorded-code-binding')
    # SciDraw renderer outputs and comparison sheets are never original figures.
    source_hashes = {image.get('source_image_sha256') for node in _nodes(detail)
                     for image in node.get('validated_pngs', []) if isinstance(image, dict)} - {None}
    for value in detail.get('source_compared_materials', []):
        if value.get('sha256') in source_hashes:
            add(images, value, mapping='source-hash-bound-candidate', direct=True)
    for value in bound:
        if value.get('sha256') in source_hashes:
            add(images, value, mapping='source-hash-bound-candidate', direct=True)
    images = [x for x in images if PurePosixPath(x['path']).suffix.casefold() in IMAGE_SUFFIXES]
    codes = [x for x in codes if PurePosixPath(x['path']).suffix.casefold() in CODE_SUFFIXES]
    return images, codes, warnings


def build_catalog(full_index):
    """Compile one compact card per persisted ID without reading any other file."""
    cards = []
    for entry in full_index['entries']:
        detail = entry.get('learned_contract', {})
        title = str(entry.get('title', ''))
        semantic = ' '.join(dict.fromkeys([title, entry['method_id'], *_semantic(detail)]))
        structure = ' '.join([title, *_semantic(detail, STRUCTURE_KEYS)])
        # A broad family includes alternatives, not every subtype at once.
        # A scatter-bubble family alone cannot prove a size-encoded bubble plot.
        structure = re.sub(r'\bscatter[-_]bubble\b', 'scatter', structure, flags=re.I)
        types = _tags(structure, TYPE_ALIASES)
        domains = _tags(' '.join([title, *_semantic(detail, DOMAIN_KEYS)]), DOMAIN_ALIASES)
        images, codes, warnings = _assets(entry)
        primitives = detail.get('code_analysis', {}).get('plot_primitives', [])
        if 'correlation' in domains and any(x in primitives for x in ('geom_tile', 'Heatmap', 'corrplot')):
            types.add('heatmap')
        # Controlled geometry signals from actually bound method source paths.
        # These labels are not a general path-search corpus.
        for asset in images:
            if asset['mapping_status'] != 'source-hash-bound-candidate':
                continue
            path = asset['path'].casefold().replace('_', ' ').replace('-', ' ')
            if re.search(r'\bbubbles?\b', path):
                types.add('bubble')
            for direction in ('upper', 'lower'):
                if direction + ' triangle' in path:
                    types.update({'triangle', direction + '-triangle'})
        category_domains = _tags(str(detail.get('category', '')), DOMAIN_ALIASES)
        method_domains = set()
        for node in detail.get('all_method_records', []):
            method_domains |= _tags(str(node.get('family', '')), DOMAIN_ALIASES)
        if category_domains and method_domains and not category_domains & method_domains:
            warnings.append('metadata domain conflict: category=' + ','.join(sorted(category_domains))
                            + '; method=' + ','.join(sorted(method_domains)))
        # DotPlot is a matrix of expression/enrichment points, not a volcano
        # scatter merely drawn with geom_point. Do not infer from that geom alone.
        if ('bubble' in types and domains & {'expression', 'enrichment'}
                and not any('conflict' in x for x in warnings)):
            types.add('dotplot')
        if 'dotplot' in types and 'expression' in domains:
            warnings.append('check source size mapping: mean-only expression cannot supply positive-cell fractions')
        if 'bubble' in types and 'correlation' in domains:
            warnings.append('check source size/star mapping: r alone cannot supply abundance or P/q values')
        binding = entry.get('material_binding', {})
        if binding.get('unresolved'):
            warnings.append('unresolved material bindings')
        if binding.get('hash_mismatches'):
            warnings.append('recorded material hash mismatch')
        if detail.get('source_code_gap', 0):
            warnings.append('source code incomplete')
        if detail.get('status') == 'needs_review' or detail.get('note') == 'ambiguous_sections':
            warnings.append('code section ownership needs review: ' + str(detail.get('note') or detail.get('status')))
        if not images:
            warnings.append('no indexed original figure; source lookup required')
        if not codes:
            warnings.append('no figure-level code binding')
        card = {'method_id': entry['method_id'], 'title': title,
                      'contract_name': detail.get('name'),
                      'collection': entry.get('collection', ''), 'semantic_text': semantic[:2400],
                      'domain': sorted(domains), 'type_tags': sorted(types),
                      'source_record': entry.get('source_record'), 'source_images': images,
                      'code_files': codes, 'warnings': list(dict.fromkeys(warnings)),
                      'archive_status': detail.get('status'), 'archive_note': detail.get('note'),
                      'collection_overview': bool(detail.get('plot_recipes') or detail.get('figures')),
                      'validation_status': 'NOT_VERIFIED'}
        card.update(classify_card(card, entry))
        card['warnings'] = list(dict.fromkeys(card.get('classification_warnings', []) + card['warnings']))
        cards.append(card)
    return {'schema_version': 1, 'coverage': full_index.get('coverage', {}), 'cards': cards,
            'boundary': 'Retrieval candidates only; current bytes, source pairing, runtime and new-input rendering are not verified.'}


def _tokens(text):
    text = text.casefold()
    english = re.findall(r'[a-z0-9]+(?:[_.+][a-z0-9]+)*', text)
    chinese = re.findall(r'[\u4e00-\u9fff]{2,}', text)
    tokens = set(english)
    for phrase in chinese:
        for stop in sorted(STOP_WORDS, key=len, reverse=True):
            if re.search(r'[\u4e00-\u9fff]', stop):
                phrase = phrase.replace(stop, ' ')
        for part in phrase.split():
            tokens.add(part)
            tokens.update(part[i:i+n] for n in (2, 3, 4) for i in range(len(part)-n+1))
    return tokens - STOP_WORDS


def rank_catalog(catalog, query, limit=3, case_id=None):
    """Rank compatible cards; exact English words and controlled bilingual tags."""
    if limit < 1:
        raise ValueError('limit must be positive')
    cards = catalog['cards']
    if case_id:
        matching = [c for c in cards if c['method_id'] == case_id]
        if not matching:
            raise ValueError('unknown learned method ID: ' + str(case_id))
        return [dict(matching[0], score=10000, match_reasons=['explicit_method_id'])]
    query = str(query).casefold()
    direct_id = [c for c in cards if c['method_id'].casefold() == query.strip()]
    if direct_id:
        return [dict(direct_id[0], score=10000, match_reasons=['exact_method_id'])]
    wanted_types = _tags(query, TYPE_ALIASES)
    wanted_domains = _tags(query, DOMAIN_ALIASES)
    tokens = _tokens(query)
    species = {english for chinese, english in SPECIES_ALIASES.items() if chinese in query}
    tokens |= species
    alias_tokens = _tokens(' '.join(word for tag in wanted_types for word in TYPE_ALIASES[tag])
                           + ' ' + ' '.join(word for tag in wanted_domains for word in DOMAIN_ALIASES[tag]))
    if not tokens and not wanted_types and not wanted_domains:
        return []
    ranked = []
    for card in cards:
        types, domains = set(card['type_tags']), set(card['domain'])
        if wanted_types and not wanted_types.issubset(types):
            continue
        if wanted_domains & {'correlation', 'expression', 'enrichment'}:
            specific = wanted_domains & {'correlation', 'expression', 'enrichment'}
            if not specific & domains:
                continue
        if ('upper-triangle' in wanted_types and 'lower-triangle' in types and 'upper-triangle' not in types
                or 'lower-triangle' in wanted_types and 'upper-triangle' in types and 'lower-triangle' not in types):
            continue
        text_tokens, title_tokens = _tokens(card['semantic_text']), _tokens(card['title'])
        if species and not species & text_tokens:
            continue
        overlap = tokens & text_tokens
        type_overlap, domain_overlap = wanted_types & types, wanted_domains & domains
        if not overlap and not type_overlap and not domain_overlap:
            continue
        score = sum(8 if t in title_tokens else 2 for t in overlap - alias_tokens)
        score += 32 * len(type_overlap) + 28 * len(domain_overlap)
        score -= 18 * len(wanted_types - types)
        reasons = ([f'type:{x}' for x in sorted(type_overlap)]
                   + [f'domain:{x}' for x in sorted(domain_overlap)]
                   + [f'term:{x}' for x in sorted(overlap)])
        if score <= 0:
            continue
        # Evidence quality only breaks comparable semantic relevance. It cannot
        # make an unrelated source win, and it never promotes NOT_VERIFIED.
        quality = (2 * bool(card['source_images']) + bool(card['code_files'])
                   - 4 * any('conflict' in x or 'mismatch' in x for x in card['warnings']))
        if ({'triangle', 'heatmap'} <= wanted_types and 'correlation' in wanted_domains
                and not wanted_types & {'upper-triangle', 'lower-triangle'}
                and 'upper-triangle' in types):
            quality += 1
            reasons.append('bound_upper_triangle_source_candidate')
        ranked.append((score, quality, card['method_id'], dict(card, score=score, match_reasons=reasons)))
    if wanted_types:
        focused_sources = {item[3]['source_record'] for item in ranked if not item[3].get('collection_overview')}
        ranked = [item for item in ranked if not (item[3].get('collection_overview')
                  and item[3]['source_record'] in focused_sources)]
    ranked.sort(key=lambda x: (-x[0], -x[1], x[2]))
    return [item[3] for item in ranked[:limit]]
