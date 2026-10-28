"""Check no-plusarg TB runs, editable settings, and failure guards with Icarus.

Optional --check-tcl also checks the DO scripts' Tcl flow with stub ModelSim
commands and a project path containing spaces. That is NOT a ModelSim test.
Neither this script nor Python is required to use run_modelsim.do in the GUI.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from generate_cases import generate
from reference_model import evaluate, read_mem, write_mem
from run import ROOT, FAIL_PATTERN, compile_tb


def check_tcl_flow(base: Path) -> dict:
    import tkinter

    checks = []
    expected_paths = set(re.findall(r'sim:/tb_fcnn/[A-Za-z0-9_/]+', (ROOT/'modelsim/wave.do').read_text()))
    for autorun in (0, 1):
        with tempfile.TemporaryDirectory(prefix='project with spaces ', dir=base) as temporary:
            project = Path(temporary)
            for relative in ('run_modelsim.do', 'modelsim/wave.do', 'rtl/files.f', 'verification/tb_fcnn.v'):
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            tcl = tkinter.Tcl()
            calls = []
            for name in ('onerror', 'quit', 'transcript', 'vlib', 'vmap', 'vlog', 'vsim', 'log', 'view', 'delete', 'add', 'configure', 'update', 'run', 'wave', 'puts'):
                if name in ('update', 'puts'):
                    tcl.eval(f'rename {name} original_{name}')
                def record(*args, command=name):
                    calls.append((command, list(args)))
                    if command == 'vmap' and args == ('-c',):
                        Path(tcl.eval('pwd'), 'modelsim.ini').write_text('[Library]\n')
                    return ''
                tcl.createcommand(name, record)
            tcl.eval('proc do {path} {uplevel 1 [list source $path]}')
            if autorun:
                # ModelSim's DO macro interpreter can report an empty script
                # path. Exercise that documented entry point from project cwd.
                tcl.call('cd', str(project))
                tcl.eval('rename info original_info; proc info {args} {if {$args eq "script"} {return ""}; uplevel 1 [list original_info {*}$args]}')
            tcl.setvar('FCNN_AUTORUN', autorun)
            tcl.call('source', str(project / 'run_modelsim.do'))
            assert Path(tcl.eval('pwd')) == project
            assert [args for name, args in calls if name == 'run'] == ([['-all']] if autorun else [])
            simulations = [args for name, args in calls if name == 'vsim']
            assert len(simulations) == 1 and '-voptargs=+acc' in simulations[0]
            assert simulations[0][-1] == 'fcnn_gui_work.tb_fcnn'
            assert simulations[0][simulations[0].index('-modelsimini')+1] == str(project/'build/modelsim_gui/modelsim.ini')
            assert any(name == 'vlog' and 'verification/tb_fcnn.v' in args for name, args in calls)
            paths = [arg for name, args in calls if name == 'add' for arg in args if arg.startswith('sim:/')]
            assert len(paths) == len(set(paths)) and set(paths) == expected_paths
            checks.append({'autorun': autorun, 'wave_signals': len(paths), 'passed': True,
                           'script_path_mode': 'empty DO info script' if autorun else 'Tcl source'})
            os.chdir(ROOT)
    return {'engine': str(tcl.call('info', 'patchlevel')), 'stubbed_modelsim_commands': True,
            'actual_modelsim_execution': False, 'checks': checks}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-tcl', action='store_true', help='requires Python tkinter/Tcl; checks script flow only')
    args = parser.parse_args()
    base = ROOT / 'build/gui_validation'
    base.mkdir(parents=True, exist_ok=True)
    report = {'simulator': 'icarus', 'actual_modelsim_execution': False, 'checks': [], 'passed': False}

    def relative(path: Path) -> str:
        return str(path.relative_to(ROOT))

    def run(name: str, parameters: dict, oracle: dict | None = None, runs: int = 1,
            marker: str | None = None) -> None:
        directory = base / name
        directory.mkdir(exist_ok=True)
        executable = compile_tb('icarus', 'tb_fcnn', parameters, directory)
        # Deliberately NO plusargs: equivalent to editing TB parameters and
        # loading tb_fcnn from the GUI, with the project root as working dir.
        result = subprocess.run(['vvp', str(executable)], cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=120)
        output = result.stdout
        (directory / 'simulation.log').write_text(output, encoding='utf-8')
        if marker:
            if marker not in output or '[PASS]' in output:
                raise RuntimeError(f'{name}: expected rejection was not observed')
        else:
            if result.returncode or FAIL_PATTERN.search(output) or '[PASS]' not in output:
                raise RuntimeError(f'{name}: see {directory / "simulation.log"}')
            measured = re.findall(r'\[MEASURE\] run=(\d+) cycles=(\d+)', output)
            if len(measured) != runs:
                raise RuntimeError(f'{name}: wrong run count')
            for number in range(1, runs+1):
                values = [int(word, 16) for n, index, word in re.findall(r'\[RESULT\] run=(\d+) logit\[(\d+)\]=([0-9a-fA-F]+)', output) if int(n) == number]
                digits = re.findall(rf'\[RESULT\] run={number} predicted_digit=(\d+)', output)
                if values != oracle['logits'] or digits != [str(oracle['predicted_digit'])]:
                    raise RuntimeError(f'{name}: displayed result differs from independent oracle')
        report['checks'].append({'name': name, 'passed': True, 'expected_failure': bool(marker),
                                 'inferences': 0 if marker else runs, 'tb_parameters': parameters})
        print(f'PASS {name}'+(' (expected rejection)' if marker else f' ({runs} no-plusarg inferences)'), flush=True)

    try:
        model = ROOT / 'data/model'
        reference = ROOT / 'data/cases/reference/test_image.mem'
        expected = evaluate(model, reference, 784, 8, 10)
        run('default_no_args', {}, expected, runs=2)
        digit7 = ROOT / 'data/cases/digit_7/test_image.mem'
        run('edit_image_reset_clock', {'INPUT_FILE': relative(digit7), 'RUNS': 1, 'RESET_AFTER': 6350,
                                      'CLOCK_PERIOD_NS': 4, 'INJECT_BUSY_START': 0},
            evaluate(model, digit7, 784, 8, 10))
        custom = base / 'custom_image.mem'
        write_mem(custom, [0x3C00 if i % 2 else 0 for i in range(784)])
        run('unseen_image', {'INPUT_FILE': relative(custom), 'RUNS': 1}, evaluate(model, custom, 784, 8, 10))
        suite = json.loads(generate(base / 'small_model', 15, 3, 5, 7, 3, seed=71).read_text())
        small_model = ROOT / suite['model_dir']
        small_image = ROOT / suite['cases'][-1]['image']
        settings = {**suite['parameters'], 'CLOCK_PERIOD_NS': 4, 'RUNS': 3, 'DUMP_WAVE': 1,
                    'VCD_FILE': relative(base/'small_model_wave/fcnn.vcd'),
                    'FC1_WEIGHTS_FILE': relative(small_model/'fc1_weights.mem'),
                    'FC2_WEIGHTS_FILE': relative(small_model/'fc2_weights.mem'),
                    'FC1_BIAS_FILE': relative(small_model/'fc1_bias.mem'),
                    'FC2_BIAS_FILE': relative(small_model/'fc2_bias.mem'), 'INPUT_FILE': relative(small_image)}
        vcd = base / 'small_model_wave/fcnn.vcd'
        run('small_model_wave', settings, evaluate(small_model, small_image, 15, 3, 5), runs=3)
        if not vcd.is_file() or '$enddefinitions' not in vcd.read_text():
            raise RuntimeError('Missing waveform probe output')
        write_mem(base / 'expected_logits.mem', expected['logits'])
        write_mem(base / 'expected_hidden.mem', expected['hidden'])
        run('manual_golden_parameters', {'RUNS': 1, 'CHECK_OUTPUTS': 1, 'EXPECTED_DIGIT': expected['predicted_digit'],
            'EXPECTED_LOGITS_FILE': relative(base/'expected_logits.mem'),
            'EXPECTED_HIDDEN_FILE': relative(base/'expected_hidden.mem')}, expected)
        run('missing_expected_setting', {'CHECK_OUTPUTS': 1}, marker='[FAIL] CHECK_OUTPUTS requires')
        run('missing_image', {'INPUT_FILE': relative(base/'does_not_exist.mem')}, marker='[FAIL] cannot open file:')
        short_image = base / 'short_image.mem'
        write_mem(short_image, read_mem(reference)[:10])
        run('short_image', {'INPUT_FILE': relative(short_image)}, marker='[FAIL] unknown multiplier operand')
        if args.check_tcl:
            report['tcl_script_flow'] = check_tcl_flow(base)
            print('PASS Tcl DO-script flow (stub commands; NOT a ModelSim execution)', flush=True)
        report['passed'] = True
    except Exception as exc:
        report['error'] = str(exc)
        print(f'FAIL: {exc}', flush=True)
        return 1
    finally:
        (base / 'results.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(f"PASS: {len(report['checks'])} interactive-TB checks", flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
