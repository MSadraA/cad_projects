#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import random
from reference_model import add,multiply

ROOT=Path(__file__).resolve().parents[1]


def pairs(quick=False):
    special=[0,0x8000,1,0x3ff,0x8001,0x83ff,0x0400,0x0401,0x07ff,
             0x3bff,0x3c00,0x3c01,0x3d55,0x3e00,0x3fff,0x4000,0x4001,
             0x7bfe,0x7bff,0x7c00,0x7c01,0x7e00,0x7fff]
    special=sorted(set(special+[x|0x8000 for x in special]))
    for a in special:
        for b in special: yield a,b
    # Every 16-bit encoding against four anchors (including a cancellation sign).
    for a in range(0x10000 if not quick else 0x1000):
        for b in (0,0x3c01,0xbc01,0x7bff): yield a,b
    # Every exponent pair and targeted significand/borrow boundaries.
    for ea in range(1,32):
        for eb in range(1,32):
            for fa,fb in ((1,1),(1,1023),(1023,1),(1023,1023),(512,513)):
                a=(ea<<10)|fa
                b=(eb<<10)|fb
                yield a,b
                yield a,b|0x8000
    # Adjacent opposite-sign values force long cancellation and underflow.
    for e in range(1,31):
        for f in range(1,1023):
            a=(e<<10)|f
            yield a,(a+1)|0x8000
    rng=random.Random(810102420)
    for _ in range(20000 if quick else 100000):
        yield rng.randrange(65536),rng.randrange(65536)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--quick',action='store_true')
    args=ap.parse_args()
    out=ROOT/'tb/vectors'
    out.mkdir(parents=True,exist_ok=True)
    count=0
    with (out/'fp_vectors.txt').open('w') as f:
        for a,b in pairs(args.quick):
            f.write(f'{a:04x} {b:04x} {add(a,b):04x} {multiply(a,b):04x} {add(a,b,False):04x} {multiply(a,b,False):04x}\n')
            count+=1
    info={'vectors':count,'seed':810102420,'quick':args.quick,
          'fields':['a','b','add_literal','mul_literal','add_hidden_one','mul_hidden_one'],
          'oracle':'exact signed integer arithmetic with one final truncate'}
    (out/'manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    print(f'Generated {count} vectors per arithmetic operation/policy')


if __name__=='__main__': main()
