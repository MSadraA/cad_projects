"""Generate interface, hierarchy, plans and exact-signal diagrams from RTL.

--check compares generated sources without changing files or requiring Graphviz.
--render also creates SVG and PNG images with the local 'dot' executable.
The parser covers this project's named-port/parameter Verilog style; it is not
a replacement for a compiler. Every named instance port is validated first.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parens(text: str, start: int) -> tuple[str, int]:
    depth = 0
    quoted = False
    for index in range(start, len(text)):
        char = text[index]
        if char == '"' and (index == 0 or text[index-1] != '\\'):
            quoted = not quoted
        if quoted:
            continue
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return text[start+1:index], index+1
    raise ValueError('Unbalanced module/instance header')


def named_connections(text: str) -> dict[str, str]:
    result = {}
    pos = 0
    while match := re.search(r'\.(\w+)\s*\(', text[pos:]):
        name = match.group(1)
        opening = pos + match.end()-1
        value, end = parens(text, opening)
        if name in result:
            raise ValueError(f'Duplicate connection {name}')
        result[name] = value.strip()
        pos = end
    return result


def parse_interface(original: str) -> dict:
    """Read ANSI or non-ANSI ports and reject forward width declarations.

    ModelSim 2020's Verilog parser requires derived constants to be visible
    when it reads a port range. In non-ANSI modules they precede the typed
    port declarations, without adding overridable width parameters.
    """
    clean = re.sub(r'/\*.*?\*/|//[^\n]*', '', original, flags=re.S)
    declarations = list(re.finditer(r'\bmodule\s+(\w+)\s*', clean))
    if len(declarations) != 1:
        raise ValueError('Expected exactly one module')
    match = declarations[0]
    name = match.group(1)
    pos = match.end()
    parameters = ''
    if clean[pos] == '#':
        parameters, pos = parens(clean, clean.index('(', pos))
    header, end = parens(clean, clean.index('(', pos))
    port_pattern = r'\b(input|output)\s+(?:(?:wire|reg)\s+)?(\[[^\]]+\])?\s*(\w+)'
    ports = {}
    positions = {}
    if re.search(r'\b(input|output)\b', header):
        style = 'ansi'
        opening = clean.index('(', pos)
        for port in re.finditer(port_pattern, header):
            key = port.group(3)
            ports[key] = {'direction': port.group(1), 'width': (port.group(2) or '1 bit').strip()}
            positions[key] = opening + 1 + port.start()
        interface_end = clean.index(';', end) + 1
    else:
        style = 'non_ansi'
        order = [item.strip() for item in header.split(',')]
        if len(order) != len(set(order)) or not all(re.fullmatch(r'\w+', item) for item in order):
            raise ValueError(f'{name}: invalid non-ANSI port identifier list')
        declarations_end = end
        for port in re.finditer(port_pattern+r'\s*;', clean[end:]):
            key = port.group(3)
            if key not in order:
                continue
            if key in ports:
                raise ValueError(f'{name}: duplicate typed declaration of {key}')
            ports[key] = {'direction': port.group(1), 'width': (port.group(2) or '1 bit').strip()}
            positions[key] = end + port.start()
            declarations_end = max(declarations_end, end + port.end())
        if set(ports) != set(order):
            raise ValueError(f'{name}: missing typed port declarations')
        ports = {key: ports[key] for key in order}
        interface_end = declarations_end
        # Export only module-level constants and port declarations. A generate
        # localparam such as LEAF_INDEX=k-LEAVES must never escape its scope.
        prefix = clean[end:interface_end]
        prefix = re.sub(r'\blocalparam\b[^;]+;', '', prefix)
        prefix = re.sub(port_pattern+r'\s*;', '', prefix)
        if prefix.strip(' \t\r\n;'):
            raise ValueError(f'{name}: operational code precedes the interface declarations')
    if not ports:
        raise ValueError(f'{name}: no ports parsed')
    constant_positions = {}
    for declaration in re.finditer(r'\blocalparam\b[^;]+;', clean):
        for constant in re.finditer(r'\b(\w+)\s*=', declaration.group(0)):
            constant_positions.setdefault(constant.group(1), declaration.start())
    for key, info in ports.items():
        for symbol in re.findall(r'\b\w+\b', info['width']):
            if symbol in constant_positions and constant_positions[symbol] > positions[key]:
                raise ValueError(f'{name}.{key}: width {symbol} is used before its declaration (ModelSim compatibility)')
    return {'name': name, 'clean': clean, 'parameters': parameters, 'ports': ports,
            'body_start': end, 'port_style': style,
            'interface_source': clean[match.start():interface_end]+'\nendmodule\n'}


def parse_modules() -> dict:
    modules = {}
    for path in sorted((ROOT / 'rtl').glob('*.v')):
        original = path.read_text(encoding='utf-8')
        interface = parse_interface(original)
        clean = interface['clean']
        name = interface['name']
        if name in modules or path.stem != name:
            raise ValueError(f'Duplicate or mismatched module/file name: {name}')
        parameters = interface['parameters']
        ports = interface['ports']
        end = interface['body_start']
        param_names = re.findall(r'\b(\w+)\s*=', parameters)
        if not ports:
            raise ValueError(f'{name}: no ports parsed')
        instances = []
        body = clean[end:]
        for call in re.finditer(r'\b(fcnn_\w+)\s*', body):
            cursor = call.end()
            instance_parameters = {}
            if cursor < len(body) and body[cursor] == '#':
                opening = body.index('(', cursor)
                params, cursor = parens(body, opening)
                instance_parameters = named_connections(params)
            ident = re.match(r'\s*(\w+)\s*\(', body[cursor:])
            if not ident:
                continue
            instance_name = ident.group(1)
            opening = cursor+ident.end()-1
            connections, _ = parens(body, opening)
            instances.append({'module': call.group(1), 'name': instance_name,
                              'parameters': instance_parameters, 'ports': named_connections(connections)})
        functional = re.sub(r'// synthesis translate_off.*?// synthesis translate_on', '', original, flags=re.S)
        steps = []
        seen = set()
        for step in re.finditer(r'//\s*Step\s+(\d+)\s*[:&]?\s*([^\n]*)', original):
            number = int(step.group(1))
            if number not in seen:
                seen.add(number)
                steps.append({'number': number, 'description': step.group(2).strip()})
        modules[name] = {'file': str(path.relative_to(ROOT)), 'parameters': param_names, 'parameter_defaults': {m.group(1):m.group(2).strip() for m in re.finditer(r'(\w+)\s*=\s*("[^"]*"|[^,]+)',parameters)}, 'ports': ports,
                         'port_style': interface['port_style'],
                         'instances': instances, 'steps': steps,
                         'clocked_blocks': len(re.findall(r'always\s*@\(posedge', functional)),
                         'combinational_blocks': len(re.findall(r'always\s*@\(\*\)', functional)),
                         'initial_blocks': len(re.findall(r'\binitial\b', re.sub(r'//[^\n]*', '', functional)))}
    for name, module in modules.items():
        for instance in module['instances']:
            definition = modules[instance['module']]
            if set(instance['ports']) != set(definition['ports']):
                raise ValueError(f'{name}.{instance["name"]}: instance port set differs from its module')
            if set(instance['parameters']) - set(definition['parameters']):
                raise ValueError(f'{name}.{instance["name"]}: invalid parameter override')
    return modules


def hierarchy(modules: dict) -> tuple[list, collections.Counter]:
    rows = []
    counts = collections.Counter()

    def visit(module: str, path: str, parent: str | None, stack: tuple = ()) -> None:
        if module in stack:
            raise ValueError('Recursive module instantiation')
        counts[module] += 1
        rows.append({'path': path, 'module': module, 'parent': parent})
        for instance in modules[module]['instances']:
            visit(instance['module'], path+'.'+instance['name'], path, stack+(module,))
    visit('fcnn_top', 'dut', None)
    if counts['fcnn_fp16_adder'] != 1 or counts['fcnn_fp16_multiplier'] != 1:
        raise ValueError('Assignment requires exactly one FP16 adder and multiplier')
    if set(counts) != set(modules):
        raise ValueError('Unused RTL module exists')
    return rows, counts


STYLE = '''graph [fontname="DejaVu Sans", rankdir=TB, bgcolor="white", pad="0.3", nodesep="0.35", ranksep="0.55", splines=polyline];
node [fontname="DejaVu Sans", fontsize=11, shape=box, style="rounded,filled", fillcolor="#edf3fa", color="#526780", margin="0.15,0.12"];
edge [fontname="DejaVu Sans", fontsize=9, color="#526780", arrowsize=0.7];'''


def graph(label: str, content: str) -> str:
    return 'digraph FCNN {\n'+STYLE+'\nlabel='+json.dumps(label)+'; labelloc=t; fontsize=19;\n'+content+'\n}\n'


def generate_outputs(modules: dict) -> dict[Path, str]:
    rows, counts = hierarchy(modules)
    outputs = {}
    outputs[ROOT/'docs/architecture.json'] = json.dumps({'modules': modules, 'hierarchy': rows,
                                                        'instance_counts': dict(counts)}, indent=2, ensure_ascii=False)+'\n'
    text = '# رابط‌های تولیدشده از RTL\n\nاین فایل را با `python scripts/design_docs.py` به‌روز کنید؛ مبنا خود RTL است.\n\n'
    for name, module in modules.items():
        text += f'## {name}\n\nفایل: `{module["file"]}`؛ تعداد نمونه در Top: {counts[name]}.\n\n'
        text += '| پورت | جهت | عرض اعلام‌شده |\n|---|---|---|\n'
        for port, info in module['ports'].items():
            text += f'| `{port}` | {info["direction"]} | `{info["width"]}` |\n'
        text += '\n'
        plan = f'# برنامه جاری {name}\n\nاین برنامه با طرح بازآرایی `../05_plan.md` و Stepهای نسخه جاری کد همگام است.\n\n'
        plan += f'RTL: `{module["file"]}`؛ نمونه‌ها در hierarchy: {counts[name]}.\n\n'
        plan += f'بلوک‌های عملکردی: {module["clocked_blocks"]} ترتیبی، {module["combinational_blocks"]} ترکیبی، {module["initial_blocks"]} initial. نگهبان‌های شبیه‌سازی در این شمارش عملکردی نیستند.\n\n'
        plan += 'پارامترها: '+(', '.join(f'`{p}`' for p in module['parameters']) or 'ندارد')+'. عرض‌ها و عمق‌های مشتق با localparam محاسبه می‌شوند.\n\n'
        if module['port_style'] == 'non_ansi':
            plan += 'برای سازگاری Verilog-2005 با ModelSim 2020، فهرست پورت‌ها non-ANSI است؛ ثابت‌های مشتق قبل از اعلان نوع و عرض پورت‌ها قرار دارند.\n\n'
        plan += 'تخصیص به ثبات‌ها در لبه کلاک با `<=` و منطق ترکیبی با `assign` یا `=` انجام می‌شود. reset تمام ثبات‌های اعتبار سنکرون و فعال یک است؛ ROMها با reset بازنویسی نمی‌شوند.\n\n'
        for step in module['steps']:
            plan += f'{step["number"]}. {step["description"]}\n'
        if not module['steps']:
            raise ValueError(f'{name}: missing implementation Step comments')
        outputs[ROOT/'docs/plans'/f'{name}.md'] = plan
    outputs[ROOT/'docs/interfaces.md'] = text
    top_defaults=modules['fcnn_top']['parameter_defaults']
    ni,nh,no,lanes,latency=(int(top_defaults[k]) for k in ('N_INPUTS','N_HIDDEN','N_OUTPUTS','LANES','SRAM_LATENCY'))
    child_cells=[]
    dp_children=modules['fcnn_datapath']['instances']
    for offset in range(0,len(dp_children),4):
        cells=[]
        for instance in dp_children[offset:offset+4]:
            cells.append('<TD BGCOLOR="#edf3fa" CELLPADDING="12"><B>'+instance['name']+
                         '</B><BR/><FONT POINT-SIZE="10">'+instance['module']+'</FONT></TD>')
        child_cells.append('<TR>'+''.join(cells)+'</TR>')
    table='<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="8">'+''.join(child_cells)+'</TABLE>'
    parts=['top [label="fcnn_top / dut"];',
           'controller [label="controller_inst / fcnn_controller"];',
           'datapath [label="datapath_inst / fcnn_datapath"];',
           'children [shape=plain, style="", label=<'+table+'>];',
           'top -> controller;top -> datapath;',
           'datapath -> children [label="every cell is a direct child instance"];']
    outputs[ROOT/'docs/diagrams/hierarchy.dot'] = graph(
        f'RTL hierarchy - {len(modules)} module types / {sum(counts.values())} instances', '\n'.join(parts))
    # Selected data edges are mechanically checked against actual named ports.
    dp = {i['name']: i for i in modules['fcnn_datapath']['instances']}
    selected = [
        ('address_inst','weight_sram_inst','weight_addr'),('address_inst','input_sram_inst','input_addr'),
        ('weight_sram_inst','weight_stage_inst','weight_sram_data'),('input_sram_inst','input_stage_inst','input_sram_data'),
        ('weight_stage_inst','router_inst','weight_stage_data'),('input_stage_inst','router_inst','input_stage_data'),
        ('router_inst','multiplier_inst','mul_weight'),('router_inst','multiplier_inst','mul_input'),
        ('multiplier_inst','product_inst','mul_result'),('product_inst','ping_pong_inst','pp_wr_data'),
        ('ping_pong_inst','accumulator_inst','pp_rd_data'),('accumulator_inst','adder_inst','add_a'),
        ('accumulator_inst','adder_inst','add_b'),('adder_inst','accumulator_inst','add_result'),
        ('bias_inst','accumulator_inst','fc1_bias'),('bias_inst','accumulator_inst','fc2_biases'),
        ('accumulator_inst','relu_inst','fc1_final_value'),('relu_inst','regfile_inst','relu_out'),
        ('accumulator_inst','regfile_inst','fc2_results'),('regfile_inst','argmax_inst','logits'),
        ('regfile_inst','router_inst','hidden_rd_data')]
    merged = collections.defaultdict(list)
    for left,right,signal in selected:
        for instance in (left,right):
            if signal not in dp[instance]['ports'].values():
                raise ValueError(f'Diagram edge {signal} not connected to {instance}')
        merged[(left,right)].append(signal)
    parts = []
    for name, instance in dp.items():
        if name=='scheduler_inst':
            continue
        label = instance['module'].removeprefix('fcnn_')
        notes = {'weight_sram_inst':f'raw weights / {latency} stages', 'input_sram_inst':f'raw pixels / {latency} stages',
                 'weight_stage_inst':'one weight row', 'input_stage_inst':'one input row',
                 'ping_pong_inst':f'2 banks x {lanes} words\nread sealed bank only',
                 'accumulator_inst':f'1 FC1 + {no} FC2 accumulators\nproducts, then bias',
                 'regfile_inst':f'{max(nh,no)} shared FP16 registers\nhidden first, logits last',
                 'multiplier_inst':'exactly one FP16 MUL', 'adder_inst':'exactly one FP16 ADD'}
        if name in notes:
            label += '\n'+notes[name]
        color = '#dbf3e8' if name in ('adder_inst','multiplier_inst') else '#edf3fa'
        parts.append(f'{name} [label={json.dumps(label)}, fillcolor="{color}"];')
    parts += ['{rank=same; weight_sram_inst; input_sram_inst;}', '{rank=same; weight_stage_inst; input_stage_inst;}',
              '{rank=same; multiplier_inst; product_inst; ping_pong_inst;}',
              '{rank=same; accumulator_inst; adder_inst; bias_inst;}', '{rank=same; relu_inst; regfile_inst; argmax_inst;}']
    for (left,right), signals in merged.items():
        attrs = 'constraint=false, style=dashed, ' if (left,right) in [('adder_inst','accumulator_inst'),('regfile_inst','router_inst')] else ''
        parts.append(f'{left} -> {right} [{attrs}label={json.dumps(chr(10).join(signals))}];')
    outputs[ROOT/'docs/diagrams/datapath.dot'] = graph(f'Datapath - Top defaults {ni} / {nh} / {no}', '\n'.join(parts))
    controller = (ROOT/'rtl/fcnn_controller.v').read_text()
    case = re.search(r'case \(state\)(.*?)endcase',controller,re.S).group(1)
    states = list(re.finditer(r'\b(IDLE|FC1|FC2|DONE):\s*(.*?)(?=\b(?:IDLE|FC1|FC2|DONE|default):|$)',case,re.S))
    parts = ['reset [shape=point];reset -> IDLE [label="synchronous rst"];',
             'IDLE [label="IDLE\nbusy=0 / done=0\nrun_init=start && !rst"];',
             'FC1 [label="FC1\nbusy=1 / fc1_active=1"];',
             'FC2 [label="FC2\nbusy=1 / fc2_active=1"];',
             'DONE [label="DONE\ndone=1 / busy=0\none cycle"];']
    for state in states:
        source, body = state.groups()
        transition = re.search(r'if \((.*?)\) next_state = (\w+)',body)
        if transition:
            condition,target=transition.groups()
            parts.append(f'{source} -> {target} [label={json.dumps(condition)}];')
            parts.append(f'{source} -> {source} [label={json.dumps("!("+condition+")")}];')
        else:
            target = re.search(r'next_state = (\w+)',body).group(1)
            parts.append(f'{source} -> {target} [label="next clock"];')
    if len(states)!=4:
        raise ValueError('Controller FSM parser requires updating')
    outputs[ROOT/'docs/diagrams/controller_fsm.dot'] = graph('Controller FSM - extracted transitions', '\n'.join(parts))
    outputs[ROOT/'docs/diagrams/backend_fsm.dot'] = graph('Backend protocol - bias_pending control flag', '''
        rankdir=LR;splines=spline;
        PRODUCT [label="PRODUCT\nproduct_ready=1\nADD(acc, product)\nhold unless last accepted"];
        BIAS [label="BIAS_PENDING\nproduct_ready=0\nADD(acc, bias)"];
        PRODUCT:s -> BIAS:s [label="last product accepted",minlen=2];
        BIAS:n -> PRODUCT:n [label="bias committed",constraint=false];
        reset [shape=point];reset -> PRODUCT [label="rst / run_init"];
    ''')
    return outputs


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--render',action='store_true')
    args=parser.parse_args()
    outputs=generate_outputs(parse_modules())
    for path, text in outputs.items():
        if args.check:
            if not path.is_file() or path.read_text(encoding='utf-8')!=text:
                raise ValueError(f'Stale generated document: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(text,encoding='utf-8')
    if args.render and not args.check:
        for path in outputs:
            if path.suffix=='.dot':
                for kind in ('svg','png'):
                    subprocess.run(['dot',f'-T{kind}',str(path),'-o',str(path.with_suffix('.'+kind))],check=True)
    print('PASS: RTL ports, one-MUL/one-ADD hierarchy, plans and diagram source consistency')
    return 0


if __name__=='__main__':
    raise SystemExit(main())
