#!/usr/bin/env python3
"""Strict portable regression runner. Python 3.10+, Icarus 11+."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]


def run(command,log,timeout=1800):
    before=time.monotonic()
    p=subprocess.run([str(x) for x in command],cwd=ROOT,text=True,
                     stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    log.parent.mkdir(parents=True,exist_ok=True)
    log.write_text(p.stdout)
    if p.returncode:
        raise RuntimeError(f'{command[0]} failed ({p.returncode}):\n{p.stdout[-6000:]}')
    return p.stdout,round(time.monotonic()-before,3)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--sim',choices=['icarus'],default='icarus')
    ap.add_argument('--quick',action='store_true')
    ap.add_argument('--groups',default='cells,helpers,fp,buffer')
    ap.add_argument('--wave',action='store_true',help='Icarus waveform output; use --quick to bound file sizes')
    args=ap.parse_args()
    groups=set(args.groups.split(','))
    if groups-{'cells','helpers','fp','buffer'}: ap.error('Unknown test group')
    build=ROOT/'build'/args.sim
    build.mkdir(parents=True,exist_ok=True)
    result_dir=ROOT/'results'/args.sim
    result_dir.mkdir(parents=True,exist_ok=True)
    if 'fp' in groups:
        run([sys.executable,'scripts/generate_vectors.py']+(['--quick'] if args.quick else []),build/'generate.log')
    sources=(ROOT/'rtl/files.f').read_text().splitlines()
    jobs=[]
    if 'cells' in groups: jobs.append(('tb_actel_cells',[],{},'[PASS] ACTEL_CELLS'))
    if 'helpers' in groups: jobs.append(('tb_building_blocks',[],{},'[PASS] BUILDING_BLOCKS'))
    if 'fp' in groups:
        jobs.extend([('tb_fp16_adder',[],{},'[PASS] ADD'),('tb_fp16_multiplier',[],{},'[PASS] MUL')])
    if 'buffer' in groups:
        for lanes,dest in [(1,1),(2,1),(3,2),(5,3),(7,4),(8,4),(9,5)]:
            jobs.append(('tb_ping_pong_buffer',['tb/ca1_ping_pong_reference.v'],
                         {'LANES':lanes,'DEST_W':dest},'[PASS] PINGPONG'))
    results=[]
    for top,extra,params,marker in jobs:
        label=top+''.join(f'_{k}{v}' for k,v in params.items())
        if args.sim=='icarus':
            compiler=os.environ.get('IVERILOG') or shutil.which('iverilog')
            runtime=os.environ.get('VVP') or shutil.which('vvp')
            if not compiler or not runtime: ap.error('Icarus (iverilog and vvp) is required')
            cmd=[compiler]
            if os.environ.get('IVERILOG_BASE'): cmd+=['-B',os.environ['IVERILOG_BASE']]
            cmd+=['-g2012','-Wall','-s',top,'-o',build/(label+'.vvp')]
            cmd += [f'-P{top}.{k}={v}' for k,v in params.items()]
            cmd += sources+extra+[f'tb/{top}.sv']
            _,compile_seconds=run(cmd,result_dir/(label+'_compile.log'))
            output,seconds=run([runtime,build/(label+'.vvp')]+(['+wave'] if args.wave else []),result_dir/(label+'.log'))
        if marker not in output or '[FAIL]' in output or 'FATAL' in output:
            raise AssertionError(f'Missing PASS / failed assertions in {label}: {output[-2000:]}')
        item={'test':label,'parameters':params,'pass':True,'seconds':seconds,
              'compile_seconds':compile_seconds,'summary':[x for x in output.splitlines() if '[PASS]' in x]}
        results.append(item)
        print(item['summary'][0],flush=True)
        (result_dir/'regression.json').write_text(json.dumps({'simulator':args.sim,'quick':args.quick,'results':results},indent=2)+'\n')
    files=sources+sorted(str(p.relative_to(ROOT)) for p in (ROOT/'tb').glob('*.sv'))+['tb/ca1_ping_pong_reference.v']
    hashes={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files}
    (result_dir/'source_sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
    print(f'PASS: {len(results)} test configurations ({args.sim})')


if __name__=='__main__': main()
