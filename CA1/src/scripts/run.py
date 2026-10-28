"""Reproducible RTL regression for Icarus and ModelSim/Questa.

Run from any working directory. Source files are read from rtl/files.f. Inputs
are copied byte-for-byte into isolated build directories; source data is never
rewritten. A missing simulator, compilation error, RTL assertion, timeout,
missing PASS marker or numerical mismatch makes this process fail.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from reference_model import evaluate, write_mem

ROOT = Path(__file__).resolve().parents[1]
PARAMETERS = {'N_INPUTS', 'N_HIDDEN', 'N_OUTPUTS', 'LANES', 'SRAM_LATENCY', 'CLOCK_PERIOD_NS'}
FILE_PARAMETERS = {'FC1_WEIGHTS_FILE': 'fc1_weights.mem', 'FC2_WEIGHTS_FILE': 'fc2_weights.mem',
                   'INPUT_FILE': 'test_image.mem', 'FC1_BIAS_FILE': 'fc1_bias.mem', 'FC2_BIAS_FILE': 'fc2_bias.mem'}
FAIL_PATTERN = re.compile(r'\[FAIL\]|\[FATAL|\*\*\s+(?:Error|Fatal)|ERROR:|WARNING:', re.IGNORECASE)


def execute(command: list[str], cwd: Path, log: Path, *, timeout: int = 120) -> str:
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        log.write_text(str(exc) + '\n', encoding='utf-8')
        raise RuntimeError(f'Cannot execute {command[0]}: {exc}') from exc
    log.write_text(result.stdout, encoding='utf-8')
    if result.returncode != 0 or FAIL_PATTERN.search(result.stdout):
        raise RuntimeError(f'{command[0]} failed; see {log}')
    return result.stdout


def source_files() -> list[Path]:
    paths = [ROOT / line.strip() for line in (ROOT / 'rtl/files.f').read_text().splitlines() if line.strip()]
    if len(paths) != len(set(paths)) or any(not p.is_file() for p in paths):
        raise ValueError('Invalid or duplicate rtl/files.f entries')
    if set(paths) != set((ROOT / 'rtl').glob('*.v')):
        raise ValueError('rtl/files.f does not match the RTL directory')
    return paths


def check_pass(output: str, token: str) -> None:
    if FAIL_PATTERN.search(output) or token not in output:
        raise RuntimeError(f'Missing successful marker: {token}')


def compile_tb(simulator: str, name: str, parameters: dict, build: Path) -> Path:
    sources = source_files() + [ROOT / 'verification' / f'{name}.v']
    if simulator == 'icarus':
        executable = build / f'{name}.vvp'
        command = ['iverilog', '-g2005', '-s', name, '-o', str(executable)]
        for key, value in parameters.items():
            literal = json.dumps(value, ensure_ascii=False) if isinstance(value, str) else str(int(value))
            command += [f'-P{name}.{key}={literal}']
        execute(command + [str(path) for path in sources], build, build / f'{name}_compile.log')
        return executable
    if not (build / 'work').is_dir():
        execute(['vlib', 'work'], build, build / 'vlib.log')
    execute(['vlog', '-work', 'work'] + [str(p) for p in sources], build, build / f'{name}_compile.log')
    return build / 'work'


def run_tb(simulator: str, name: str, executable: Path, parameters: dict,
           plusargs: list[str], directory: Path, log: Path) -> str:
    if simulator == 'icarus':
        return execute(['vvp', str(executable)] + plusargs, directory, log)
    # Absolute library path allows isolated case working directories. The script
    # catches a simulator error and exits nonzero; Python also requires PASS.
    script = directory / 'run.do'
    # Keep Verilog string literals quoted within each argv item; ModelSim's
    # generic parser must retain embedded spaces in custom file paths.
    generic_args = [f'-g{k}={json.dumps(v, ensure_ascii=False) if isinstance(v, str) else int(v)}'
                    for k, v in parameters.items()]
    args = ['-c', '-onfinish', 'stop', '-lib', str(executable), name] + generic_args + plusargs
    script.write_text('onerror {quit -f -code 2}\nrun -all\nquit -f -code 0\n', encoding='ascii')
    return execute(['vsim'] + args + ['-do', str(script)], directory, log)


def run_suite(args: argparse.Namespace) -> dict:
    suite_file = Path(args.suite).resolve() if args.suite else ROOT / 'config/regression.json'
    suite = json.loads(suite_file.read_text(encoding='utf-8'))
    parameters = dict(suite['parameters'])
    for assignment in args.set:
        key, value = assignment.split('=', 1)
        if key not in PARAMETERS:
            raise ValueError(f'Unknown parameter {key}; choose from {sorted(PARAMETERS)}')
        parameters[key] = int(value)
    if set(parameters) - PARAMETERS or any(not isinstance(v, int) or v < 1 for v in parameters.values()):
        raise ValueError('Only positive integer parameters are accepted')
    if args.runs < 1 or args.reset_after < 0:
        raise ValueError('runs must be positive and reset_after must be nonnegative')
    file_parameters = {**FILE_PARAMETERS, **suite.get('file_parameters', {})}
    for assignment in args.file_param:
        key, value = assignment.split('=', 1)
        file_parameters[key] = value
    if set(file_parameters) != set(FILE_PARAMETERS):
        raise ValueError('Unknown file parameter')
    for key, value in file_parameters.items():
        if not isinstance(value, str) or not value or any(ord(c) < 32 for c in value):
            raise ValueError(f'{key}: expected a nonempty path without control characters')
        file_parameters[key] = value.replace('\\', '/')
        path = Path(file_parameters[key])
        if path.is_absolute() or '..' in path.parts:
            raise ValueError(f'{key}: runner stages relative paths within the case directory')
    if len(set(file_parameters.values())) != 5 or any(v in {'expected_logits.mem','expected_hidden.mem','run.do','simulation.log','fcnn.vcd'} for v in file_parameters.values()):
        raise ValueError('Input file names must be distinct and cannot replace oracle/log files')
    selected = suite['cases'] if args.cases == 'all' else [c for c in suite['cases'] if c['name'] in args.cases.split(',')]
    if not selected or (args.cases != 'all' and {c['name'] for c in selected} != set(args.cases.split(','))):
        raise ValueError('Unknown or empty case selection')
    if len({c['name'] for c in selected}) != len(selected):
        raise ValueError('Duplicate case names')
    build = ROOT / 'build' / args.tag
    build.mkdir(parents=True, exist_ok=True)
    report = {'simulator': args.sim, 'suite': str(suite_file), 'parameters': parameters,
              'file_parameters': file_parameters, 'runs': args.runs, 'reset_after': args.reset_after, 'cases': [], 'passed': False}
    report_file = build / 'results.json'
    try:
        executable = compile_tb(args.sim, 'tb_fcnn', {**parameters, **file_parameters}, build)
        model = (ROOT / suite['model_dir']).resolve()
        for case in selected:
            if not re.fullmatch(r'[A-Za-z0-9_-]+', case['name']):
                raise ValueError('Case names may contain only letters, numbers, underscore and hyphen')
            directory = build / case['name']
            directory.mkdir(exist_ok=True)
            image = (ROOT / case['image']).resolve()
            ni, nh, no = (parameters[k] for k in ('N_INPUTS', 'N_HIDDEN', 'N_OUTPUTS'))
            oracle = evaluate(model, image, ni, nh, no)
            for key, original_name in FILE_PARAMETERS.items():
                source = image if key == 'INPUT_FILE' else model / original_name
                target = directory / file_parameters[key]
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
            write_mem(directory / 'expected_logits.mem', oracle['logits'])
            write_mem(directory / 'expected_hidden.mem', oracle['hidden'])
            baseline = {}
            if 'legacy_golden' in case:
                # Original stored expected files used bias-first and are NOT the
                # oracle for the corrected design. Verify their provenance by
                # recomputing the old arithmetic independently.
                old = evaluate(model, image, ni, nh, no, bias_first=True)
                legacy = json.loads((ROOT / suite['legacy_goldens']).read_text())[case['legacy_golden']]
                stored = legacy['logits']
                old_digit = legacy['predicted_digit']
                if stored != old['logits'] or old_digit != old['predicted_digit']:
                    raise ValueError(f"{case['name']}: original golden files do not match the legacy model")
                baseline = {'legacy_golden_validated': True,
                            'changed_logit_words': sum(a != b for a, b in zip(stored, oracle['logits'])),
                            'legacy_predicted_digit': old_digit}
            plusargs = ['+check_outputs=1', f'+expected_digit={oracle["predicted_digit"]}', f'+runs={args.runs}',
                        f'+reset_after={args.reset_after}', '+busy_start=1']
            if args.timeout_cycles:
                plusargs += [f'+timeout={args.timeout_cycles}']
            if args.wave:
                plusargs += ['+wave=1']
            output = run_tb(args.sim, 'tb_fcnn', executable, {**parameters, **file_parameters}, plusargs, directory, directory / 'simulation.log')
            check_pass(output, '[PASS] E2E runs=')
            if not re.search(r'\[PASS\] E2E runs=[^\n]*checked_outputs=1\b', output):
                raise RuntimeError('Numerical scoreboard was not enabled')
            measurements = []
            for line in output.splitlines():
                if '[MEASURE]' in line:
                    measurements.append({k: int(v) for k, v in re.findall(r'(\w+)=(-?\d+)', line)})
            if len(measurements) != args.runs:
                raise RuntimeError(f'{case["name"]}: missing run measurements')
            entry = {'name': case['name'], 'passed': True, 'measurements': measurements,
                     'oracle': oracle, **baseline}
            if 'true_label' in case:
                entry['true_label'] = case['true_label']
                entry['classification_correct'] = oracle['predicted_digit'] == case['true_label']
            report['cases'].append(entry)
            print(f"PASS {case['name']}: {measurements[0]['cycles']} cycles; runs={args.runs}; digit={oracle['predicted_digit']}", flush=True)
        report['passed'] = True
    except Exception as exc:
        report['error'] = str(exc)
        raise
    finally:
        report_file.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim', choices=['icarus', 'modelsim'], default='icarus')
    parser.add_argument('--suite', help='JSON suite; data paths are relative to project root')
    parser.add_argument('--cases', default='all', help='all, or comma-separated case names')
    parser.add_argument('--runs', type=int, default=2, help='completed inferences without reset per case')
    parser.add_argument('--reset-after', type=int, default=0, help='abort an initial run at this cycle, then test fresh runs')
    parser.add_argument('--timeout-cycles', type=int, default=0)
    parser.add_argument('--file-param', action='append', default=[], metavar='PARAM=PATH', help='rename an input within each isolated case directory')
    parser.add_argument('--set', action='append', default=[], metavar='PARAM=VALUE')
    parser.add_argument('--tag', default='regression', help='build directory name')
    parser.add_argument('--wave', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.tag):
        parser.error('tag must be a simple directory name')
    try:
        run_suite(args)
    except (ValueError, OSError, RuntimeError, KeyError) as exc:
        print(f'FAIL: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
