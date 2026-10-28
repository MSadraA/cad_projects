"""Strict structural lint, with three documented style-only warning exclusions.

WIDTHEXPAND: bounded unsigned indices widen for integer parameter arithmetic.
UNUSEDSIGNAL: status probes and discarded upper bits are intentional.
PINCONNECTEMPTY: unused status outputs are explicitly left open by name.
Truncation, latches, multiple drivers, implicit nets, and combinational cycles
remain enabled and cause failure. This is lint, not a synthesis resource report.
"""
from __future__ import annotations

import subprocess
import sys

from run import ROOT, source_files


def main() -> int:
    base = ROOT / 'build/lint'
    base.mkdir(parents=True, exist_ok=True)
    profiles = [(), (15,3,5,7,7), (1,1,1,1,1), (14,8,3,7,3),
                (20,11,17,5,11), (9,11,3,4,7), (7,2,2,7,1)]
    failures = 0
    for i, values in enumerate(profiles):
        command = ['verilator', '--lint-only', '--language', '1364-2005', '--top-module', 'fcnn_top',
                   '-Wall', '-Wno-WIDTHEXPAND', '-Wno-UNUSEDSIGNAL', '-Wno-PINCONNECTEMPTY']
        for key, value in zip(('N_INPUTS','N_HIDDEN','N_OUTPUTS','LANES','SRAM_LATENCY'), values):
            command.append(f'-G{key}={value}')
        try:
            result = subprocess.run(command + [str(p) for p in source_files()], cwd=ROOT,
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        except OSError as exc:
            print(f'FAIL: {exc}', file=sys.stderr)
            return 1
        original_output = result.stdout
        if result.returncode and 'Internal Error' in result.stdout and 'V3Gate.cpp' in result.stdout:
            # Verilator 5.020 can fail in its gate optimizer on constant-index
            # memory layouts. Retry lint with only that optimization disabled;
            # all warning checks remain enabled. Retain both logs for review.
            result = subprocess.run(command[:1] + ['-fno-gate'] + command[1:] + [str(p) for p in source_files()],
                                    cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=60)
            original_output += '\nRETRY: Verilator gate optimizer disabled for lint only.\n' + result.stdout
        (base / f'profile_{i}.log').write_text(original_output, encoding='utf-8')
        if result.returncode:
            failures += 1
            print(result.stdout, file=sys.stderr)
        else:
            print(f'PASS lint profile {i}')
    return int(failures != 0)


if __name__ == '__main__':
    raise SystemExit(main())
