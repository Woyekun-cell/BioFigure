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
    ids, images = set(), set()
    for row in figures:
        assert row['id'] not in ids and row['image'] not in images, row['id']
        ids.add(row['id']); images.add(row['image'])
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
                    f'本类 **{count} 张**；第 **{number}/{pages} 页**。页码：{paging}\n',
                    '图型与数据来源分别标注；旧版折叠保留。收录不等于原论文数据复现或完整 CP 验收。<br>Data origin is stated per figure. Historical versions are folded. Inclusion does not certify scientific fidelity.\n']
            for row in rows[(number - 1) * PAGE_SIZE:number * PAGE_SIZE]:
                ident = row['id']
                body.append(f'<a id="{ident.lower()}"></a>\n')
                if row['historical']:
                    body.append(f'<details>\n<summary>{ident} · {row["title"]}（历史存档，点击展开）</summary>\n')
                body.append(f'## {ident} · {row["title"]}\n')
                body.append(row['note'] + '\n')
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
            body.append(f'页码：{paging}\n\n[全部分类](../GALLERY.md) · [脚本存档说明](../../biofigure/examples/archive-gallery/README.md)\n')
            files[f'docs/gallery/{page_name(slug, number)}'] = '\n'.join(body)
    heading = f'**{len(categories)} 类、{total} 张**'
    index = ['# BioFigure 全量分类图廊 / Complete gallery\n', '[返回首页 / Home](../README.md) · [逐图清单 CSV](gallery/catalog.csv) · [完整来源记录 JSON](gallery/catalog.json)\n',
             f'当前收录 {heading}，按图型浏览；点击类别后显示该类图片，较大类别分页，每页最多 {PAGE_SIZE} 张。<br>Browse {total} figures in {len(categories)} categories, with up to {PAGE_SIZE} images per page.\n',
             '范围：本地项目的已有自行成图，包括 benchmark 工作目录及维护示例。相同字节文件只计一次；配色、布局及修订变体分别计数，因此张数不等于独立方法数。历史版本折叠展示。\n',
             '包含模拟数据、公开数据分析与软件包示例，各图分别注明。展示不代表完整验收；待修订案例保留状态。第三方参考原图、对照拼图、网页截图、调试首稿及纯技术测试图不列入。\n',
             '| 分类 / Category | 图数 | 页数 |\n|---|---:|---:|']
    for cat, count, pages in nav_rows:
        index.append(f'| [{cat["title"]} / {cat["english"]}](gallery/{cat["slug"]}.md) | {count} | {pages} |')
    index.append('\n[来源与权利](../NOTICE.md) · [脚本存档与复现边界](../biofigure/examples/archive-gallery/README.md) · [验收规则](../biofigure/references/benchmark-protocol.md)\n')
    files['docs/GALLERY.md'] = '\n'.join(index)
    readme = (ROOT / 'README.md').read_text()
    start, end = readme.index('## 分类图廊'), readme.index('## 绘图方法')
    section = ['## 分类图廊 / Gallery by plot type\n',
               f'完整收录本地已有科研成图 {heading}。点击分类查看对应图片，较大类别分页；历史修订版折叠保留。<br>All {total} inventoried scientific figures are organized into {len(categories)} categories. Click a category to browse; historical versions remain available in folded sections.\n',
               '数据来源包括模拟数据、公开数据和软件包示例，逐图标注。收录不等于原论文数据复现或完整验收。<br>Each figure states whether it uses simulated, public or package-example data. Inclusion does not certify reproduction of original research findings.\n',
               '| 图型分类 / Category | 图数 / Figures |\n|---|---:|']
    for cat, count, _ in nav_rows:
        section.append(f'| [{cat["title"]} / {cat["english"]}](docs/gallery/{cat["slug"]}.md) | {count} |')
    section.append('\n[完整分类目录](docs/GALLERY.md) · [逐图清单与文件哈希](docs/gallery/catalog.csv)。复合图只归入一个主要类别，变体分别计数。\n\n')
    files['README.md'] = readme[:start] + '\n'.join(section) + readme[end:]
    fields = ['id', 'category', 'title', 'image', 'sha256', 'data_origin', 'historical', 'validation', 'note', 'origin_paths', 'scripts']
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
