#!/usr/bin/env python3
"""Approximate raster of actual UI calls under the test double, NOT a WoW capture.
Text metrics/texture layering differ from native WoW; intended for layout review.
"""
from pathlib import Path
import math
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

def preview(count, hover=False):
    lua=LuaRuntime(unpack_returned_tuples=True)
    ns=lua.table()
    mock=lua.execute((ROOT/'Tests/wow_mock.lua').read_text())
    for module in ['Core/Util.lua','Localization/Locale.lua','Core/Roleplay.lua','Rules/Engine.lua','Protocol/Codec.lua','Transport/Wire.lua','Session/Manager.lua','UI/Theme.lua','UI/UI.lua','Core/Demo.lua']:
        lua.execute((ROOT/'TimeBombRP'/module).read_text(),'TimeBombRP',ns)
    lua.globals().NS=ns
    lua.globals().COUNT=count
    ui=lua.execute("local d=NS.Demo.New(COUNT,function() end,function() end); local c={id=d.clients[1].id,isDemo=true,transportStatus='CONNECTED'};local u=NS.UI.New(c,{scale=1});u:Render(d.clients[1]:GetView(),'SNAPSHOT');u:Show();return u")
    if hover:
        lua.globals().PREVIEW_UI=ui
        lua.execute('PREVIEW_UI.seats[1].cards[1]:Fire("OnEnter")')
    objects=list(mock.objects.values())
    # Lua objects are keyed by their creation index for stable identity in Python.
    for i,o in enumerate(objects):o['_i']=i
    cache={}
    def size(o):
        if o['allPoints']:return size(o['allPoints'])
        return float(o['w'] or 0),float(o['h'] or 0)
    def point(x,y,w,h,anchor):
        anchor=anchor or 'CENTER'
        return (x if 'LEFT' in anchor else x+w if 'RIGHT' in anchor else x+w/2,
                y if 'TOP' in anchor else y+h if 'BOTTOM' in anchor else y+h/2)
    def rect(o):
        idx=o['_i']
        if idx in cache:return cache[idx]
        if o['allPoints']:return rect(o['allPoints'])
        w,h=size(o);parent=o['parent']
        pts=list(o['points'].values())
        if not parent:res=(0,0,w,h)
        elif not pts:res=(*rect(parent)[:2],w,h)
        else:
            pts=list(pts[0].values());anchor=pts[0]
            if len(pts)>1 and lua.eval('type')(pts[1])=='table':
                rel=pts[1];ra=pts[2] if len(pts)>2 else anchor;dx=pts[3] if len(pts)>3 else 0;dy=pts[4] if len(pts)>4 else 0
            else:
                rel=parent;ra=anchor;dx=pts[1] if len(pts)>1 else 0;dy=pts[2] if len(pts)>2 else 0
            rx,ry=point(*rect(rel),ra);ox,oy=point(0,0,w,h,anchor)
            res=(rx+float(dx)-ox,ry-float(dy)-oy,w,h)
        cache[idx]=res;return res
    def visible(o):return bool(o['shown']) and (not o['parent'] or visible(o['parent']))
    def alpha(o):return float(o['alpha'] or 1)*(alpha(o['parent']) if o['parent'] else 1)
    def level(o):
        if o['kind'] in ['Texture','FontString']:return level(o['parent'])
        return float(o['level']) if o['level'] is not None else (level(o['parent'])+1 if o['parent'] else 1)
    def rgba(color,a=1):
        c=list(color.values()) if color else [1,1,1,1]
        return tuple(round(max(0,min(1,float(v)))*255) for v in c[:3])+(round((float(c[3]) if len(c)>3 else 1)*a*255),)
    full=Image.new('RGBA',(1400,900),(18,17,21,255))
    layers={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}
    ordered=sorted(objects,key=lambda o:(level(o),layers.get(o['layer'],-1),o['_i']))
    for o in ordered:
        if not visible(o):continue
        if o['kind'] in ['Animation','AnimationGroup']:continue
        x,y,w,h=rect(o);x,y,w,h=map(round,(x,y,w,h));a=alpha(o)
        layer=Image.new('RGBA',full.size);draw=ImageDraw.Draw(layer)
        if o['bg'] and w>0 and h>0:
            draw.rectangle((x,y,x+w-1,y+h-1),fill=rgba(o['bg'],a),outline=rgba(o['border'],a))
        if o['texture'] and w>0 and h>0:
            path=ROOT/'TimeBombRP'/'Assets'/str(o['texture']).split('\\')[-1]
            if path.exists():
                im=Image.open(path).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
                im.putalpha(im.getchannel('A').point(lambda v:round(v*a)));layer.alpha_composite(im,(x,y))
        elif o['fill'] and w>0 and h>0:draw.rectangle((x,y,x+w,y+h),fill=rgba(o['fill'],a))
        if o['text'] and o['kind'] in ['FontString','EditBox']:
            font=ImageFont.truetype(FONT,round(o['fontSize'] or 12))
            text=str(o['text']);lineh=round(o['fontSize'] or 12)+2
            no_wrap=o['SetWordWrapArgs'] and o['SetWordWrapArgs'][1] is False
            lines=[]
            for para in text.split('\n'):
                if no_wrap:
                    while w and font.getlength(para)>w and len(para)>1:para=para[:-2]+'…'
                    lines.append(para)
                else:
                    current=''
                    for word in para.split(' '):
                        if w and font.getlength(current+' '+word)>w and current:lines.append(current);current=word
                        else:current=(current+' '+word).strip()
                    lines.append(current)
            justify=o['SetJustifyHArgs'] and o['SetJustifyHArgs'][1]
            for i,line in enumerate(lines):
                if h and (i+1)*lineh>h+4:break
                tx=x+(w-font.getlength(line))/2 if justify=='CENTER' else x+w-font.getlength(line) if justify=='RIGHT' else x
                draw.text((tx,y+i*lineh),line,font=font,fill=rgba(o['color'],a),stroke_width=0)
        full=Image.alpha_composite(full,layer)
    x,y,w,h=map(round,rect(ui['frame']))
    cropped=full.crop((x-8,y-8,x+w+8,y+h+8))
    out=Image.new('RGBA',(cropped.width,cropped.height+30),(18,17,21,255));out.alpha_composite(cropped,(0,30))
    ImageDraw.Draw(out).text((10,7),'APERÇU HORS JEU — appels UI simulés, rendu approximatif',font=ImageFont.truetype(FONT,12),fill=(218,207,184,255))
    path=ROOT/'docs'/(f'ui-preview-{count}-hover.png' if hover else f'ui-preview-{count}.png');out.convert('RGB').save(path);print(path)
for n in [4,8]:preview(n)
preview(8,hover=True)
