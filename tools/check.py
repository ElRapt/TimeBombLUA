#!/usr/bin/env python3
"""Static distribution checks; deliberately not a WoW compatibility claim."""
from pathlib import Path
import re, struct, json, zipfile
from lupa.lua51 import LuaRuntime
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
addon=ROOT/'TimeBombRP'
lua=LuaRuntime(unpack_returned_tuples=True)
compile_lua=lua.eval('function(text,name) local f,e=loadstring(text,name); return f~=nil,e end')
toc=(addon/'TimeBombRP.toc').read_text()
entries=[line.replace('\\','/') for line in toc.splitlines() if line and not line.startswith('#')]
assert '## Interface: 120105' in toc
assert entries[0]=='Core/Util.lua' and entries[-1]=='Core/Main.lua'
assert len(entries)==len(set(entries))
for name in entries: assert (addon/name).is_file(),name
for path in sorted(addon.rglob('*.lua')):
    text=path.read_text()
    ok,err=compile_lua(text,str(path))
    assert ok,err
    assert not re.search(r'\b(?:loadstring|dofile|loadfile|InviteUnit)\s*\(',text),path
    if "SendChatMessage" in text:
        assert path.relative_to(addon).as_posix()=="Core/Main.lua",path
    assert path.relative_to(addon).as_posix() in entries,path
textures=list((addon/'Assets').glob('*.tga'))
expected={'card_back','card_safe','card_defuse','card_bomb','emblem_defuser','emblem_saboteur','pliers','chest','table','ornament','progress_on','progress_off'}
assert expected<={p.stem for p in textures},'missing runtime art'
for path in textures:
    data=path.read_bytes()
    typ=data[2]; w,h=struct.unpack_from('<HH',data,12)
    assert typ==2 and data[16]==32 and data[17]&15==8,(path,'uncompressed RGBA')
    assert w>0 and h>0 and w&(w-1)==0 and h&(h-1)==0,path
    assert len(data)>=18+w*h*4,path
    im=Image.open(path); assert im.mode=='RGBA' and im.size==(w,h)
    if path.stem!='table': assert im.getchannel('A').getextrema()[0]==0,(path,'missing transparency')
card_sizes={Image.open(addon/'Assets'/f'{name}.tga').size for name in expected if name.startswith('card_')}
assert len(card_sizes)==1
for path in addon.rglob('*.lua'):
    for asset in re.findall(r'Assets\\\\([a-z_]+)\.tga',path.read_text()): assert asset in expected,asset
print(f'PASS Lua 5.1 syntax, TOC order, {len(entries)} modules, {len(textures)} RGBA/POT textures, standalone runtime')

archive=ROOT/'dist'/'TimeBombRP-1.1.0.zip'
if archive.exists():
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert all(n.startswith('TimeBombRP/') for n in z.namelist())
        for name in entries+['TimeBombRP.toc']:
            assert z.read('TimeBombRP/'+name)==(addon/name).read_bytes(),('stale archive',name)
        for path in textures:
            assert z.read('TimeBombRP/Assets/'+path.name)==path.read_bytes()
        assert not any('/Sources/' in n for n in z.namelist())
    print('PASS installable ZIP root, modules, textures and exact current bytes')
