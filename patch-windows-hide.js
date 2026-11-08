#!/usr/bin/env node
// patch-windows-hide.js
// Windows 上 spawn 控制台程序时，options 里没有 windowsHide 就会弹一个黑框。
// 这个脚本扫一遍目标目录，把只差这一项的 spawn 调用补上。
//
//   node patch-windows-hide.js "C:\path\to\node_modules"          # 只报告
//   node patch-windows-hide.js "C:\path\to\node_modules" --fix    # 直接改（先备份为 .bak）
//
// 只处理"单行 options 对象里已经有 stdio、缺 windowsHide"的情况，其余只报告不改。

const fs = require('fs');
const path = require('path');

const target = process.argv[2];
const doFix = process.argv.includes('--fix');
if (!target || !fs.existsSync(target)) {
  console.error('usage: node patch-windows-hide.js <dir> [--fix]');
  process.exit(2);
}

const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== '.git') walk(p); }
    else if (e.name.endsWith('.js') || e.name.endsWith('.mjs') || e.name.endsWith('.cjs')) files.push(p);
  }
})(target);

// 单行的 spawn(...) 调用，options 里带 stdio 但没有 windowsHide
const re = /spawn\([^\n]*\{[^\n}]*stdio:[^\n}]*\}/;

let hits = 0;
let fixed = 0;

for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  const lines = src.split('\n');
  let changed = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.includes('spawn(')) continue;
    if (!re.test(line)) continue;
    if (line.includes('windowsHide')) continue;

    hits++;
    const rel = path.relative(target, file);
    if (!doFix) {
      console.log(`${rel}:${i + 1}  ${line.trim().slice(0, 110)}`);
      continue;
    }
    // 在 options 对象的最后一个 } 前插入 windowsHide
    lines[i] = line.replace(/(\{[^\n}]*stdio:[^\n}]*)\}/, '$1, windowsHide: true }');
    if (lines[i] !== line) { changed = true; fixed++; }
  }

  if (changed) {
    fs.writeFileSync(file + '.bak', src, 'utf8');
    fs.writeFileSync(file, lines.join('\n'), 'utf8');
    console.log(`patched ${path.relative(target, file)} (backup: ${path.basename(file)}.bak)`);
  }
}

console.log(`\nfound ${hits} spawn call(s) missing windowsHide${doFix ? `, patched ${fixed}` : ' (dry run: add --fix to change)'}`);
