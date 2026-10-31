#!/usr/bin/env python3
"""Create a separate CA1 source copy, replacing only the three phase-1 modules."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
TARGETS={'fcnn_fp16_adder.v','fcnn_fp16_multiplier.v','fcnn_ping_pong_buffer.v'}


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--ca1-src',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args()
    src=args.ca1_src.resolve();out=args.out.resolve()
    if out.exists(): ap.error('Output already exists; choose a new directory')
    if src==out or src in out.parents: ap.error('Output must be outside the original source tree')
    for name in TARGETS|{'fcnn_top.v'}:
        if not (src/'rtl'/name).is_file(): ap.error(f'Not a CA1 src directory: missing rtl/{name}')
    original={p.name:sha(p) for p in (src/'rtl').glob('*.v') if p.name not in TARGETS}
    shutil.copytree(src,out,ignore=shutil.ignore_patterns('work','build','*.wlf','transcript','*.mpf','*.mti','__pycache__'))
    for folder in ('actel','common'):
        shutil.copytree(ROOT/'rtl'/folder,out/'rtl'/folder)
    for name in TARGETS:
        source=ROOT/('integration' if name=='fcnn_ping_pong_buffer.v' else 'rtl')/name
        shutil.copy2(source,out/'rtl'/name)
    sources=sorted(str(p.relative_to(out)).replace('\\','/') for p in (out/'rtl').rglob('*.v'))
    (out/'rtl/files.f').write_text('\n'.join(sources)+'\n')
    assert all(sha(out/'rtl'/name)==digest for name,digest in original.items())
    report={'replaced':sorted(TARGETS),'unchanged_original_rtl_sha256':original,
            'source':str(src),'arithmetic':'CA2 literal zero-fraction policy and truncate',
            'buffer_gates':4499,'note':'Re-generate the numerical oracle for CA2; old RNE goldens are incompatible.'}
    (out/'overlay_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Prepared {out}; {len(original)} other RTL modules preserved byte-for-byte')


if __name__=='__main__': main()
