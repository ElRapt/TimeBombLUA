#!/usr/bin/env python3
"""Build the original TimeBombRP art set. Python 3 + Pillow; no network needed.

AI-painted source props are versioned in Assets/Sources. Small ornaments, cable
illustrations and role badges are original deterministic drawing code below.
No third-party game art or fonts are embedded. Runtime files are ready to use.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import struct
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "TimeBombRP" / "Assets"
SOURCES = ASSETS / "Sources"
SCALE = 4
BRASS = (182, 136, 67, 255)
GOLD = (234, 196, 118, 255)
DARK = (38, 24, 18, 255)
IVORY = (242, 224, 181, 255)


class Canvas:
    def __init__(self, width=128, height=128):
        self.im = Image.new("RGBA", (width * SCALE, height * SCALE))
        self.draw = ImageDraw.Draw(self.im)

    def box(self, p):
        return tuple(round(v * SCALE) for v in p)

    def line(self, points, fill, width=1):
        self.draw.line([self.box(p) for p in points], fill=fill,
                       width=max(1, round(width * SCALE)), joint="curve")

    def polygon(self, points, fill, outline=None, width=1):
        pts = [self.box(p) for p in points]
        self.draw.polygon(pts, fill=fill)
        if outline:
            self.draw.line(pts + pts[:1], fill=outline,
                           width=max(1, round(width * SCALE)), joint="curve")

    def ellipse(self, box, fill=None, outline=None, width=1):
        self.draw.ellipse(self.box(box), fill=fill, outline=outline,
                          width=max(1, round(width * SCALE)))

    def rounded(self, box, radius, fill=None, outline=None, width=1):
        self.draw.rounded_rectangle(self.box(box), round(radius * SCALE),
                                    fill=fill, outline=outline,
                                    width=max(1, round(width * SCALE)))

    def curve(self, points, color, width=1):
        # Cubic Bezier tessellation, deterministic and resolution independent.
        p0, p1, p2, p3 = points
        path = []
        for i in range(61):
            t = i / 60
            u = 1 - t
            path.append(tuple(u**3 * p0[j] + 3*u*u*t*p1[j] +
                              3*u*t*t*p2[j] + t**3*p3[j] for j in (0, 1)))
        self.line(path, color, width)

    def result(self):
        return self.im.resize((self.im.width // SCALE, self.im.height // SCALE),
                              Image.Resampling.LANCZOS)


def metal_line(c, points, width=5, color=BRASS):
    c.line([(x+1.0, y+1.3) for x, y in points], (13, 10, 9, 230), width+3)
    c.line(points, (89, 58, 31, 255), width+1)
    c.line(points, color, width)
    c.line([(x-0.45, y-0.65) for x, y in points], GOLD, max(0.7, width*0.2))


def rivet(c, x, y, radius=3):
    c.ellipse((x-radius-1, y-radius-1, x+radius+1, y+radius+1), DARK)
    c.ellipse((x-radius, y-radius, x+radius, y+radius), BRASS)
    c.ellipse((x-radius+0.6, y-radius+0.6, x+radius-1, y+radius-1), GOLD)
    c.line([(x-radius*0.4, y+radius*0.4), (x+radius*0.4, y-radius*0.4)],
           (118, 81, 42, 255), 0.65)


def gear(c, x, y, r, teeth=12, inner=None):
    points = []
    for j in range(teeth*4):
        a = j * math.pi * 2 / (teeth*4)
        rr = r if j % 4 in (1, 2) else r*0.89
        points.append((x+math.sin(a)*rr, y+math.cos(a)*rr))
    c.polygon(points, BRASS, DARK, 1.4)
    c.ellipse((x-r*.78, y-r*.78, x+r*.78, y+r*.78), inner or DARK, GOLD, 1.2)
    c.ellipse((x-r*.68, y-r*.68, x+r*.68, y+r*.68), None, (99, 68, 39, 255), 1)


def leaf(c, x, y, size=1, flip=1):
    for d in (-1, 1):
        c.curve([(x, y), (x+d*20*size, y-14*size*flip),
                 (x+d*20*size, y-32*size*flip), (x+d*5*size, y-20*size*flip)],
                BRASS, 1)
        c.curve([(x+d*9*size, y-13*size*flip), (x+d*23*size, y-14*size*flip),
                 (x+d*20*size, y-22*size*flip), (x+d*9*size, y-13*size*flip)],
                GOLD, 0.65)


def card_alpha():
    c = Canvas(128, 256)
    c.rounded((6, 7, 122, 249), 10, (255,255,255,255))
    return c.result().getchannel("A")


def card_surface(back=False):
    c = Canvas(128, 256)
    base = Image.new("RGBA", (128,256))
    pix = base.load()
    rnd = random.Random(70811)
    for y in range(256):
        for x in range(128):
            edge = min(x, 127-x, y/2, (255-y)/2) / 64
            grain = rnd.randrange(-5, 6)
            if back:
                rgb = (41+18*edge, 19+5*edge, 20+6*edge)
            else:
                rgb = (153+56*edge, 125+53*edge, 84+47*edge)
            pix[x,y] = tuple(max(0,min(255, int(z+grain))) for z in rgb)+(255,)
    c.im = base.resize((128*SCALE,256*SCALE),Image.Resampling.BICUBIC)
    c.draw = ImageDraw.Draw(c.im)
    c.rounded((7,8,121,248), 10, None, (37,22,15,255), 7)
    c.rounded((9,10,119,246), 8, None, BRASS, 1.2)
    c.rounded((13,14,115,242), 6, None, (86,57,32,255), 2.1)
    c.rounded((16,17,112,239), 4, None, GOLD, 0.55)
    for x in (16, 112):
        for y in (19,237):
            rivet(c,x,y,1.7)
    for y, flip in ((59,1), (197,-1)):
        leaf(c,64,y,.69,flip)
        c.polygon([(60,y-4*flip),(64,y-12*flip),(68,y-4*flip),(64,y)], BRASS)
    c.line([(28,62),(49,62)],BRASS,.7)
    c.line([(79,62),(100,62)],BRASS,.7)
    c.line([(28,194),(49,194)],BRASS,.7)
    c.line([(79,194),(100,194)],BRASS,.7)
    return c


def cable(c, kind, x=64, y=127, factor=1):
    # Color is redundant: safe has a parted loop, defuse a check/spark seal,
    # bomb a distinctive round clockwork trigger and flaring fuse.
    if kind == "safe":
        path1=[(x-29,y-36),(x-50,y-7),(x-19,y+28),(x-8,y+2)]
        path2=[(x+8,y-2),(x+19,y-28),(x+50,y+7),(x+29,y+36)]
        for points in (path1,path2):
            c.curve(points,(46,34,24,255),12)
            c.curve(points,(105,108,99,255),8)
            c.curve([(px-1,py-1) for px,py in points],(226,227,198,255),2)
        for xx, yy in ((x-8,y+2),(x+8,y-2)):
            c.ellipse((xx-5,yy-5,xx+5,yy+5),BRASS,DARK,1)
            c.ellipse((xx-2,yy-2,xx+2,yy+2),DARK)
        c.line([(x-3,y-14),(x+3,y-9)],IVORY,2)
        c.line([(x-3,y+9),(x+3,y+14)],IVORY,2)
    elif kind == "defuse":
        gear(c,x,y,37,12,(40,74,63,255))
        c.ellipse((x-23,y-23,x+23,y+23),None,(105,162,130,255),1.2)
        metal_line(c,[(x-18,y),(x-5,y+13),(x+19,y-15)],7,IVORY)
        c.polygon([(x,y-54),(x+4,y-44),(x,y-37),(x-4,y-44)],GOLD)
        c.polygon([(x,y+54),(x+4,y+44),(x,y+37),(x-4,y+44)],GOLD)
    elif kind == "bomb":
        c.curve([(x+5,y-32),(x+34,y-59),(x+45,y-30),(x+32,y-54)],DARK,7)
        c.curve([(x+5,y-32),(x+34,y-59),(x+45,y-30),(x+32,y-54)],(195,119,64,255),3)
        for j in range(8):
            a=j*math.pi/4
            c.line([(x+32+math.sin(a)*5,y-54+math.cos(a)*5),
                    (x+32+math.sin(a)*11,y-54+math.cos(a)*11)],GOLD,1.6)
        c.rounded((x-12,y-35,x+12,y-22),3,BRASS,DARK,2)
        c.ellipse((x-35,y-27,x+35,y+43),(39,32,29,255),DARK,3)
        c.ellipse((x-32,y-25,x+32,y+39),(62,43,36,255),BRASS,1.5)
        c.ellipse((x-27,y-20,x+27,y+34),(83,38,35,255),(146,83,49,255),2)
        gear(c,x,y+7,22,8,(42,27,24,255))
        c.polygon([(x,y-8),(x+13,y+16),(x-13,y+16)],(219,103,72,255),GOLD,1)
        c.rounded((x-1.5,y-1,x+1.5,y+7),1,IVORY)
        c.ellipse((x-1.5,y+10,x+1.5,y+13),IVORY)
        for xx, yy in ((x-24,y-7),(x+25,y+25)):
            rivet(c,xx,yy,2.5)


def make_card(kind):
    c=card_surface(kind=="back")
    if kind=="back":
        c.polygon([(64,75),(102,128),(64,181),(26,128)],(80,37,36,255),BRASS,1.1)
        c.polygon([(64,85),(94,128),(64,171),(34,128)],None,GOLD,.6)
        gear(c,64,128,30,12,(52,26,24,255))
        for j in range(8):
            a=j*math.pi/4
            rr=25 if j%2==0 else 18
            c.polygon([(64+math.sin(a)*rr,128+math.cos(a)*rr),
                       (64+math.sin(a+.45)*9,128+math.cos(a+.45)*9),
                       (64+math.sin(a-.45)*9,128+math.cos(a-.45)*9)],GOLD,DARK,.6)
        rivet(c,64,128,7)
    else:
        cable(c,kind)
    result=c.result()
    result.putalpha(card_alpha())
    return result


def medallion(kind):
    c=Canvas()
    for side in (-1,1):
        c.polygon([(64+side*20,71),(64+side*37,114),
                   (64+side*24,106),(64+side*14,119),(64+side*6,80)],
                  (79,30,33,255),BRASS,1.1)
    gear(c,64,59,46,16,(33,37,31,255) if kind=="defuser" else (61,27,28,255))
    c.ellipse((28,23,100,95),None,GOLD,1)
    if kind=="defuser":
        c.polygon([(64,27),(88,36),(85,65),(76,79),(64,87),(52,79),(43,65),(40,36)],
                  (46,84,67,255),GOLD,1.8)
        metal_line(c,[(50,56),(61,68),(80,44)],5,IVORY)
    else:
        # An impish mechanical theatrical mask: role emblem, not character lore.
        c.polygon([(38,41),(50,45),(64,39),(78,45),(90,41),(85,69),
                   (76,79),(64,73),(52,79),(43,69)],(91,48,38,255),GOLD,1.8)
        c.polygon([(45,50),(58,55),(55,62),(47,59)],IVORY,DARK,1)
        c.polygon([(83,50),(70,55),(73,62),(81,59)],IVORY,DARK,1)
        c.line([(58,67),(64,69),(70,67)],GOLD,1.6)
        c.polygon([(48,39),(40,23),(61,36)],BRASS,DARK,1)
        c.polygon([(80,39),(88,23),(67,36)],BRASS,DARK,1)
    return c.result()


def progress(on):
    c=Canvas()
    gear(c,64,64,47,12,(24,31,26,255))
    c.ellipse((30,30,98,98),(54,86,58,255) if on else (34,31,25,255),GOLD,1.5)
    if on:
        c.ellipse((36,36,92,92),(88,139,84,255),(148,175,104,255),1)
        metal_line(c,[(44,65),(58,80),(86,47)],8,IVORY)
    else:
        c.ellipse((39,39,89,89),None,(88,76,50,255),2)
        c.ellipse((58,58,70,70),(116,91,53,255))
    return c.result()


def ornament():
    c=Canvas()
    c.polygon([(64,44),(75,64),(64,84),(53,64)],BRASS,DARK,1)
    c.polygon([(64,51),(70,64),(64,77),(58,64)],GOLD)
    for flip in (-1,1):
        for sign in (-1,1):
            c.curve([(64,64),(64+sign*22,64+flip*27),
                     (64+sign*60,64+flip*5),(64+sign*43,64)],BRASS,2)
            c.curve([(64+sign*21,64+flip*10),(64+sign*43,64+flip*27),
                     (64+sign*43,64+flip*5),(64+sign*21,64+flip*10)],GOLD,1)
            c.curve([(64+sign*32,64+flip*4),(64+sign*67,64+flip*2),
                     (64+sign*52,64+flip*24),(64+sign*49,64+flip*11)],BRASS,1)
    return c.result()


def fit_source(name,size,padding=10):
    src=Image.open(SOURCES/(name+"_painted.png")).convert("RGBA")
    if name=="table":
        return src.resize(size,Image.Resampling.LANCZOS)
    bbox=src.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Empty source alpha")
    src=src.crop(bbox)
    src.thumbnail((size[0]-padding*2,size[1]-padding*2),Image.Resampling.LANCZOS)
    out=Image.new("RGBA",size)
    out.alpha_composite(src,((size[0]-src.width)//2,(size[1]-src.height)//2))
    return out


def write_tga(path, image):
    image=image.convert("RGBA")
    # True-color, uncompressed, BGRA, top-left origin, eight alpha bits.
    header=struct.pack("<BBBHHBHHHHBB",0,0,2,0,0,0,0,0,image.width,image.height,32,0x28)
    path.write_bytes(header+image.tobytes("raw","BGRA"))


def verify():
    manifest=json.loads((ASSETS/"manifest.json").read_text())
    alphas=[]
    for entry in manifest["textures"]:
        path=ASSETS/entry["file"]
        raw=path.read_bytes()
        h=struct.unpack("<BBBHHBHHHHBB",raw[:18])
        w,ht=h[8],h[9]
        assert h[0:3]==(0,0,2),path
        assert h[10:12]==(32,0x28),path
        assert [w,ht]==entry["dimensions"],path
        assert w&(w-1)==0 and ht&(ht-1)==0,path
        assert len(raw)==18+w*ht*4,path
        assert hashlib.sha256(raw).hexdigest()==entry["sha256"],path
        image=Image.open(path).convert("RGBA")
        assert image.tobytes("raw","BGRA")==raw[18:],"TGA orientation mismatch"
        alpha=image.getchannel("A")
        if path.stem!="table":
            assert alpha.getextrema()==(0,255),path
            assert alpha.getpixel((0,0))==0 and alpha.getpixel((w-1,ht-1))==0,path
        if path.stem.startswith("card_"):
            alphas.append(alpha.tobytes())
    assert len(alphas)==4 and len(set(alphas))==1,"Card silhouette differs"
    print("Assets verified: %d uncompressed BGRA32 POT textures, top-left orientation, alpha, SHA-256, identical card silhouettes."%len(manifest["textures"]))


def contact_sheet(images):
    out=Image.new("RGB",(1100,920),(22,18,17))
    d=ImageDraw.Draw(out)
    try:
        title=ImageFont.truetype("DejaVuSans.ttf",24)
        font=ImageFont.truetype("DejaVuSans.ttf",15)
        small=ImageFont.truetype("DejaVuSans.ttf",12)
    except OSError:
        title=font=small=ImageFont.load_default()
    d.text((32,24),"TIME BOMB RP / ORIGINAL TEXTURE SET",font=title,fill=(238,217,174))
    d.text((32,59),"Asset contact sheet · not a WoW capture · alpha shown on charcoal",font=font,fill=(154,140,122))
    for i,k in enumerate(("card_back","card_safe","card_defuse","card_bomb")):
        x=40+i*168
        out.paste(images[k],(x,96),images[k])
        d.text((x,363),k,font=font,fill=(225,207,167))
        d.text((x,386),"128 × 256 / RGBA",font=small,fill=(148,136,117))
    for k,xy in (("chest",(750,95)),("pliers",(755,368))):
        im=images[k].copy();im.thumbnail((235,235),Image.Resampling.LANCZOS)
        out.paste(im,xy,im)
        d.text((xy[0],xy[1]+240),k,font=font,fill=(225,207,167))
    for i,k in enumerate(("emblem_defuser","emblem_saboteur","progress_on","progress_off","ornament")):
        x=30+i*136
        im=images[k]
        out.paste(im,(x,439),im)
        d.text((x,575),k,font=small,fill=(225,207,167))
    table=images["table"].resize((1024,256),Image.Resampling.LANCZOS)
    out.paste(table,(32,625),table)
    d.text((40,889),"table · 1024 × 512 (compressed vertically in this contact sheet)",font=small,fill=(172,156,132))
    (ROOT/"docs").mkdir(exist_ok=True)
    out.save(ROOT/"docs"/"assets-preview.png")


def build():
    ASSETS.mkdir(parents=True,exist_ok=True)
    images={"card_"+k:make_card(k) for k in ("back","safe","defuse","bomb")}
    images.update({"emblem_"+k:medallion(k) for k in ("defuser","saboteur")})
    images.update({"progress_on":progress(True),"progress_off":progress(False),
                   "ornament":ornament(),"chest":fit_source("chest",(256,256),14),
                   "pliers":fit_source("pliers",(256,256),12),
                   "table":fit_source("table",(1024,512),0)})
    entries=[]
    for name,im in images.items():
        path=ASSETS/(name+".tga")
        write_tga(path,im)
        entries.append({"file":path.name,"dimensions":list(im.size),
                        "format":"TGA type 2; BGRA32; straight alpha; top-left origin",
                        "alpha":"opaque" if name=="table" else "transparent cutout",
                        "provenance":"OpenAI imagegen original painted source; deterministic resize/crop" if name in ("chest","pliers","table") else "Original procedural illustration in tools/assets_build.py",
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    manifest={"name":"TimeBombRP original art set","version":"1.0.0",
              "runtime_root":"Interface\\AddOns\\TimeBombRP\\Assets\\",
              "license":"Original project artwork; see Assets/README.md",
              "build":"python3 tools/assets_build.py",
              "verify":"python3 tools/assets_build.py --verify",
              "generated_source_prompts":["Sources/prompts.json","Sources/pliers_prompt.json"],
              "textures":entries}
    (ASSETS/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    contact_sheet(images)
    verify()


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify",action="store_true",help="Verify only; do not rebuild")
    args=parser.parse_args()
    verify() if args.verify else build()
