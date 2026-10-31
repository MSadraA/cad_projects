#!/usr/bin/env python3
"""Count elaborated leaf instances, NOT an optimized generic synthesis netlist.

Black boxes deliberately prevent Yosys from removing, merging, or remapping
Actel cells, including cells whose pins happen to be constant.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WEIGHTS = {'c1': 10, 'c2': 11, 's1': 13, 's2': 13}
TOPS = {'fcnn_fp16_adder': 3060, 'fcnn_fp16_multiplier': 5340,
        'ping_pong_buffer': 3540, 'fcnn_ping_pong_buffer': 3540}
STUBS = '''
(* blackbox *) module c1(input A0,A1,SA,B0,B1,SB,S0,S1,output f); endmodule
(* blackbox *) module c2(input D00,D01,D10,D11,A1,B1,A0,B0,output out); endmodule
(* blackbox *) module s1(input D00,D01,D10,D11,A1,B1,A0,clr,clk,output out); endmodule
(* blackbox *) module s2(input D00,D01,D10,D11,A1,B1,A0,B0,clr,clk,output out); endmodule
'''


def count(yosys, top, parameters=None):
    work = ROOT / 'build/count' / top
    work.mkdir(parents=True, exist_ok=True)
    (work/'cells.v').write_text(STUBS)
    sources = [p for p in (ROOT/'rtl/files.f').read_text().splitlines()
               if p != 'rtl/actel/modules.v']
    commands = [f'read_verilog -sv {work.relative_to(ROOT)}/cells.v ' + ' '.join(sources)]
    for name, value in (parameters or {}).items():
        commands.append(f'chparam -set {name} {int(value)} {top}')
    commands += [f'hierarchy -check -top {top}', 'proc', 'flatten',
                 f'write_json {work.relative_to(ROOT)}/netlist.json', 'stat']
    (work/'count.ys').write_text('\n'.join(commands)+'\n')
    proc = subprocess.run([yosys, '-s', str(work/'count.ys')], cwd=ROOT,
                          text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (work/'yosys.log').write_text(proc.stdout)
    if proc.returncode:
        raise RuntimeError(proc.stdout[-5000:])
    module = json.loads((work/'netlist.json').read_text())['modules'][top]
    cells = Counter(c['type'] for c in module.get('cells', {}).values())
    forbidden = set(cells)-set(WEIGHTS)
    if forbidden:
        raise AssertionError(f'Non-Actel leaf cells: {forbidden}')
    total = sum(cells[k]*v for k,v in WEIGHTS.items())
    result = {'top':top, 'parameters':parameters or {}, 'cells':dict(sorted(cells.items())),
              'gates':total, 'limit':TOPS[top], 'within_limit':total<=TOPS[top],
              'method':'unoptimized elaborated Actel leaves; 10*c1+11*c2+13*s1+13*s2'}
    return result


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--yosys',default=shutil.which('yosys'))
    ap.add_argument('--check',action='store_true',help='fail if a phase-1 payload top exceeds its limit')
    args=ap.parse_args()
    if not args.yosys:
        ap.error('Yosys is required for independent elaboration and counting')
    reports=[]
    for top in TOPS:
        result=count(args.yosys,top)
        out=ROOT/'results/gates'/top
        out.mkdir(parents=True,exist_ok=True)
        (out/'gated.txt').write_text(str(result['gates'])+'\n')
        (out/'count.json').write_text(json.dumps(result,indent=2)+'\n')
        reports.append(result)
        print(f"{top}: {result['gates']} / {result['limit']} {result['cells']}")
    (ROOT/'results/gate_counts.json').write_text(json.dumps(reports,indent=2)+'\n')
    if args.check and any(not r['within_limit'] for r in reports[:3]):
        raise SystemExit('Gate limit exceeded')


if __name__=='__main__': main()
