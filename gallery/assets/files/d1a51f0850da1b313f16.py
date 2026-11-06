#!/usr/bin/env python3
"""Fresh BioFigure prepare, authorization and render for three fixed FigureYa inputs."""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
SKILL = ROOT / 'biofigure'


def run(*args, log=None):
    result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True, text=True)
    if log:
        Path(log).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed: {result.stdout[-1500:]} {result.stderr[-1500:]}')
    return result


cases = tuple(sys.argv[1:] or ('lego', 'ternary', 'circvenn'))
assert set(cases) <= {'lego', 'ternary', 'circvenn'}
for case in cases:
    folder = WORK / case
    run(sys.executable, SKILL / 'scripts/prepare_figure.py', folder / 'request.yaml',
        '--output', folder / 'preparation-receipt.json', log=folder / 'prepare-current.log')
    run(sys.executable, WORK / 'prepare_specs.py', case, log=folder / 'spec-current.log')
    spec = folder / 'design-spec.yaml'
    receipt = folder / 'preparation-receipt.json'
    run(sys.executable, SKILL / 'scripts/validate_design_spec.py', spec,
        '--preparation-receipt', receipt, log=folder / 'cp2-current.log')
    module = {'lego': 'FigureYa168legoplot', 'ternary': 'FigureYa64triangle',
              'circvenn': 'FigureYa237circVenn'}[case]
    sources = [ROOT / 'scripts/figureya_gap_20261030.R', SKILL / 'scripts/figure_style.R',
               WORK / module / ('very_easy_input.csv' if case == 'lego' else 'easy_input.csv'),
               WORK / module / {'lego': 'test_legoplot.pdf',
                                 'ternary': 'triangle_directlabels.pdf',
                                 'circvenn': 'Circled_Venn_diagram_ori.pdf'}[case],
               WORK / module / (module + '.Rmd')]
    auth = folder / ('render-authorization-' + str(time.time_ns()) + '.json')
    command = [sys.executable, SKILL / 'scripts/authorize_render.py', '--receipt', receipt,
               '--design-spec', spec]
    for source in sources:
        command.extend(('--source', source))
    run(*command, '--output', auth, log=folder / 'auth-current.log')
    run('Rscript', ROOT / 'scripts/figureya_gap_20261030.R', case, 'formal', auth,
        log=folder / 'formal-current.log')
    print(case, 'rendered')
