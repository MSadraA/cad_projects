"""Export HW1 Task 5's required filenames from the single-source project.

The generated aggregate is an alternative to rtl/*.v, never an extra source
to compile alongside them. Original prompt-history artifacts are not invented.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from design_docs import ROOT, generate_outputs, parse_interface, parse_modules
from run import source_files


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--partition-output',type=Path,help='also export Task-2 headers and partitioning/diagrams')
    args=parser.parse_args()
    modules=parse_modules()
    for path,expected in generate_outputs(modules).items():
        if path.read_text(encoding='utf-8')!=expected:
            raise ValueError(f'Stale plan/diagram source: {path}')
    code='// Generated from rtl/files.f. Compile THIS file OR rtl/*.v, never both.\n\n'
    for path in source_files():
        code+='// Source: '+str(path.relative_to(ROOT))+'\n'+path.read_text(encoding='utf-8')+'\n'
    plan=(ROOT/'docs/05_plan.md').read_text(encoding='utf-8')
    for name in modules:
        plan+='\n\n---\n\n'+(ROOT/'docs/plans'/f'{name}.md').read_text(encoding='utf-8')
    output=args.output.resolve();output.parent.mkdir(parents=True,exist_ok=True)
    with ZipFile(output,'w',ZIP_DEFLATED) as archive:
        archive.writestr('05_code.v',code)
        archive.writestr('05_plan.md',plan)
        archive.writestr('README.txt','Generated Task-5 view of the maintained project.\nCompile 05_code.v alone as the RTL source.\nAll numerical operations are binary16 RNE; bias is added last.\nThe PNG images accompany the actual RTL.\nFull verification evidence is in the main project package.\n')
        for path in sorted((ROOT/'docs/diagrams').glob('*.png')):
            archive.write(path,path.name)
    if args.partition_output:
        header_text='// Task-2 interface declarations only. No functional RTL.\n'
        for path in source_files():
            header_text+='\n'+parse_interface(path.read_text(encoding='utf-8'))['interface_source']
        target=args.partition_output.resolve();target.parent.mkdir(parents=True,exist_ok=True)
        with ZipFile(target,'w',ZIP_DEFLATED) as archive:
            archive.writestr('02_module_headers.v',header_text)
            archive.write(ROOT/'docs/02_partitioning.md','02_partitioning.md')
            for path in sorted((ROOT/'docs/diagrams').glob('*.png')):
                archive.write(path,'diagrams/'+path.name)
        print(target.name)
    print(f'{output.name}: sha256={hashlib.sha256(output.read_bytes()).hexdigest()}')


if __name__=='__main__':
    main()
