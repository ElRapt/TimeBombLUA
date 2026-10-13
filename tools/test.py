#!/usr/bin/env python3
"""Run addon tests on a genuine Lua 5.1 VM via lupa; no WoW client implied."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
ns = lua.table()
ns.TestRoot = str(ROOT)
for file in ['Core/Util.lua', 'Rules/Engine.lua', 'Protocol/Codec.lua', 'Transport/Wire.lua', 'Session/Manager.lua', 'Core/Demo.lua']:
    path = ROOT / 'TimeBombRP' / file
    if path.exists():
        lua.execute(path.read_text(), 'TimeBombRP', ns)
counts = {'passed': 0, 'failed': 0}
def test(name, fn):
    try:
        fn()
        counts['passed'] += 1
        print('PASS', name)
    except Exception as error:
        counts['failed'] += 1
        print('FAIL', name, '\n', error)
for path in sorted((ROOT / 'Tests').glob('test_*.lua')):
    suite = lua.execute(path.read_text())
    suite(ns, test)
print(f"\n{counts['passed']} passed; {counts['failed']} failed (Lua 5.1)")
sys.exit(bool(counts['failed']))
