"""生成使用指南的原理示意图与真实渲染缩略图；不生成替代粒子运动。"""
from pathlib import Path
from html import escape
import math

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'doc/assets'
BLUE, TEAL, INK, GRAY, GOLD = '#2563eb', '#0d9488', '#14243a', '#64748b', '#d97706'

class Figure:
    def __init__(self, title, height=420):
        self.height = height
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="{height}" viewBox="0 0 1000 {height}" role="img"><title>{escape(title)}</title><rect width="1000" height="{height}" rx="16" fill="#f4f7fb"/><style>text{{font-family:"PingFang SC","Microsoft YaHei",sans-serif;fill:{INK};font-size:18px}}.small{{font-size:15px;fill:{GRAY}}}.title{{font-size:25px;font-weight:600}}</style>']
        self.text(32, 43, title, cls='title')
    def text(self, x, y, text, cls='', anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{escape(text)}</text>')
    def line(self,x1,y1,x2,y2,color=GRAY,width=2,dash=''):
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}" stroke-dasharray="{dash}"/>')
    def arrow(self,x1,y1,x2,y2,color=BLUE,width=4):
        self.line(x1,y1,x2,y2,color,width)
        a=math.atan2(y2-y1,x2-x1)
        pts=[(x2,y2),(x2-13*math.cos(a)+5*math.sin(a),y2-13*math.sin(a)-5*math.cos(a)),(x2-13*math.cos(a)-5*math.sin(a),y2-13*math.sin(a)+5*math.cos(a))]
        self.polygon(pts,color)
    def polygon(self,points,color,stroke='none',opacity=1):
        p=' '.join(f'{x:.2f},{y:.2f}' for x,y in points)
        self.parts.append(f'<polygon points="{p}" fill="{color}" stroke="{stroke}" opacity="{opacity}"/>')
    def circle(self,x,y,r,color,opacity=1):
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{color}" opacity="{opacity}"/>')
    def path(self,d,color=BLUE,width=4,fill='none'):
        self.parts.append(f'<path d="{d}" fill="{fill}" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
    def box(self,x,y,w,h,title,subtitle,color=BLUE):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="white" stroke="#dbe3ef"/>')
        self.line(x+1,y+15,x+1,y+h-15,color,4)
        self.text(x+15,y+32,title)
        self.text(x+15,y+60,subtitle,'small')
    def save(self,name):
        self.parts.append('</svg>')
        (ASSETS/f'{name}.svg').write_text('\n'.join(self.parts),encoding='utf-8')

f=Figure('01 / 从配方到画面',360)
f.box(32,92,248,85,'ConfettiEffect','seed + 多个发射器')
f.box(372,92,255,85,'ConfettiEmitter','出生时机、位置、初速度')
f.box(716,92,250,85,'ParticleChoice','粒子配方、权重、颜色')
f.arrow(286,133,357,133); f.arrow(637,133,700,133)
f.box(32,238,248,85,'Controller / Simulation','重力 + 风场 + 资源预算',TEAL)
f.box(372,238,255,85,'Camera','米 → 逻辑像素',TEAL)
f.box(716,238,250,85,'View / Painter','材料 + 独立速度色带',TEAL)
f.arrow(840,184,840,211,TEAL);f.line(155,212,840,212,TEAL);f.arrow(155,212,155,231,TEAL)
f.arrow(286,279,357,279,TEAL); f.arrow(637,279,700,279,TEAL)
f.save('configuration-map')

f=Figure('02 / 世界坐标与相机',430)
f.polygon([(70,170),(325,130),(425,282),(160,322)],'#e2e8f0')
f.arrow(230,228,402,228,BLUE);f.text(347,208,'+X 向右')
f.arrow(230,228,230,369,TEAL);f.text(246,365,'+Y 向下')
f.arrow(230,228,103,318,GOLD);f.text(43,352,'+Z 朝相机')
f.circle(230,228,5,INK);f.text(194,203,'原点')
f.line(495,87,495,387,'#dbe3ef')
f.text(545,107,'同样宽度，越靠近相机越大')
for x,y,s,label in [(602,229,26,'z < 0'),(735,226,42,'z = 0'),(882,220,64,'z > 0')]:
    f.polygon([(x-s/2,y-s/2),(x+s/2,y-s/2),(x+s/2,y+s/2),(x-s/2,y+s/2)],BLUE)
    f.text(x,293,label,anchor='middle')
f.text(545,342,'viewHeight 变小 → 整体放大')
f.text(545,376,'相机仅改变投影，不改变物理飞行距离。','small')
f.save('coordinates')

f=Figure('03 / 发射方向与出生时间',460)
f.text(40,98,'spread 是圆锥半角；图为截面示意')
f.polygon([(211,346),(74,143),(348,143)],'#dbeafe')
f.arrow(211,346,211,133,BLUE);f.line(211,346,74,143,TEAL);f.line(211,346,348,143,TEAL)
f.path('M 211 257 A 89 89 0 0 1 262 273',GOLD,3)
f.text(228,244,'spread');f.text(233,145,'direction')
f.circle(211,346,24,TEAL,.16);f.circle(211,346,5,INK);f.text(55,396,'origin + 半径 radius 内的随机起点')
f.line(480,86,480,423,'#dbe3ef')
f.text(533,98,'stream：delay=500ms，rate=4/s，duration=1s')
f.arrow(541,203,947,203,GRAY,2)
for t in [0,.5,.75,1,1.25,1.5,2]:
    x=551+t*181
    f.line(x,197,x,209,GRAY)
    f.text(x,235,str(t),'small','middle')
f.text(924,261,'秒','small')
f.line(551,156,641.5,156,GRAY,5);f.text(574,142,'等待','small')
f.line(641.5,156,822.5,156,TEAL,5);f.text(681,142,'持续出生 1 秒','small')
for t in [.75,1,1.25,1.5]:f.circle(551+t*181,203,6,TEAL)
f.circle(641.5,203,9,BLUE);f.text(537,307,'蓝点：开场 burstCount（可为 0）')
f.text(537,341,'绿点：后续按累计 rate 出生')
f.text(537,385,'每个粒子从自己的出生时刻开始计算 lifetime。','small')
f.text(537,413,'duration 结束 ≠ 所有粒子同时消失。','small')
f.save('emission')

f=Figure('04 / 柔性丝带：材料位置与三种形变',510)
f.path('M70 160 C 170 80 280 230 420 135',TEAL,22)
f.path('M70 160 C 170 80 280 230 420 135','#5eead4',2)
for x,y,label in [(70,160,'u=0 前端'),(248,160,'u=0.5'),(420,135,'u=1 尾部')]:
    f.circle(x,y,5,INK);f.text(x,212,label,anchor='middle')
f.text(490,116,'材料点诊断固定追踪 u=0.5')
f.text(490,150,'segments 是物理段数；节点数 = segments + 1')
f.text(490,184,'节点质量固定；出生时整条材料已经存在。','small')
f.line(32,247,968,247,'#dbe3ef')
f.text(55,289,'带面外弯曲');f.text(55,318,'bendingStiffness','small')
f.path('M70 408 C 100 328 207 477 270 374',BLUE,18)
f.text(55,466,'控制翻卷难易','small')
f.text(366,289,'带面内弯曲');f.text(366,318,'inPlaneBendingStiffness','small')
f.path('M380 405 Q 464 346 572 405',TEAL,27)
f.text(366,466,'控制沿带面侧向弯折','small')
f.text(689,289,'绕长度方向扭转');f.text(689,318,'torsionalStiffness','small')
f.path('M710 388 C 760 344 820 436 930 388',GOLD,8)
f.path('M710 414 C 760 458 820 366 930 414',GOLD,8)
f.text(689,466,'控制截面扭转后的回复','small')
f.save('ribbon-material')

f=Figure('05 / 两个空气系数，三个局部方向',450)
f.polygon([(74,196),(664,293),(862,217),(272,120)],'#dbe3ed','#94a3b8')
f.arrow(467,212,467,83,BLUE);f.text(493,105,'dragCoefficient')
f.text(493,133,'垂直材料表面的法向阻力','small')
f.arrow(467,212,750,259,TEAL);f.text(719,323,'沿长度')
f.arrow(467,212,347,264,TEAL);f.text(238,314,'沿宽度')
f.text(410,350,'surfaceFriction：沿材料表面的两个切向分量')
f.text(43,403,'方向随材料弯曲和翻转改变；箭头示意方向，长度不表示力大小。','small')
f.save('air-forces')

def chart(f,x,y,w,h,fun,xmax,title,xlabel,ylabel,color,xticks):
    f.text(x,y-28,title)
    f.line(x,y,x,y+h,GRAY,1.5);f.line(x,y+h,x+w,y+h,GRAY,1.5)
    for val in [0,.5,1]:
        yy=y+h*(1-val);f.line(x,yy,x+w,yy,'#dbe3ef',1);f.text(x-10,yy+5,str(val),'small','end')
    points=[(x+w*i/160,y+h*(1-fun(i*xmax/160))) for i in range(161)]
    f.path('M'+' L'.join(f'{a:.2f} {b:.2f}' for a,b in points),color,4)
    for val in xticks:f.text(x+val/xmax*w,y+h+25,str(val),'small','middle')
    f.text(x+w/2,y+h+56,xlabel,'small','middle');f.text(x,y-6,ylabel,'small')
f=Figure('06 / 局部风的空间衰减与阵风的时间包络',470)
chart(f,83,135,365,225,lambda x:math.exp(-x*x),3,'局部风：exp(−r² / radius²)','距离 r / radius','相对强度',BLUE,[0,1,2,3])
f.text(98,439,'r = radius 时仍有约 36.8% 的强度。','small')
chart(f,587,135,365,225,lambda x:math.sin(math.pi*x)**2,1,'阵风：sin²(π × progress)','已过时间 / duration','相对强度',TEAL,[0,.25,.5,.75,1])
f.text(598,439,'从零增强，中点最强，结束时回到零。','small')
f.save('wind-envelopes')

f=Figure('07 / 自动速度响应',465)
chart(f,82,133,523,236,lambda x: (lambda t:t*t*(3-2*t))(max(0,min(1,(x-.625)/.625))),1.875,'速度显现因子：自动适配画布高度','每秒跨越的画布高度数','显现因子',BLUE,[0,.625,1.25,1.875])
f.text(671,149,'≤ 0.625 个画布高度/秒');f.text(671,180,'不绘制光迹','small')
f.text(671,229,'0.625 → 1.25');f.text(671,260,'平滑显现，减速则逐渐消失','small')
f.text(671,310,'≥ 1.25 个画布高度/秒');f.text(671,341,'完全显现，长度继续随速度增加','small')
f.text(82,445,'同一 viewHeight 下等比改变画布尺寸，显隐门限不变；柔边按速度与宽度自动计算。','small')
f.save('streak-speed')

f=Figure('08 / 同一个轮廓，关联外观和物理属性',400)
f.box(30,102,260,86,'PaperShape','只定义轮廓，保留凹处')
f.box(370,102,260,86,'PaperSize','等比缩放 / 独立拉伸')
f.box(708,102,260,86,'ParticleChoice','完整配方 + 相对权重')
f.arrow(300,145,355,145);f.arrow(640,145,693,145)
f.box(30,257,430,91,'同一份规范几何','三角网格、实际面积、质心与惯量',TEAL)
f.box(540,257,428,91,'两个独立空气系数','压力气动与旋转 / 表面切向摩擦',TEAL)
f.arrow(470,302,525,302,TEAL)
f.text(32,383,'曲线离散和三角化在准备时完成；每次出生独立随机采样尺寸和运动。','small')
f.save('paper-shapes')

if __name__=='__main__':
    print('Generated 8 explanatory SVG figures.')

# 仅对真实截图作版面排布和局部放大，不重绘或改变粒子。
from PIL import Image, ImageDraw, ImageFont, ImageChops
import os
font_path = os.environ.get('GUIDE_FONT', '/System/Library/Fonts/STHeiti Medium.ttc')
if not Path(font_path).is_file():
    raise RuntimeError('Set GUIDE_FONT to an installed Chinese .ttf/.ttc font.')
font = ImageFont.truetype(font_path, 27)
small = ImageFont.truetype(font_path, 20)
hero = Image.new('RGB', (1800, 550), '#f4f7fb')
draw = ImageDraw.Draw(hero)
draw.text((30, 20), '六种庆祝方式', font=font, fill=INK)
draw.text((30, 62), '真实引擎渲染 · 预览局部放大（非统一比例）', font=small, fill=GRAY)
scenes = [('celebration','轻量庆祝'),('side-cannons','双侧礼炮'),('paper-rain','纸片雨'),('ribbon-dance','长丝带飘舞'),('streak-burst','开场色带'),('shape-mix','多形状混合')]
for index,(scene,title) in enumerate(scenes):
    source=Image.open(ASSETS/f'{scene}.png').convert('RGB')
    difference=ImageChops.difference(source,Image.new('RGB',source.size,source.getpixel((0,0))))
    box=difference.getbbox()
    x0,y0,x1,y1=box
    crop=source.crop((max(0,x0-12),max(0,y0-15),min(source.width,x1+12),min(source.height,y1+15)))
    crop.thumbnail((248,344),Image.Resampling.LANCZOS)
    x=30+index*294
    draw.rounded_rectangle((x,112,x+264,480),radius=12,fill='#101827')
    hero.paste(crop,(x+(264-crop.width)//2,112+(368-crop.height)//2))
    draw.text((x,498),f'0{index+1} / {title}',font=small,fill=INK)
hero.save(ASSETS/'preset-overview.png')
print('Composed the real-raster overview.')
