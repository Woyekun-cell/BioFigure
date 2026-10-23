#!/usr/bin/env python3
"""Build paginated GitHub gallery documents from the checked-in image inventory."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE_SIZE = 8

# Public presentation copy is kept separate from provenance and validation records.
DISPLAY_CAPTIONS = {
    'BF-0055': '相关矩阵与 Mantel 网络 · vegan 示例数据 / Correlation matrix and Mantel network · vegan example data。',
    'BF-0082': '环形热图与 UpSet 组合：在同一版面中连接多层注释、表达模式与集合交集。<br>Circular heatmap and UpSet: layered annotations, expression patterns and set intersections in one layout.',
    'BF-0109': 'DNA、RNA 与蛋白状态的完整路径，在一张桑基图中串联呈现。',
    'BF-0132': '以 GADM 边界为底图，组合模拟采样点与组成饼图。',
    'BF-0146': '多事件突变景观示例：12 个基因、144 个样本，在三块对齐方格矩阵中呈现。',
    'BF-0217': '基于原作者公开处理数据重绘，展示 BUSCO 锚定的基因区域比较。',
    'BF-0218': '基于原作者公开处理坐标重绘，串联 BUSCO 路径与 CBDAS 位点。',
    'BF-0221': 'OHCA 书籍案例重绘：Micro-C 接触矩阵与环标记。<br>A redraw of the OHCA book example: Micro-C contact matrix and loop annotations.',
    'BF-0222': '基于原作者公开处理坐标重绘，以四染色体单倍型点阵呈现序列比对关系。',
}


def display_caption(row):
    if row['id'] in DISPLAY_CAPTIONS:
        return DISPLAY_CAPTIONS[row['id']]
    if row['data_origin'] == 'public-data':
        return f'{row["subtype"]}：公开数据可视化示例。'
    return f'{row["subtype"]}绘图示例。'


def display_order(row):
    return (row['data_origin'] != 'public-author-processed', row['historical'], row['id'])


FEATURED_CASES = [
    ('BF-0082', '环形热图 × UpSet', 'Circular heatmap × UpSet',
     '把多层注释、表达模式和集合交集放到一起，展示复杂信息如何在一张图里有条理地展开。',
     'Layered annotations, expression patterns and set intersections, composed as one connected figure.'),
    ('BF-0217', 'BUSCO 锚定的基因区域比较', 'BUSCO-anchored genomic comparison',
     '基于原作者公开处理数据重绘，把跨基因组的区域结构与合酶位点放到同一视野。',
     'A redraw from publicly released author-processed data, aligning genomic regions and synthase loci.'),
    ('BF-0221', 'Micro-C 接触矩阵与环标记', 'Micro-C contact map and loops',
     'OHCA 书籍案例重绘，将公开数据的接触矩阵与环标记组合展示。',
     'A redraw of the OHCA book example, combining a Micro-C contact matrix with loop annotations.'),
    ('BF-0055', '相关矩阵与 Mantel 网络', 'Correlation matrix and Mantel network',
     '使用 vegan 示例数据，将环境变量相关矩阵与 Mantel 检验网络连接起来。',
     'Using vegan example data to connect an environmental correlation matrix with a Mantel-test network.'),
]
DISPLAY_SOURCES = {
    'BF-0055': 'https://github.com/vegandevs/vegan/blob/master/man/varechem.Rd',
    'BF-0221': 'https://js2264.github.io/OHCA/devel/pages/topological-features.html',
}


def featured_section(figures, destinations, english=False):
    by_id = {row['id']: row for row in figures}
    heading = 'Featured figures' if english else '精选作品'
    intro = ('A few examples of the layouts I work on: dense annotations, genomic comparisons and connected statistical views. Follow the case links for the source and rendering workflow.'
             if english else
             '挑几张我在做的复杂图放在这里：多层注释、基因组比较，以及把多种统计信息接起来的组合图。每张都附了案例与代码入口，方便继续看细节。')
    lines = [f'## {heading}\n', intro + '\n']
    for ident, title_zh, title_en, caption_zh, caption_en in FEATURED_CASES:
        row = by_id[ident]
        title = title_en if english else title_zh
        caption = caption_en if english else caption_zh
        lines += [f'### {title}\n', caption + '\n', f'![{title}]({row["image"]})\n']
        links = [f'[{"Case" if english else "案例详情"}](docs/gallery/{destinations[ident]})']
        if row['scripts']:
            script_path = row['scripts'][0] if len(row['scripts']) == 1 else str(Path(row['scripts'][0]).parent)
            if ident == 'BF-0082':
                script_path = 'biofigure/examples/archive-gallery/scidraw-001-065/scripts/render_cases_10_14.R'
            links.append(f'[{"Code" if english else "绘图代码"}]({script_path})')
        if row.get('provenance'):
            links.append(f'[{"Source notes" if english else "来源说明"}]({row["provenance"]})')
        source = DISPLAY_SOURCES.get(ident, row.get('source_url'))
        if source:
            label = ('Example data' if english else '示例数据') if ident == 'BF-0055' else ('Reference' if english else '参考来源')
            links.append(f'[{label}]({source})')
        lines.append(' · '.join(links) + '\n')
    portable_label = 'Seven compact examples with inputs and PNG/PDF exports' if english else '7 个含输入与 PNG/PDF 的便携绘图案例'
    lines.append(f'[{portable_label}](biofigure/examples/portable)\n')
    return '\n'.join(lines) + '\n'


def replace_showcase(text, section, english=False):
    featured = '## Featured figures' if english else '## 精选作品'
    gallery = '## Gallery by plot type' if english else '## 分类图廊'
    areas = '## Research areas and plot types' if english else '## 适用领域与图型'
    methods = '## Methods and quality checks' if english else '## 绘图方法'
    if featured in text:
        start, end = text.index(featured), text.index(areas)
        text = text[:start] + text[end:]
    if gallery in text:
        start, end = text.index(gallery), text.index(methods)
        text = text[:start] + text[end:]
    location = text.index(areas)
    return text[:location] + section + text[location:]

def page_name(slug, number):
    return f'{slug}.md' if number == 1 else f'{slug}-{number}.md'


def generate():
    catalog = json.loads((ROOT / 'docs/gallery/catalog.json').read_text(encoding='utf-8'))
    figures = catalog['figures']
    categories = catalog['categories']
    ids, images, subtypes = set(), set(), set()
    for row in figures:
        assert row['id'] not in ids and row['image'] not in images, row['id']
        ids.add(row['id']); images.add(row['image'])
        subtype = (row['category'], row['subtype'])
        assert subtype not in subtypes, f'Duplicate visual subtype: {subtype}'
        subtypes.add(subtype)
        assert row['category'] in {c['slug'] for c in categories}, row['id']
        assert hashlib.sha256((ROOT / row['image']).read_bytes()).hexdigest() == row['sha256'], row['id']
        for script in row['scripts']:
            assert (ROOT / script).is_file(), script
        for key in ('pdf', 'provenance'):
            if row.get(key):
                assert (ROOT / row[key]).is_file(), row[key]
        for data_file in row.get('plot_data', []):
            assert (ROOT / data_file).is_file(), data_file
    asset_paths = {str(p.relative_to(ROOT)) for p in (ROOT / 'docs/assets').rglob('*.png')}
    assert images == asset_paths, f'Unlisted/missing images: {images ^ asset_paths}'
    files = {}
    total = len(figures)
    nav_rows = []
    destinations = {}
    for category in categories:
        slug = category['slug']
        rows = sorted((r for r in figures if r['category'] == slug), key=display_order)
        pages = math.ceil(len(rows) / PAGE_SIZE)
        nav_rows.append((category, len(rows), pages))
        for i, row in enumerate(rows):
            destinations[row['id']] = f'{page_name(slug, i // PAGE_SIZE + 1)}#{row["id"].lower()}'
    for category, count, pages in nav_rows:
        slug = category['slug']
        rows = sorted((r for r in figures if r['category'] == slug), key=display_order)
        for number in range(1, pages + 1):
            paging = ' · '.join(f'**{n}**' if n == number else f'[{n}]({page_name(slug, n)})' for n in range(1, pages + 1))
            body = [f'# {category["title"]} / {category["english"]}\n',
                    '[全部分类 / Categories](../GALLERY.md) · [首页 / Home](../../README.md) · [逐图清单 / Inventory](catalog.csv)\n',
                    f'本类 **{count} 张代表图**，每个细分图型保留一例。\n',
                    '按图形结构与科研用途浏览，每个细分图型选一张代表图；点击图片下方的来源与代码，继续探索绘图过程。<br>Explore one example per visual subtype, with source and code links for a closer look at the workflow.\n']
            for row in rows[(number - 1) * PAGE_SIZE:number * PAGE_SIZE]:
                ident = row['id']
                body.append(f'<a id="{ident.lower()}"></a>\n')
                if row['historical']:
                    body.append(f'<details>\n<summary>{ident} · {row["title"]}（历史存档，点击展开）</summary>\n')
                body.append(f'## {ident} · {row["title"]}\n')
                body.append(display_caption(row) + '\n')
                if row.get('superseded_by'):
                    newer = row['superseded_by']
                    body.append(f'[查看当前修订版 {newer}]({destinations[newer]})\n')
                body.append(f'![{ident} {row["title"]}](../../{row["image"]})\n')
                links = [f'[原尺寸](../../{row["image"]})']
                if row.get('pdf'):
                    links.append(f'[PDF](../../{row["pdf"]})')
                if len(row['scripts']) == 1:
                    links.append(f'[脚本](../../{row["scripts"][0]})')
                elif row['scripts']:
                    parent = str(Path(row['scripts'][0]).parent)
                    links.append(f'[批次脚本](../../{parent})')
                if row.get('plot_data'):
                    parent = str(Path(row['plot_data'][0]).parent)
                    links.append(f'[绘图数据](../../{parent})')
                if row.get('provenance'):
                    links.append(f'[来源说明 / Source notes](../../{row["provenance"]})')
                source = DISPLAY_SOURCES.get(ident, row.get('source_url'))
                if source:
                    label = '示例数据 / Example data' if ident == 'BF-0055' else '参考来源 / Reference'
                    links.append(f'[{label}]({source})')
                links.append('[案例记录 / Details](catalog.csv)')
                body.append(' · '.join(links) + '\n')
                if row['historical']:
                    body.append('</details>\n')
            body.append((f'页码：{paging}\n\n' if pages > 1 else '') + '[全部分类](../GALLERY.md) · [脚本存档说明](../../biofigure/examples/archive-gallery/README.md)\n')
            files[f'docs/gallery/{page_name(slug, number)}'] = '\n'.join(body)
    heading = f'**{len(categories)} 类、{total} 张**'
    index = ['# BioFigure 分类代表图库 / Curated gallery\n', '[返回首页 / Home](../README.md) · [逐图清单 CSV](gallery/catalog.csv) · [完整来源记录 JSON](gallery/catalog.json)\n',
             f'精选 {heading}，每个细分图型保留一个代表。点击类别即可查看对应图片。<br>Browse {total} representative figures in {len(categories)} categories, with one example per visual subtype.\n',
             '从多组学、基因组到统计图与多面板组合，按图形结构和科研用途整理。每类选取不同的表达方式，方便从研究问题找到合适的图。<br>From multi-omics and genomics to statistics and multi-panel layouts, the gallery is organized around the questions a figure helps explain.\n',
             '每张图都连接相应代码、数据或参考来源；作者数据重绘案例保留原研究和教程入口。<br>Follow the links beneath each figure for code, data, and the original study or tutorial behind redraw examples.\n',
             '| 分类 / Category | 代表图数 |\n|---|---:|']
    for cat, count, pages in nav_rows:
        index.append(f'| [{cat["title"]} / {cat["english"]}](gallery/{cat["slug"]}.md) | {count} |')
    index.append('\n[来源与权利](../NOTICE.md) · [复现与脚本存档](../biofigure/examples/archive-gallery/README.md) · [成图检查流程](../biofigure/references/benchmark-protocol.md)\n')
    files['docs/GALLERY.md'] = '\n'.join(index)
    readme = (ROOT / 'README.md').read_text(encoding='utf-8')
    section = ['## 分类图廊\n',
               f'现有成图中精选 {heading}。同一细分图型只展示一张代表图，去除重复配色、数据集及历史版本；点击分类查看。\n',
               '从图形结构和科研用途出发挑选案例，附上代码、数据与参考来源，方便继续修改和复用。\n',
               '| 图型分类 | 图数 |\n|---|---:|']
    for cat, count, _ in nav_rows:
        section.append(f'| [{cat["title"]}](docs/gallery/{cat["slug"]}.md) | {count} |')
    section.append('\n[完整分类目录](docs/GALLERY.md) · [逐图清单与文件哈希](docs/gallery/catalog.csv)。复合图只归入一个主要类别，同类变体不重复展示。\n\n')
    showcase = featured_section(figures, destinations) + '\n'.join(section)
    files['README.md'] = replace_showcase(readme, showcase)
    english = (ROOT / 'README.en.md').read_text(encoding='utf-8')
    section_en = ['## Gallery by plot type\n',
                  f'The gallery selects **{total} figures in {len(categories)} categories**. Each visual subtype appears once; color-only, dataset-only and historical variants are omitted.\n',
                  'Explore the visual approach, then follow the code, data and source links to adapt a figure for your own work.\n',
                  '| Category | Figures |\n|---|---:|']
    for cat, count, _ in nav_rows:
        section_en.append(f'| [{cat["english"]}](docs/gallery/{cat["slug"]}.md) | {count} |')
    section_en.append('\nSee the [complete gallery index](docs/GALLERY.md) and [per-figure inventory](docs/gallery/catalog.csv). Composite figures appear in one primary category.\n\n')
    showcase_en = featured_section(figures, destinations, english=True) + '\n'.join(section_en)
    files['README.en.md'] = replace_showcase(english, showcase_en, english=True)
    fields = ['id', 'category', 'subtype', 'title', 'image', 'pdf', 'sha256', 'data_origin', 'historical', 'validation', 'note', 'origin_paths', 'scripts', 'plot_data', 'provenance']
    out = io.StringIO(newline='')
    writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    for row in figures:
        writer.writerow({key: ' | '.join(row.get(key, [])) if isinstance(row.get(key), list) else row.get(key, '') for key in fields})
    files['docs/gallery/catalog.csv'] = out.getvalue()
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify inventory hashes and generated documents without writing.')
    args = parser.parse_args()
    files = generate()
    for name, content in files.items():
        path = ROOT / name
        if args.check:
            assert path.is_file() and path.read_bytes() == content.encode(), f'Stale document: {name}'
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.encode())
    print(f'GALLERY_OK: {len(files)} documents, all inventory hashes and image coverage checked.')


if __name__ == '__main__':
    main()

