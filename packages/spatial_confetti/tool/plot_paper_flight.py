"""从 record_paper_flight_test.dart 的实际输出生成轨迹图；需要 Matplotlib。"""
from pathlib import Path
import json
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

root = Path(__file__).resolve().parents[1]
font = os.environ.get("CONFETTI_CHINESE_FONT", "/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
if Path(font).exists():
    font_manager.fontManager.addfont(font)
    plt.rcParams["font.family"] = [font_manager.FontProperties(fname=font).get_name(), "DejaVu Sans"]
plt.rcParams.update({"font.size": 11, "axes.unicode_minus": False, "svg.fonttype": "path"})
cases = json.loads((root / "docs/assets/paper-flight.json").read_text())
fig, axes = plt.subplots(2, 2, figsize=(12, 9), gridspec_kw={"width_ratios": [1, 1.8]})
fig.set_facecolor("#f4f6f5")
fig.suptitle("从静止释放：轨迹与姿态一起改变", fontsize=22, color="#172b3c", y=.97)
fig.text(.5, .923, "真实求解器数据 · 10 × 30 cm 薄片 · 初始倾角 40° · 静止空气 · 初始角速度为 0", ha="center", color="#5c6c78")
for row, case in enumerate(cases):
    data = np.array(case["samples"])
    t, x, y, pitch = data[:, :4].T
    color = "#0c796d" if row == 0 else "#bf652a"
    label = "往返飘摆" if row == 0 else "连续翻滚"
    ax, angle_ax = axes[row]
    for axis in [ax, angle_ax]:
        axis.set_facecolor("#ffffff")
        axis.grid(color="#e6ebee", linewidth=.8)
        axis.set_axisbelow(True)
        axis.spines[["top", "right"]].set_visible(False)
        axis.spines[["left", "bottom"]].set_color("#b9c8ce")
        axis.tick_params(colors="#5c6c78")
    ax.plot(x, y, color=color, linewidth=2)
    ax.scatter([x[0], x[-1]], [y[0], y[-1]], color=color, s=24, zorder=3)
    for i in range(15, len(t), 30):
        direction = np.deg2rad(pitch[i])
        # 真实 10 cm 弦长；只展示剖面方向，未放大纸片或改变轨迹。
        dx, dy = .05 * np.cos(direction), .05 * np.sin(direction)
        ax.plot([x[i]-dx,x[i]+dx], [y[i]-dy,y[i]+dy], color="#172b3c", linewidth=2)
    ax.annotate("0 s", (x[0],y[0]), xytext=(8,2), textcoords="offset points", fontsize=9)
    ax.annotate("6 s", (x[-1],y[-1]), xytext=(8,2), textcoords="offset points", fontsize=9)
    ax.invert_yaxis()
    ax.set_aspect("equal", adjustable="datalim")
    ax.set(xlabel="横向位移（m）", ylabel="沿重力方向位移（m）")
    ax.set_title(f"{label} · {case['massPerArea'] * 1000:.0f} g/m²", color=color, fontweight="bold", pad=14)
    angle_ax.plot(t,pitch,color=color,linewidth=2)
    angle_ax.axhline(0,color="#b9c8ce",linewidth=.7)
    angle_ax.set(xlabel="时间（s）", ylabel="连续展开的俯仰角（°）", xlim=(0,6))
    angle_ax.set_title("角度来回变化" if row == 0 else "角度越过多个完整周转", loc="left", color="#172b3c", pad=14)
    angle_ax.text(.98,.93, f"角度跨度 {case['pitchSpanDegrees']:.1f}°", transform=angle_ax.transAxes,
                  ha="right",va="top",color=color,bbox={"facecolor":"white","edgecolor":"none","alpha":.9})
fig.subplots_adjust(top=.85,bottom=.09,left=.09,right=.96,hspace=.46,wspace=.32)
fig.text(.5,.025,"左图为飞行平面投影，两轴等比例；短线是纸片剖面。结果属于当前气动近似，未经实物标定。",
         ha="center", fontsize=10, color="#5c6c78")
for suffix in ["png"]:
    fig.savefig(root / f"docs/assets/paper-flight.{suffix}", dpi=150, facecolor=fig.get_facecolor())
plt.close(fig)
