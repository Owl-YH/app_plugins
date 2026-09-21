"""绘制实际 Flutter 求解器记录；不合成或修饰粒子形变。"""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

assets = Path(__file__).resolve().parents[1] / 'docs/assets'
font_manager.fontManager.addfont('/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
plt.rcParams.update({'font.family': 'Arial Unicode MS', 'axes.unicode_minus': False,
                     'text.color':'#e3eaf3', 'axes.labelcolor':'#becade',
                     'xtick.color':'#9bacbf','ytick.color':'#9bacbf', 'font.size':10})
rows = json.loads((assets / 'paper-bending.json').read_text())
fig = plt.figure(figsize=(15,10),facecolor='#101827')
fig.suptitle('长边只形成轻微浅弧，撤去风后回弹',fontsize=22,x=.06,ha='left',y=.96)
fig.text(.06,.914,'真实模拟记录 · 15 cm 纸片 · 2 m/s 局部风 · 150 ms 撤风 · 最大弓高 2% · 内部阻尼 10 s⁻¹',color='#a5b6c8',fontsize=12)
for i, (frame,title) in enumerate([(0,'出生 · 未受载'),(6,'100 ms · 局部风加载中'),(69,'1150 ms · 撤风后一秒')]):
    ax=fig.add_subplot(2,3,i+1)
    ax.imshow(plt.imread(assets / f'paper-standard-{frame}.png'))
    ax.set_title(title,color='#e3eaf3',pad=10)
    ax.axis('off')
fig.text(.06,.515,'上排：正式 Flutter Painter 渲染，标准抗弯刚度 2×10⁻⁵ N·m；只平移画布使粒子居中。',fontsize=10,color='#a5b6c8')
colors=['#fdb36b','#80dbc4','#a89ef5']
labels=['柔软 · 2×10⁻⁶','标准 · 2×10⁻⁵','挺括 · 2×10⁻³']
ax=fig.add_subplot(2,3,4,facecolor='#101827')
for row,col,label in zip(rows,colors,labels):
    ax.plot([p['time'] for p in row['samples']],[abs(p['bendRatio'])*row['size']*1000 for p in row['samples']],color=col,label=label,lw=2)
ax.axvline(.15,color='#76879b',ls='--',lw=1)
ax.set_title('实际弓高，最多长边的 2%',color='#e3eaf3')
ax.set_xlabel('模拟时间 / s');ax.set_ylabel('形变深度 / mm')
ax.legend(facecolor='#101827',edgecolor='#344254',labelcolor='#becade',fontsize=8)
ax.grid(alpha=.15)
for spine in ax.spines.values(): spine.set_color('#344254')
for slot,index in [(5,0),(6,2)]:
    row=rows[index];p=row['samples'][9];points=p['vertices'];tri=row['triangles']
    ax=fig.add_subplot(2,3,slot,projection='3d',facecolor='#101827')
    faces=[[[v*1000 for v in points[j]] for j in tri[i:i+3]] for i in range(0,len(tri),3)]
    ax.add_collection3d(Poly3DCollection(faces,facecolor=colors[index],edgecolor='#526171',linewidth=.4,alpha=.9))
    ax.set(xlim=(-90,90),ylim=(-90,90),zlim=(-45,45),xlabel='材料 X / mm',ylabel='材料 Y / mm',zlabel='弯曲 / mm')
    ax.set_box_aspect((2,2,1));ax.view_init(elev=23,azim=-65)
    ax.set_title(f'{labels[index]} N·m · 150 ms',color='#e3eaf3',fontsize=11)
    ax.tick_params(labelsize=7)
    for axis in [ax.xaxis,ax.yaxis,ax.zaxis]:axis.pane.fill=False;axis.pane.set_edgecolor('#344254')
fig.text(.06,.035,'下排网格来自 surfaceVertices / surfaceTriangles，移除整体位姿；三个轴保持相同比例，未放大形变。\n这是实时薄片近似，未经过实物标定；短边保持直线，不包含拉伸、褶皱、碰撞和自碰撞。',fontsize=10,color='#a5b6c8')
fig.subplots_adjust(left=.07,right=.96,top=.86,bottom=.12,hspace=.4,wspace=.35)
fig.savefig(assets/'paper-bending.png',dpi=150,facecolor=fig.get_facecolor())
