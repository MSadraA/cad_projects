#!/usr/bin/env python3
"""Validate the source boundary and reconcile saved elaborated gate totals."""
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]


def main():
    files=[ROOT/p for p in (ROOT/'rtl/files.f').read_text().splitlines()]
    assert len(files)==len(set(files)), 'Duplicate source paths'
    hashes={}
    for path in files:
        assert path.is_file(),path
        source=path.read_text()
        stripped=re.sub(r'/\*.*?\*/|//[^\n]*','',source,flags=re.S)
        if path.relative_to(ROOT).as_posix()!='rtl/actel/modules.v':
            assert not re.search(r'\b(always|initial|function|task|reg)\b',stripped),path
        hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    counts=json.loads((ROOT/'results/gate_counts.json').read_text())
    for report in counts:
        total=sum(report['cells'].get(k,0)*v for k,v in {'c1':10,'c2':11,'s1':13,'s2':13}.items())
        assert total==report['gates']
        assert int((ROOT/'results/gates'/report['top']/'gated.txt').read_text())==total
    assert all(r['within_limit'] for r in counts[:3])
    # The identity and gate cost of EVERY flattened leaf is checked in count_gates.py.
    result={'pass':True,'structural_files':len(files)-1,'source_sha256':hashes,
            'phase1_gate_limits_pass':True,'metadata_extension_within_limit':counts[3]['within_limit'],
            'notes':'No behavioral blocks outside TA cell library; all flattened leaves are c1/c2/s1/s2.'}
    (ROOT/'results/source_audit.json').write_text(json.dumps(result,indent=2)+'\n')
    print('[PASS] SOURCE_AUDIT structural sources and phase-1 gate totals')


if __name__=='__main__': main()
