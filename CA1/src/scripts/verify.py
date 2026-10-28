"""Run arithmetic, protocol, parameter, and failure-detection regressions.

No third-party Python packages are needed. Icarus is the default simulator;
--sim modelsim selects ModelSim/Questa for the same Verilog-2005 benches.
Use --groups to rerun only the relevant checks after a change.
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
import subprocess
import sys
from pathlib import Path

from generate_cases import generate
from reference_model import add, mul, relu, argmax
from run import ROOT, check_pass, compile_tb, run_tb


def fp_vectors(path: Path) -> int:
    rng = random.Random(17501)
    edges = [0, 0x8000, 1, 0x8001, 0x03FF, 0x0400, 0x07FF, 0x3555,
             0x3BFF, 0x3C00, 0x3C01, 0x4000, 0x7BFF, 0xFBFF,
             0x7C00, 0xFC00, 0x7E00, 0xFE00, 0x7C01, 0xFC01]
    pairs = [(a, b) for a in edges for b in edges]
    # Exhaustively exercise every binary16 bit pattern against three operands.
    pairs += [(word, partner) for word in range(65536) for partner in (0, 0x3C00, 0x0001)]
    pairs += [(rng.randrange(65536), rng.randrange(65536)) for _ in range(100000)]
    with path.open('w', encoding='ascii') as stream:
        for a, b in pairs:
            stream.write(f'{a:04x} {b:04x} {add(a,b):04x} {mul(a,b):04x} {relu(a):04x}\n')
    return len(pairs)


def argmax_vectors(path: Path, width: int) -> int:
    rng = random.Random(4200 + width)
    patterns = [[0]*width, [0x8000]*width, [0x7E00]*width, [0xFE01]*width,
                [0xFC00]*width, [0x7C00]*width, [0xBC00]*width]
    for winner in range(width):
        for background, value in [(0xBC00, 0x3C00), (0x7E00, 0), (0x8000, 0)]:
            row = [background]*width
            row[winner] = value
            patterns.append(row)
    patterns += [[rng.randrange(65536) for _ in range(width)] for _ in range(2000)]
    with path.open('w', encoding='ascii') as stream:
        for row in patterns:
            stream.write(''.join(f'{word:04x}' for word in reversed(row)) + f' {argmax(row)}\n')
    return len(patterns)


def run_unit(simulator: str, name: str, parameters: dict, build: Path,
             token: str, plusargs: list[str] | None = None) -> str:
    build.mkdir(parents=True, exist_ok=True)
    binary = compile_tb(simulator, name, parameters, build)
    output = run_tb(simulator, name, binary, parameters, plusargs or [], build, build / 'simulation.log')
    check_pass(output, token)
    print(next(line for line in output.splitlines() if token in line), flush=True)
    return output


def expected_failure(command: list[str], directory: Path, marker: str, log: Path) -> None:
    result = subprocess.run(command, cwd=directory, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=120, check=False)
    log.write_text(result.stdout, encoding='utf-8')
    if marker not in result.stdout or '[PASS]' in result.stdout:
        raise RuntimeError(f'Expected guard was not observed: {marker}')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sim', choices=['icarus', 'modelsim'], default='icarus')
    parser.add_argument('--groups', default='fp,units,parameters,negative')
    args = parser.parse_args()
    groups = set(args.groups.split(','))
    if groups - {'fp', 'units', 'parameters', 'negative'}:
        parser.error('groups: fp,units,parameters,negative')
    base = ROOT / 'build' / 'verification'
    base.mkdir(parents=True, exist_ok=True)
    results = {'simulator': args.sim, 'checks': [], 'passed': False}

    def record(name: str, function) -> None:
        function()
        results['checks'].append({'name': name, 'passed': True})

    try:
        if 'fp' in groups:
            work = base / 'fp16'
            work.mkdir(exist_ok=True)
            results['fp_vectors'] = fp_vectors(work / 'fp16_vectors.txt')
            record('fp16', lambda: run_unit(args.sim, 'tb_fp16', {}, work, '[PASS] FP16'))
            for width in (1, 3, 10, 17):
                work = base / f'argmax_{width}'
                work.mkdir(exist_ok=True)
                argmax_vectors(work / 'argmax_vectors.txt', width)
                record(f'argmax_{width}', lambda w=width, d=work: run_unit(args.sim, 'tb_argmax', {'N_OUTPUTS': w}, d, '[PASS] ARGMAX'))
        if 'units' in groups:
            for lanes in (1, 3, 7, 8):
                record(f'pingpong_{lanes}', lambda n=lanes: run_unit(args.sim, 'tb_pingpong', {'LANES': n}, base / f'pingpong_{n}', '[PASS] PINGPONG'))
            record('pipeline', lambda: run_unit(args.sim, 'tb_pipeline', {}, base / 'pipeline', '[PASS] PIPELINE'))
            for latency in (1, 3, 7, 11):
                work = base / f'sram_{latency}'
                work.mkdir(exist_ok=True)
                for filename in ('fc1_weights.mem', 'fc2_weights.mem', 'fc1_bias.mem', 'fc2_bias.mem'):
                    shutil.copyfile(ROOT / 'data/model' / filename, work / filename)
                shutil.copyfile(ROOT / 'data/cases/reference/test_image.mem', work / 'test_image.mem')
                record(f'sram_{latency}', lambda n=latency, d=work: run_unit(args.sim, 'tb_sram', {'SRAM_LATENCY': n}, d, '[PASS] SRAM'))
        if 'parameters' in groups:
            profiles = [(15,3,5,7,7), (1,1,1,1,1), (14,8,3,7,3),
                        (20,11,17,5,11), (9,11,3,4,7), (7,2,2,7,1)]
            for index, dimensions in enumerate(profiles):
                suite = generate(base / f'generated_{index}', *dimensions, seed=42+index)
                command = [sys.executable, str(ROOT / 'scripts/run.py'), '--sim', args.sim,
                           '--suite', str(suite), '--runs', '2', '--tag', f'parameters_{index}']
                def run_profile(cmd=command, i=index):
                    result = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=120)
                    (base / f'parameters_{i}.log').write_text(result.stdout, encoding='utf-8')
                    if result.returncode:
                        raise RuntimeError(result.stdout)
                    print(result.stdout.strip(), flush=True)
                record(f'parameters_{index}', run_profile)
        if 'negative' in groups:
            if args.sim != 'icarus':
                raise ValueError('Negative guard probes currently use Icarus; run --groups fp,units,parameters for ModelSim')
            work = base / 'negative'
            work.mkdir(exist_ok=True)
            binary = compile_tb(args.sim, 'tb_pipeline', {}, work)
            for number, marker in ((1, '[FAIL] ROW_STAGE overwrite'), (2, '[FAIL] ROW_STAGE empty consume')):
                record(f'guard_{number}', lambda n=number, m=marker: expected_failure(['vvp', str(binary), f'+negative={n}'], work, m, work / f'guard_{n}.log'))
            # A deliberately wrong golden word must be rejected by the real E2E
            # checker, not silently accepted because the predicted class agrees.
            suite = generate(work / 'mutant_data', 15, 3, 5, 7, 7, seed=99)
            subprocess.run([sys.executable, str(ROOT / 'scripts/run.py'), '--suite', str(suite), '--cases', 'zero', '--runs', '1', '--tag', 'checker_probe'], check=True, timeout=120)
            run_dir = ROOT / 'build/checker_probe/zero'
            expected = run_dir / 'expected_logits.mem'
            text = expected.read_text()
            expected.write_text(f'{int(text[:4],16)^1:04x}' + text[4:])
            report = json.loads((ROOT / 'build/checker_probe/results.json').read_text())
            digit = report['cases'][0]['oracle']['predicted_digit']
            binary = ROOT / 'build/checker_probe/tb_fcnn.vvp'
            record('checker_rejects_wrong_logit', lambda: expected_failure(['vvp', str(binary), f'+expected_digit={digit}', '+runs=1'], run_dir, '[FAIL] logit', work / 'wrong_logit.log'))
        results['passed'] = True
    except Exception as exc:
        results['error'] = str(exc)
        print(f'FAIL: {exc}', file=sys.stderr)
        return 1
    finally:
        (base / 'results.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(f"PASS: {len(results['checks'])} verification groups", flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
