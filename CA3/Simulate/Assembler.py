#!/usr/bin/env python3
"""Tiny MIPS assembler for the instruction subset of the course processor.

Needs Python 3, no extra packages.

Syntax: one instruction per line, `;` also separates instructions, `#` starts a comment,
`label:` defines a label (its value is the byte address). Registers by name ($t1) or number ($9).
A label may be used as an immediate (`addi $t1,$zero,Lnew` loads its byte address).
Pseudo-instructions: `nop`, `nop N` (N nops), `halt` (= j <self>: an endless loop that ends the program).

    python3 asm.py prog.s program.mem

The output has one 8-digit hex word per line, which is the format the processor reads from program.mem.
"""
import re
import sys

REGS = {n: i for i, n in enumerate(
    "zero at v0 v1 a0 a1 a2 a3 t0 t1 t2 t3 t4 t5 t6 t7 s0 s1 s2 s3 s4 s5 s6 s7 t8 t9 k0 k1 gp sp fp ra".split())}

R3 = {"add": 0x20, "addu": 0x21, "sub": 0x22, "subu": 0x23, "and": 0x24, "or": 0x25, "xor": 0x26,
      "nor": 0x27, "slt": 0x2A, "sltu": 0x2B}
RSHV = {"sllv": 0x04, "srlv": 0x06, "srav": 0x07}
RSH = {"sll": 0x00, "srl": 0x02, "sra": 0x03}
IALU = {"addi": 0x08, "addiu": 0x09, "slti": 0x0A, "sltiu": 0x0B, "andi": 0x0C, "ori": 0x0D, "xori": 0x0E}
MEMOP = {"lw": 0x23, "sw": 0x2B}
BR = {"beq": 0x04, "bne": 0x05}


def reg(tok):
    tok = tok.strip()
    if not tok.startswith("$"):
        raise ValueError(f"bad register {tok!r}")
    t = tok[1:]
    if t.isdigit():
        return int(t)
    return REGS[t]


def split_lines(text):
    """-> list of (label_list, mnemonic, args)"""
    items = []
    for raw in text.splitlines():
        line = raw.split("#")[0]
        for part in line.split(";"):
            part = part.strip()
            while True:
                m = re.match(r"^(\w+)\s*:\s*(.*)$", part)
                if not m:
                    break
                items.append((m.group(1), None, []))
                part = m.group(2).strip()
            if not part:
                continue
            mn, _, rest = part.partition(" ")
            args = [a.strip() for a in rest.split(",")] if rest.strip() else []
            mn = mn.lower()
            if mn == "nop":
                n = int(args[0]) if args else 1
                items.extend([(None, "nop", [])] * n)
            else:
                items.append((None, mn, args))
    return items


def assemble(text):
    items = split_lines(text)
    labels, pc = {}, 0
    for lab, mn, _ in items:
        if mn is None:
            labels[lab] = pc
        else:
            pc += 4

    def imm(tok):
        tok = tok.strip()
        if tok in labels:
            return labels[tok]
        return int(tok, 0)

    words, pc = [], 0
    for lab, mn, a in items:
        if mn is None:
            continue
        if mn == "nop":
            w = 0
        elif mn == "halt":
            w = (0x02 << 26) | ((pc >> 2) & 0x3FFFFFF)
        elif mn in R3:
            w = (reg(a[1]) << 21) | (reg(a[2]) << 16) | (reg(a[0]) << 11) | R3[mn]
        elif mn in RSHV:  # sllv rd, rt, rs
            w = (reg(a[2]) << 21) | (reg(a[1]) << 16) | (reg(a[0]) << 11) | RSHV[mn]
        elif mn in RSH:  # sll rd, rt, shamt
            w = (reg(a[1]) << 16) | (reg(a[0]) << 11) | ((imm(a[2]) & 31) << 6) | RSH[mn]
        elif mn == "jr":
            w = (reg(a[0]) << 21) | 0x08
        elif mn == "jalr":  # jalr rd, rs  |  jalr rs  (rd = $ra)
            rd, rs = (reg(a[0]), reg(a[1])) if len(a) == 2 else (31, reg(a[0]))
            w = (rs << 21) | (rd << 11) | 0x09
        elif mn in IALU:
            v = imm(a[2])
            w = (IALU[mn] << 26) | (reg(a[1]) << 21) | (reg(a[0]) << 16) | (v & 0xFFFF)
        elif mn == "lui":
            w = (0x0F << 26) | (reg(a[0]) << 16) | (imm(a[1]) & 0xFFFF)
        elif mn in MEMOP:  # lw rt, off(rs)
            m = re.match(r"^(.*)\((\$\w+)\)$", a[1].replace(" ", ""))
            off = imm(m.group(1)) if m.group(1) else 0
            w = (MEMOP[mn] << 26) | (reg(m.group(2)) << 21) | (reg(a[0]) << 16) | (off & 0xFFFF)
        elif mn in BR:
            off = (imm(a[2]) - (pc + 4)) // 4
            w = (BR[mn] << 26) | (reg(a[0]) << 21) | (reg(a[1]) << 16) | (off & 0xFFFF)
        elif mn in ("j", "jal"):
            w = ((0x02 if mn == "j" else 0x03) << 26) | ((imm(a[0]) >> 2) & 0x3FFFFFF)
        else:
            raise ValueError(f"unknown instruction {mn!r}")
        words.append(w & 0xFFFFFFFF)
        pc += 4
    return words, labels


def to_mem(words, pad=0):
    words = list(words) + [0] * max(0, pad - len(words))
    return "".join(f"{w:08x}\n" for w in words)


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    words, _ = assemble(open(src).read())
    open(dst, "w").write(to_mem(words))
