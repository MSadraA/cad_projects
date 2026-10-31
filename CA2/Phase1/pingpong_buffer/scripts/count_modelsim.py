#!/usr/bin/env python3
"""Reproduce the TA runtime counter, with exactly one DUT per run.

Requires g++ and ModelSim/Questa in PATH. Icarus has no $system support.
The default regression has two arithmetic DUTs and must NOT be used for counts.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]


def main():
    for tool in ('g++','vlib','vlog','vsim'):
        if not shutil.which(tool): raise SystemExit(f'Required tool missing: {tool}')
    sources=[ROOT/p for p in (ROOT/'rtl/files.f').read_text().splitlines()]
    reports=[]
    for top in ('fcnn_fp16_adder','fcnn_fp16_multiplier','ping_pong_buffer','fcnn_ping_pong_buffer'):
        work=ROOT/'build/native_count'/top
        work.mkdir(parents=True,exist_ok=True)
        for executable,weight in (('c1.exe',10),('c2.exe',11),('s2-s1.exe',13)):
            subprocess.run(['g++','-std=c++11',f'-DGATE_WEIGHT={weight}',str(ROOT/'scripts/gate_counter.cpp'),'-o',str(work/executable)],check=True)
        (work/'gated.txt').write_text('0\n')
        (work/'tb_count.sv').write_text(f'`timescale 1ns/1ps\nmodule tb_count; {top} dut(); initial begin #1; $finish; end endmodule\n')
        env=os.environ.copy()
        env['PATH']=str(work)+os.pathsep+env.get('PATH','')
        commands=[['vlib','work'],['vlog','-sv','+define+ACTEL_COUNT']+[str(p) for p in sources]+['tb_count.sv'],
                  ['vsim','-c','work.tb_count','-do','onerror {quit -code 1}; onfinish stop; run -all; quit -code 0']]
        for command in commands:
            p=subprocess.run(command,cwd=work,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
            (work/(command[0]+'.log')).write_text(p.stdout)
            if p.returncode: raise RuntimeError(p.stdout)
        gates=int((work/'gated.txt').read_text())
        expected=int((ROOT/'results/gates'/top/'gated.txt').read_text())
        if gates!=expected: raise AssertionError(f'{top}: runtime={gates}, static={expected}')
        destination=ROOT/'results/native_count'/top
        destination.mkdir(parents=True,exist_ok=True)
        (destination/'gated.txt').write_text(str(gates)+'\n')
        reports.append({'top':top,'runtime_gates':gates,'matches_elaboration':True})
        print(top,gates)
    (ROOT/'results/native_count/verification.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__=='__main__': main()
