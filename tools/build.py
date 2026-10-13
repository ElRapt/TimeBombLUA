#!/usr/bin/env python3
"""Deterministic installable zip: sources remain in git, runtime has no build step."""
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'dist'/'TimeBombRP-1.0.0.zip'
OUT.parent.mkdir(exist_ok=True)
files=[]
for path in sorted((ROOT/'TimeBombRP').rglob('*')):
    if path.is_file() and 'Sources' not in path.parts:
        files.append((path,path.relative_to(ROOT).as_posix()))
for path in sorted((ROOT/'docs').glob('*')):
    if path.suffix in {'.md','.png'} and path.name!='CONTRACT.md':
        files.append((path,'TimeBombRP/docs/'+path.name))
for name in ['README.md','RULES.md','LICENSE']:
    files.append((ROOT/name,'TimeBombRP/'+name))
with zipfile.ZipFile(OUT,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
    for path,name in files:
        info=zipfile.ZipInfo(name,date_time=(2026,10,13,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED; info.external_attr=0o100644<<16
        archive.writestr(info,path.read_bytes())
with zipfile.ZipFile(OUT) as archive:
    assert archive.testzip() is None
    assert 'TimeBombRP/TimeBombRP.toc' in archive.namelist()
    assert all(n.startswith('TimeBombRP/') for n in archive.namelist())
print(OUT,OUT.stat().st_size,'bytes')
