// 从受校验的 Dart 配方和 Markdown 编辑源构建离线使用指南。
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const docs = join(root, 'doc');
const { marked } = process.env.MARKED_MODULE
  ? await import(pathToFileURL(process.env.MARKED_MODULE).href)
  : await import('marked');
const report = JSON.parse(readFileSync(join(docs, 'assets/capture.json'), 'utf8'));
const presets = readFileSync(join(docs, 'presets.dart'), 'utf8');
const names = {celebration:'轻量庆祝','side-cannons':'双侧礼炮','paper-rain':'纸片雨','ribbon-dance':'长丝带飘舞','streak-burst':'开场速度色带','shape-mix':'多形状随机混合'};
for (const item of report) {
  const input = join(root, 'build/guide-frames', item.id, '%04d.png');
  // 不存在中间帧时允许只重建文档；必须已经有对应视频。
  const output = join(docs, 'assets', `${item.id}.mp4`);
  if (existsSync(join(dirname(input), '0000.png')) && !process.argv.includes('--text-only')) {
    const result = spawnSync('ffmpeg', ['-hide_banner','-loglevel','error','-y','-framerate',String(item.fps),'-i',input,'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',output], {stdio:'inherit'});
    if (result.status !== 0) throw new Error(`Encoding failed: ${item.id}`);
  }
  if (!existsSync(output)) throw new Error(`Missing video: ${output}`);
}
function method(name) {
  const start = presets.indexOf(`  static ConfettiEffect ${name}(`);
  if (start < 0) throw new Error(`Missing Dart method: ${name}`);
  const candidates = [presets.indexOf('\n  ///', start), presets.indexOf('\n}\n', start)].filter(i => i >= 0);
  const end = Math.min(...candidates);
  return presets.slice(start, end).trimEnd();
}
let markdown = readFileSync(join(docs, 'guide.template.md'), 'utf8');
markdown = markdown.replace(/\{\{file:([\w.-]+)\}\}/g, (_,file) => `\`\`\`dart\n${readFileSync(join(docs,file),'utf8').trim()}\n\`\`\``);
markdown = markdown.replace(/\{\{preset:(\w+)\}\}/g, (_,name) => `<details>\n<summary>展开完整 ${name} 配置（复制到自己的配方类）</summary>\n\n\`\`\`dart\n${method(name)}\n\`\`\`\n\n</details>`);
markdown = markdown.replace(/\{\{video:([\w-]+)\}\}/g, (_,id) => `<figure class="motion"><video controls playsinline preload="none" poster="assets/${id}.png" aria-label="${names[id]}真实渲染动画"><source src="assets/${id}.mp4" type="video/mp4"/><a href="assets/${id}.mp4">播放${names[id]}</a></video><figcaption>${names[id]} · 当前 Flutter 引擎实际渲染 · 可暂停逐段观察</figcaption></figure>`);
markdown = markdown.replace('{{capture-summary}}', '| 预设 | 导出帧数 | 峰值保留粒子 | 容量/工作丢弃 | 数值异常 | 结束状态 |\n| --- | --- | --- | --- | --- | --- |\n' + report.map(r => `| ${names[r.id]} | ${r.frames} | ${r.peakParticles} | ${r.droppedParticles} | ${r.invalidParticles} | ${r.completion} |`).join('\n'));
if (/\{\{/.test(markdown)) throw new Error('Unexpanded document placeholder');
writeFileSync(join(docs,'guide.md'), markdown);
const nav = [...markdown.matchAll(/<a id="([\w-]+)"><\/a>\s*\n## ([^\n]+)/g)].map(m => `<a href="#${m[1]}">${m[2]}</a>`).join('');
let body = marked.parse(markdown, {gfm:true});
// HTML 中用视频封面展示同一截图，避免连续重复两张大图；Markdown 保留图片兼容预览器。
body = body.replace(/<p><img src="assets\/(celebration|side-cannons|paper-rain|ribbon-dance|streak-burst|shape-mix)\.png"[^>]*><\/p>\s*(?=<figure class="motion">)/g,'');
body = body.replace(/<table>/g,'<div class="table-wrap"><table>').replace(/<\/table>/g,'</table></div>');
const html = `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>Spatial Confetti · 图文使用指南</title>
<style>
:root{--ink:#172b3c;--muted:#5c6c78;--accent:#0c796d;--line:#dce5e9;--paper:#fff;--page:#f4f6f5;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;color:var(--ink);background:var(--page);font-size:16px;line-height:1.8;scroll-behavior:smooth}
*{box-sizing:border-box}body{margin:0}header{padding:20px 36px;border-bottom:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:20px;background:var(--paper)}.brand{letter-spacing:.14em;font-size:12px;font-weight:700;color:var(--accent)}.header-links{display:flex;gap:16px;font-size:13px}a{color:var(--accent);text-decoration-thickness:1px;text-underline-offset:3px}.layout{max-width:1400px;margin:auto;display:grid;grid-template-columns:235px minmax(0,1fr);gap:40px;padding:36px}aside{position:sticky;top:24px;align-self:start}aside .label{font-size:12px;color:var(--muted);letter-spacing:.1em;margin:0 0 12px}nav a{display:block;text-decoration:none;color:var(--muted);font-size:13px;padding:7px 10px;border-left:2px solid transparent;line-height:1.6}nav a:hover,nav a.active{color:var(--accent);border-color:var(--accent);background:#e8f2ef}main{min-width:0;background:var(--paper);padding:42px 48px;border:1px solid var(--line);border-radius:14px}h1{font-size:40px;line-height:1.22;letter-spacing:-.045em;margin:0 0 24px}h2{font-size:27px;line-height:1.4;letter-spacing:-.02em;margin:64px 0 24px;padding-top:26px;border-top:1px solid var(--line)}h3{font-size:20px;line-height:1.5;margin:32px 0 12px}p{margin:16px 0}blockquote{margin:16px 0 24px;padding:12px 18px;background:#ecf6f2;border-left:3px solid var(--accent);color:#225b52;font-size:14px}blockquote p{margin:0}img{display:block;max-width:100%;height:auto;margin:24px auto;border-radius:10px}p>img[src$=".png"]{max-height:560px}p>img[src$="preset-overview.png"]{max-height:none;width:100%}figure.motion{margin:24px 0 30px;display:flex;flex-direction:column;align-items:center;padding:18px;background:#eef2f6;border-radius:12px}video{display:block;max-width:100%;height:auto;width:336px;background:#101827;border-radius:8px}figcaption{font-size:12px;color:var(--muted);margin-top:12px;text-align:center}code{font-family:"SFMono-Regular",Consolas,monospace;font-size:.85em;background:#eef3f4;padding:2px 4px;border-radius:4px;overflow-wrap:anywhere}pre{background:#122132;color:#d9e9ed;padding:20px;border-radius:9px;overflow:auto;font-size:13px;line-height:1.7;position:relative}pre code{font-size:inherit;background:none;padding:0;overflow-wrap:normal}.copy{display:block;margin-left:auto;margin-bottom:10px;border:1px solid #506576;background:#203649;color:#e7f3f5;border-radius:5px;padding:5px 11px;cursor:pointer}details{margin:18px 0;border:1px solid var(--line);border-radius:8px;padding:12px 16px}summary{cursor:pointer;font-size:14px;color:var(--accent);font-weight:600}details pre{margin-bottom:4px}.table-wrap{overflow-x:auto;margin:20px 0;border:1px solid var(--line);border-radius:8px}table{width:100%;border-collapse:collapse;font-size:13px;line-height:1.75}th{background:#edf4f2;text-align:left;font-weight:600}th,td{padding:12px 14px;border-bottom:1px solid var(--line);vertical-align:top}tr:last-child td{border:0}td:first-child{min-width:135px}td{min-width:115px}li{margin:7px 0}main>a[id]{display:block;scroll-margin-top:20px}footer{max-width:1400px;margin:auto;padding:0 36px 32px;color:var(--muted);font-size:12px}.mobile-index{display:none}@media(max-width:1050px){.layout{grid-template-columns:190px minmax(0,1fr);padding:24px;gap:24px}main{padding:30px}}@media(max-width:760px){header{padding:16px 20px}.header-links{gap:10px;font-size:12px}.layout{display:block;padding:16px}aside{position:static;margin-bottom:18px}.mobile-index{display:block}aside>.label{display:none}nav{display:flex;flex-wrap:wrap;gap:4px}nav a{padding:5px 8px;font-size:12px;border-left:0;background:#e9f0ed;border-radius:4px}main{padding:24px 18px;border-radius:10px}h1{font-size:30px}h2{font-size:23px;margin-top:44px}td,th{padding:10px}video{width:300px}pre{font-size:12px}footer{padding:0 20px 24px}}@media(prefers-reduced-motion:reduce){:root{scroll-behavior:auto}}@media print{header,aside,footer,.copy{display:none}.layout{display:block;padding:0}main{border:0;padding:0}h2{break-before:page}h3{break-after:avoid}table{font-size:10px}pre{white-space:pre-wrap;background:#f1f4f6;color:#14243a}details{border:0}video{max-height:300px}a{color:inherit}img{max-height:450px}figure.motion{break-inside:avoid}}
</style></head><body>
<header><div class="brand">SPATIAL CONFETTI / FIELD GUIDE</div><div class="header-links"><a href="guide.md">Markdown</a><a href="presets.dart">完整配方</a><a href="gallery.dart">Flutter 画廊</a></div></header>
<div class="layout"><aside><div class="label">使用与调节 / CONTENTS</div><nav aria-label="章节目录">${nav}</nav></aside><main>${body}</main></div>
<footer>源码版 0.1.0 · 图片与视频随文档保存在 assets 中 · 可离线阅读 · 无外部网络依赖</footer>
<script>
for(const pre of document.querySelectorAll('pre')){const code=pre.querySelector('code');if(!code)continue;const button=document.createElement('button');button.className='copy';button.textContent='复制代码';button.type='button';button.addEventListener('click',async()=>{try{await navigator.clipboard.writeText(code.textContent);button.textContent='已复制'}catch{const range=document.createRange();range.selectNodeContents(code);getSelection().removeAllRanges();getSelection().addRange(range);button.textContent='已选中，请复制'}});pre.prepend(button)}
for(const video of document.querySelectorAll('video'))video.addEventListener('play',()=>{for(const other of document.querySelectorAll('video'))if(other!==video)other.pause()});
const links=[...document.querySelectorAll('nav a')];const sections=links.map(link=>document.querySelector(link.getAttribute('href')));const observer=new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting){links.forEach(link=>link.classList.toggle('active',link.getAttribute('href')==='#'+entry.target.id))}},{rootMargin:'0px 0px -70% 0px'});sections.forEach(section=>{if(section)observer.observe(section)});
</script></body></html>`;
writeFileSync(join(docs,'guide.html'),html);
console.log(`Built guide.md and guide.html: ${report.length} real videos, 8 explanatory figures and measured flight/bending plots.`);
