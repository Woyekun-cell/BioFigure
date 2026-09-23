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


def page_name(slug, number):
    return f'{slug}.md' if number == 1 else f'{slug}-{number}.md'


def generate():
    catalog = json.loads((ROOT / 'docs/gallery/catalog.json').read_text())
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
    asset_paths = {str(p.relative_to(ROOT)) for p in (ROOT / 'docs/assets').rglob('*.png')}
    assert images == asset_paths, f'Unlisted/missing images: {images ^ asset_paths}'
    files = {}
    total = len(figures)
    nav_rows = []
    destinations = {}
    for category in categories:
        slug = category['slug']
        rows = sorted((r for r in figures if r['category'] == slug), key=lambda r: (r['historical'], r['id']))
        pages = math.ceil(len(rows) / PAGE_SIZE)
        nav_rows.append((category, len(rows), pages))
        for i, row in enumerate(rows):
            destinations[row['id']] = f'{page_name(slug, i // PAGE_SIZE + 1)}#{row["id"].lower()}'
    for category, count, pages in nav_rows:
        slug = category['slug']
        rows = sorted((r for r in figures if r['category'] == slug), key=lambda r: (r['historical'], r['id']))
        for number in range(1, pages + 1):
            paging = ' · '.join(f'**{n}**' if n == number else f'[{n}]({page_name(slug, n)})' for n in range(1, pages + 1))
            body = [f'# {category["title"]} / {category["english"]}\n',
                    '[全部分类 / Categories](../GALLERY.md) · [首页 / Home](../../README.md) · [逐图清单 / Inventory](catalog.csv)\n',
                    f'本类 **{count} 张代表图**，每个细分图型保留一例。\n',
                    '按结构与用途选取代表图，去除同类配色、数据集及历史变体。数据来源逐图标注；收录不等于完整 CP 验收。<br>One representative per visual subtype; color-only, dataset-only and historical variants are omitted. Inclusion does not certify scientific fidelity.\n']
            for row in rows[(number - 1) * PAGE_SIZE:number * PAGE_SIZE]:
                ident = row['id']
                body.append(f'<a id="{ident.lower()}"></a>\n')
                if row['historical']:
                    body.append(f'<details>\n<summary>{ident} · {row["title"]}（历史存档，点击展开）</summary>\n')
                body.append(f'## {ident} · {row["title"]}\n')
                body.append(f'图型：{row["subtype"]}。' + row['note'] + '\n')
                if row['validation'].startswith('needs-revision'):
                    body.append('状态：方法展示／仍待修订，不能视为高保真验收通过。\n')
                if row.get('superseded_by'):
                    newer = row['superseded_by']
                    body.append(f'[查看当前修订版 {newer}]({destinations[newer]})\n')
                body.append(f'![{ident} {row["title"]}](../../{row["image"]})\n')
                links = [f'[原尺寸](../../{row["image"]})']
                if len(row['scripts']) == 1:
                    links.append(f'[脚本](../../{row["scripts"][0]})')
                elif row['scripts']:
                    parent = str(Path(row['scripts'][0]).parent)
                    links.append(f'[批次脚本](../../{parent})')
                if row.get('source_url'):
                    links.append(f'[方法来源]({row["source_url"]})')
                links.append('[记录](catalog.csv)')
                body.append(' · '.join(links) + '\n')
                if row['historical']:
                    body.append('</details>\n')
            body.append((f'页码：{paging}\n\n' if pages > 1 else '') + '[全部分类](../GALLERY.md) · [脚本存档说明](../../biofigure/examples/archive-gallery/README.md)\n')
            files[f'docs/gallery/{page_name(slug, number)}'] = '\n'.join(body)
    heading = f'**{len(categories)} 类、{total} 张**'
    index = ['# BioFigure 分类代表图库 / Curated gallery\n', '[返回首页 / Home](../README.md) · [逐图清单 CSV](gallery/catalog.csv) · [完整来源记录 JSON](gallery/catalog.json)\n',
             f'精选 {heading}，每个细分图型保留一个代表。点击类别即可查看对应图片。<br>Browse {total} representative figures in {len(categories)} categories, with one example per visual subtype.\n',
             '从216张本地成图中按图形结构与用途筛选，移除同图型的配色、数据集、批次和历史修订变体；保留有实质差异的子类型。本地原始成果与脚本保留。\n',
             '包含模拟数据、公开数据分析与软件包示例，各图分别注明。展示不代表完整验收；待修订案例保留状态。第三方参考原图、对照拼图、网页截图、调试首稿及纯技术测试图不列入。\n',
             '| 分类 / Category | 代表图数 |\n|---|---:|']
    for cat, count, pages in nav_rows:
        index.append(f'| [{cat["title"]} / {cat["english"]}](gallery/{cat["slug"]}.md) | {count} |')
    index.append('\n[来源与权利](../NOTICE.md) · [脚本存档与复现边界](../biofigure/examples/archive-gallery/README.md) · [验收规则](../biofigure/references/benchmark-protocol.md)\n')
    files['docs/GALLERY.md'] = '\n'.join(index)
    readme = (ROOT / 'README.md').read_text()
    start, end = readme.index('## 分类图廊'), readme.index('## 绘图方法')
    section = ['## 分类图廊 / Gallery by plot type\n',
               f'从216张本地成图中精选 {heading}。同一细分图型只展示一张代表图，去除重复配色、数据集及历史版本；点击分类查看。<br>Selected {total} representatives from 216 local figures across {len(categories)} categories. Each visual subtype appears once; color-only, dataset-only and historical variants are omitted.\n',
               '数据来源包括模拟数据、公开数据和软件包示例，逐图标注。收录不等于原论文数据复现或完整验收。<br>Each figure states whether it uses simulated, public or package-example data. Inclusion does not certify reproduction of original research findings.\n',
               '| 图型分类 / Category | 图数 / Figures |\n|---|---:|']
    for cat, count, _ in nav_rows:
        section.append(f'| [{cat["title"]} / {cat["english"]}](docs/gallery/{cat["slug"]}.md) | {count} |')
    section.append('\n[完整分类目录](docs/GALLERY.md) · [逐图清单与文件哈希](docs/gallery/catalog.csv)。复合图只归入一个主要类别，同类变体不重复展示。\n\n')
    files['README.md'] = readme[:start] + '\n'.join(section) + readme[end:]
    fields = ['id', 'category', 'subtype', 'title', 'image', 'sha256', 'data_origin', 'historical', 'validation', 'note', 'origin_paths', 'scripts']
    out = io.StringIO(newline='')
    writer = csv.DictWriter(out, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    for row in figures:
        writer.writerow({key: ' | '.join(row[key]) if isinstance(row[key], list) else row[key] for key in fields})
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
