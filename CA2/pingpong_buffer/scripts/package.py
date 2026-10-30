#!/usr/bin/env python3
"""Package only reviewed sources, documentation, vectors and passing evidence."""
import hashlib
import json
import os
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]
EXCLUDED={'build','__pycache__','.git'}


def main():
    regression=json.loads((ROOT/'results/icarus/regression.json').read_text())
    assert len(regression['results'])==11 and not regression['quick']
    assert all(r['pass'] for r in regression['results'])
    for name,digest in json.loads((ROOT/'results/icarus/source_sha256.json').read_text()).items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
    assert (ROOT/'docs/CAD_CA2_Phase1_Report_FA.pdf').is_file()
    files=[]
    for path in sorted(ROOT.rglob('*')):
        relative=path.relative_to(ROOT)
        if not path.is_file() or EXCLUDED.intersection(relative.parts):continue
        if path.suffix in {'.pyc','.vvp','.wlf'} or path.name=='MANIFEST_SHA256.json':continue
        files.append(path)
    manifest={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    manifest_path=ROOT/'MANIFEST_SHA256.json'
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    destination=ROOT.parent/(ROOT.name+'.zip')
    temporary=destination.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for path in files+[manifest_path]:archive.write(path,ROOT.name+'/'+str(path.relative_to(ROOT)))
    with zipfile.ZipFile(temporary) as archive:
        assert archive.testzip() is None
        for name,digest in manifest.items():
            assert hashlib.sha256(archive.read(ROOT.name+'/'+name)).hexdigest()==digest,name
        assert not any('/build/' in n or '__pycache__' in n for n in archive.namelist())
    os.replace(temporary,destination)
    print(json.dumps({'file':str(destination),'size_bytes':destination.stat().st_size,
                      'files':len(files)+1,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()},indent=2))


if __name__=='__main__': main()
