"""Check source syntax, data integrity, hierarchy and generated design consistency."""
from __future__ import annotations

import ast
import hashlib
import json
import re
from pathlib import Path

from design_docs import ROOT, generate_outputs, hierarchy, parse_modules
from reference_model import read_mem
from run import source_files


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_wave_paths(modules: dict, tb: str) -> int:
    """Validate the literal paths used by this project's curated wave layout."""
    paths = re.findall(r'sim:/tb_fcnn/[A-Za-z0-9_/]+', (ROOT/'modelsim/wave.do').read_text())
    if not paths or len(paths) != len(set(paths)):
        raise ValueError('Empty or duplicate ModelSim wave paths')
    for path in paths:
        parts = path.removeprefix('sim:/tb_fcnn/').split('/')
        source = tb
        module = None
        for instance_name in parts[:-1]:
            if module is None:
                if instance_name != 'dut':
                    raise ValueError(f'Unknown TB instance in wave path: {path}')
                module = modules['fcnn_top']
            else:
                instances = {i['name']: i['module'] for i in module['instances']}
                if instance_name not in instances:
                    raise ValueError(f'Unknown RTL instance in wave path: {path}')
                module = modules[instances[instance_name]]
            source = (ROOT/module['file']).read_text()
        clean = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
        names = set()
        for declaration in re.findall(r'\b(?:wire|reg|integer)\s+(?:\[[^\]]+\]\s*)?([^;]+);', clean):
            for item in declaration.split(','):
                match = re.match(r'\s*(?:(?:input|output|wire|reg|signed)\s+|\[[^\]]+\]\s*)*(\w+)', item)
                if match:
                    names.add(match.group(1))
        if parts[-1] not in names:
            raise ValueError(f'Unknown signal in wave path: {path}')
    return len(paths)


def main() -> int:
    source_files()
    modules = parse_modules()
    rows, counts = hierarchy(modules)
    for path in (ROOT / 'scripts').glob('*.py'):
        ast.parse(path.read_text(encoding='utf-8'), filename=path.name)
    for path, expected in generate_outputs(modules).items():
        if path.read_text(encoding='utf-8') != expected:
            raise ValueError(f'Stale generated design file: {path.relative_to(ROOT)}')
    tb = (ROOT / 'verification/tb_fcnn.v').read_text()
    wave_paths = check_wave_paths(modules, tb)
    for parameter in modules['fcnn_top']['parameters']:
        if not re.search(r'\.'+parameter+r'\(\s*'+parameter+r'\s*\)', tb):
            raise ValueError(f'Top parameter is not forwarded by TB: {parameter}')
    manifest = json.loads((ROOT / 'data/manifest.json').read_text())
    paths = {str(p.relative_to(ROOT)):p for p in (ROOT / 'data').rglob('*') if p.is_file() and p.name!='manifest.json'}
    if set(paths) != set(manifest['sha256']):
        raise ValueError('Data file inventory differs from data/manifest.json')
    for name,path in paths.items():
        if sha256(path)!=manifest['sha256'][name]:
            raise ValueError(f'Data bytes changed: {name}')
    suite=json.loads((ROOT/'config/regression.json').read_text())
    ni,nh,no=(suite['parameters'][k] for k in ('N_INPUTS','N_HIDDEN','N_OUTPUTS'))
    for filename,count in [('fc1_weights.mem',ni*nh),('fc2_weights.mem',nh*no),('fc1_bias.mem',nh),('fc2_bias.mem',no)]:
        read_mem(ROOT/suite['model_dir']/filename,count)
    for case in suite['cases']:
        read_mem(ROOT/case['image'],ni)
    result={'passed':True,'module_types':len(modules),'module_instances':len(rows),
            'fp16_adders':counts['fcnn_fp16_adder'],'fp16_multipliers':counts['fcnn_fp16_multiplier'],
            'top_parameters_forwarded':len(modules['fcnn_top']['parameters']),
            'port_width_declaration_order_checked':len(modules),
            'non_ansi_derived_width_interfaces':sum(m['port_style']=='non_ansi' for m in modules.values()),
            'modelsim_wave_paths_checked':wave_paths,
            'data_files_verified':len(paths),'input_cases':len(suite['cases'])}
    destination=ROOT/'build/audit';destination.mkdir(parents=True,exist_ok=True)
    (destination/'results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0


if __name__=='__main__':
    raise SystemExit(main())
