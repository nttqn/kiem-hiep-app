#!/usr/bin/env node
// Localization helper (see lib/core/i18n.dart).
//
//   node tool/i18n.js wrap lib/ui/foo.dart ...
//       Wraps every Vietnamese string literal in tr(...), turning
//       interpolations into named placeholders:
//         'Cấp ${h.level}'  ->  tr('Cấp {level}', {'level': h.level})
//       Drops a `const` right before a widget it wrapped a literal of. Skips
//       literals compared against (startsWith/contains/==/case...) and lines
//       marked `i18n-skip`. Run `flutter analyze` afterwards: what is left in
//       a const context (const lists, default values) is fixed by hand,
//       usually by keeping the data Vietnamese and calling tr() where shown.
//
//   node tool/i18n.js sync
//       Collects every tr('...') key in lib/ plus every Vietnamese literal of
//       the DATA_FILES below (const data shown through tr(def.name)), adds
//       the missing ones to each assets/i18n/<lang>.json with an empty value
//       and reports coverage. Writes tool/i18n_<lang>_missing.txt (file:line, key).

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const LIB = path.join(ROOT, 'lib');
const LANGS = ['zh_Hant', 'ko'];

// Const data whose Vietnamese literals are all shown through tr(x) at the
// display site. Paths relative to lib/.
const DATA_ALL = true; // every Vietnamese literal outside tr() in lib/ is a key too
const DATA_FILES = [
  'core/hanh.dart',
  'core/sects.dart',
  'core/content.dart',
  'core/items.dart',
  'core/rewards.dart',
  'core/unlocks.dart',
  'ui/create_screen.dart',
  'ui/land_splash.dart',
];

const BS = '\\';
const VI = /[À-ỹĐđ]/;

// ---------------------------------------------------------------- lexer

/// Parses the string literal at [i] (on r, ', or "). Returns
/// {start, end, raw, delim, parts:[{t:'text',s}|{t:'interp',expr,simple}]}.
function parseLiteral(src, i) {
  const start = i;
  let raw = false;
  if (src[i] === 'r') { raw = true; i++; }
  const q = src[i];
  const delim = src.substr(i, 3) === q.repeat(3) ? q.repeat(3) : q;
  i += delim.length;
  const parts = [];
  let text = '';
  const n = src.length;
  while (i < n) {
    if (src.startsWith(delim, i)) { i += delim.length; break; }
    const c = src[i];
    if (!raw && c === BS) { text += src.substr(i, 2); i += 2; continue; }
    if (!raw && c === '$' && src[i + 1] === '{') {
      if (text) parts.push({ t: 'text', s: text });
      text = '';
      i += 2;
      const es = i;
      let depth = 1;
      while (i < n) {
        const d = src[i];
        if (d === "'" || d === '"' || (d === 'r' && (src[i + 1] === "'" || src[i + 1] === '"') && !/\w/.test(src[i - 1]))) {
          i = parseLiteral(src, i).end;
          continue;
        }
        if (d === '{') depth++;
        if (d === '}') { depth--; if (depth === 0) break; }
        i++;
      }
      parts.push({ t: 'interp', expr: src.slice(es, i), simple: false });
      i++; // }
      continue;
    }
    if (!raw && c === '$' && /[A-Za-z_]/.test(src[i + 1])) {
      if (text) parts.push({ t: 'text', s: text });
      text = '';
      let j = i + 1;
      while (j < n && /\w/.test(src[j])) j++;
      parts.push({ t: 'interp', expr: src.slice(i + 1, j), simple: true });
      i = j;
      continue;
    }
    if (delim.length === 1 && c === '\n') break; // unterminated: give up on it
    text += c;
    i++;
  }
  if (text) parts.push({ t: 'text', s: text });
  return { start, end: i, raw, delim, parts };
}

/// Top-level literals of [src] (comments skipped), grouped when adjacent.
function literalGroups(src) {
  const groups = [];
  let i = 0;
  const n = src.length;
  let cur = null;
  let lastEnd = -1;
  while (i < n) {
    const c = src[i];
    if (c === '/' && src[i + 1] === '/') { while (i < n && src[i] !== '\n') i++; continue; }
    if (c === '/' && src[i + 1] === '*') { const e = src.indexOf('*/', i + 2); i = e < 0 ? n : e + 2; continue; }
    if (c === "'" || c === '"' || (c === 'r' && (src[i + 1] === "'" || src[i + 1] === '"') && !/\w/.test(src[i - 1] || ''))) {
      const lit = parseLiteral(src, i);
      const between = lastEnd >= 0 ? src.slice(lastEnd, lit.start) : null;
      if (cur && between !== null && /^\s*$/.test(between.replace(/\/\/[^\n]*/g, ''))) {
        cur.lits.push(lit);
      } else {
        cur = { lits: [lit] };
        groups.push(cur);
      }
      lastEnd = lit.end;
      i = lit.end;
      continue;
    }
    if (!/\s/.test(c)) lastEnd = -1;
    i++;
  }
  for (const g of groups) { g.start = g.lits[0].start; g.end = g.lits[g.lits.length - 1].end; }
  return groups;
}

function groupHasVi(g) {
  return g.lits.some((l) => l.parts.some((p) => (p.t === 'text' ? VI.test(p.s) : VI.test(p.expr))));
}

function groupTextHasVi(g) {
  return g.lits.some((l) => l.parts.some((p) => p.t === 'text' && VI.test(p.s)));
}

/// Runtime value of a literal's text part (Dart escapes resolved).
function unescape(s, raw) {
  if (raw) return s;
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (c !== BS) { out += c; continue; }
    const d = s[++i];
    if (d === 'n') out += '\n';
    else if (d === 't') out += '\t';
    else if (d === 'r') out += '\r';
    else if (d === 'u') {
      if (s[i + 1] === '{') { const e = s.indexOf('}', i); out += String.fromCodePoint(parseInt(s.slice(i + 2, e), 16)); i = e; }
      else { out += String.fromCharCode(parseInt(s.substr(i + 1, 4), 16)); i += 4; }
    } else out += d;
  }
  return out;
}

// ---------------------------------------------------------------- wrap

// I18N_ONLY=<regex>: wrap only literals on lines matching it.
// I18N_DATA=1: data names in placeholders (x.name, q.title…) get tr() too
// (harmless on a player's name: it is never a key).
const ONLY = process.env.I18N_ONLY ? new RegExp(process.env.I18N_ONLY) : null;
const DATA_EXPR = process.env.I18N_DATA ? /\.(name|title|label|goal|desc|tagline|role)!?$|Names\[[^\]]*\]$/ : null;

const SKIP_BEFORE = /(startsWith|endsWith|contains|replaceAll|replaceFirst|split|indexOf|debugPrint|print|tr)\(\s*$|(==|!=)\s*$|\bcase\s+$/;
const SKIP_AFTER = /^\s*(==|!=)/;

function placeholderName(expr) {
  const e = expr.trim();
  const m = /^[A-Za-z_]\w*(?:\s*[?!]?\.\s*[A-Za-z_]\w*)*!?$/.exec(e);
  if (!m) return null;
  const ids = e.replace(/!$/, '').split(/[?!]?\./);
  const name = ids[ids.length - 1].trim();
  // `x.name`, `x.label`… say little alone; keep the owner too (sectName).
  if (ids.length > 1 && ['name', 'label', 'title', 'value', 'length'].includes(name)) {
    return ids[ids.length - 2].trim() + name[0].toUpperCase() + name.slice(1);
  }
  return name;
}

/// [force]: line numbers whose literals are wrapped even with no diacritics
/// ('Uy danh', 'Xong'), from `wrap-lines`.
function transform(src, report, file, force) {
  const groups = literalGroups(src);
  let out = '';
  let pos = 0;
  for (const g of groups) {
    const lineNo = src.slice(0, g.start).split('\n').length;
    const forced = !!force && force.has(lineNo) &&
      g.lits.some((l) => l.parts.some((p) => p.t === 'text' && /[A-Za-z]{2,}/.test(p.s)));
    if (force && !force.has(lineNo)) continue; // wrap-lines touches only those lines
    if (!groupHasVi(g) && !forced) continue;
    const before = src.slice(Math.max(0, g.start - 200), g.start);
    const after = src.slice(g.end, g.end + 20);
    const lineStart = src.lastIndexOf('\n', g.start) + 1;
    const lineEnd = src.indexOf('\n', g.end);
    const line = src.slice(lineStart, lineEnd < 0 ? src.length : lineEnd);
    const isImport = /^\s*(import|export|part)\b/.test(line);
    if (isImport) continue;
    if (ONLY && !ONLY.test(line)) continue;
    const skip = !(groupTextHasVi(g) || forced) || SKIP_BEFORE.test(before) || SKIP_AFTER.test(after) || /i18n-skip/.test(line);
    if (skip) {
      if (groupTextHasVi(g) && !/tr\(\s*$/.test(before)) {
        report.skipped.push(`${file}:${lineNo}: ${line.trim().slice(0, 110)}`);
      }
      // Text only inside an interpolation, or a skipped group: still wrap
      // the VN literals nested in its ${...}.
      const seg = src.slice(g.start, g.end);
      const fixed = transformInterpolations(src, g, report, file);
      if (fixed !== seg) { out += src.slice(pos, g.start) + fixed; pos = g.end; }
      continue;
    }
    // Build the wrapped group.
    const names = new Map(); // expr -> name
    const used = new Set();
    let pn = 0;
    const args = [];
    let body = '';
    let prevEnd = null;
    for (const lit of g.lits) {
      if (prevEnd !== null) body += src.slice(prevEnd, lit.start);
      let s = (lit.raw ? 'r' : '') + lit.delim;
      for (const part of lit.parts) {
        if (part.t === 'text') { s += part.s; continue; }
        const key = part.expr.trim();
        let name = names.get(key);
        if (!name) {
          name = placeholderName(key) || `p${pn++}`;
          while (used.has(name)) name = name + '2';
          used.add(name);
          names.set(key, name);
          let valueExpr = VI.test(key) ? transform(key, report, file) : key;
          if (DATA_EXPR && DATA_EXPR.test(key)) valueExpr = `tr(${valueExpr})`;
          args.push(`'${name}': ${valueExpr}`);
        }
        s += `{${name}}`;
      }
      s += lit.delim;
      body += s;
      prevEnd = lit.end;
    }
    let wrapped = args.length ? `tr(${body}, {${args.join(', ')}})` : `tr(${body})`;
    // `const Text('…')` can no longer be const.
    let prefix = src.slice(pos, g.start);
    const cm = /\bconst\s+([A-Z]\w*(?:<[^>]*>)?(?:\.\w+)?\(\s*(?:\w+:\s*)?)$/.exec(prefix);
    if (cm) prefix = prefix.slice(0, cm.index) + cm[1];
    out += prefix + wrapped;
    pos = g.end;
    report.wrapped++;
  }
  return out + src.slice(pos);
}

/// The group's source with only VN literals inside ${...} wrapped.
function transformInterpolations(src, g, report, file) {
  let res = '';
  let p = g.start;
  for (const lit of g.lits) {
    for (const part of lit.parts) {
      if (part.t !== 'interp' || part.simple || !VI.test(part.expr)) continue;
      const at = src.indexOf(part.expr, p);
      res += src.slice(p, at) + transform(part.expr, report, file);
      p = at + part.expr.length;
    }
  }
  return res + src.slice(p, g.end);
}

// ---------------------------------------------------------------- sync

function dartFiles(dir) {
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const p = path.join(dir, f);
    if (fs.statSync(p).isDirectory()) out.push(...dartFiles(p));
    else if (p.endsWith('.dart')) out.push(p);
  }
  return out;
}

function groupValue(g) {
  let s = '';
  for (const lit of g.lits) {
    for (const part of lit.parts) {
      if (part.t === 'text') s += unescape(part.s, lit.raw);
      else return null;
    }
  }
  return s;
}

// Data words with no diacritics in const lists outside DATA_FILES, shown
// through tr(x): sync cannot tell them from ids, so they are listed here.
const EXTRA_KEYS = ['Linh Chi', 'Hoa', 'Phong', 'Thanh Y', 'Tinh anh, boss', 'Uy danh', 'Tinh Hoa', 'Xu Bang',
  'Linh binh', 'Tinh', 'Tham Lang', 'Bao La', 'Thanh Phong', 'Hoa bay', 'Xa', 'Can Kinh',
  // Inside the ${...} of another literal, where sync does not look.
  'Từ tầng 1', 'Từ tầng 10', 'Từ tầng 20'];

function sync() {
  const keys = new Map(); // key -> first place
  for (const k of EXTRA_KEYS) keys.set(k, 'tool/i18n.js EXTRA_KEYS');
  const warn = [];
  const dataSet = new Set(DATA_FILES.map((f) => path.join(LIB, f)));
  for (const file of dartFiles(LIB)) {
    // chat.dart holds the swear filter's word list: matched, never shown.
    if (/dev_entry\.dart$|i18n\.dart$|core[\\/]chat\.dart$/.test(file)) continue;
    const src = fs.readFileSync(file, 'utf8');
    const rel = path.relative(ROOT, file).replace(/\\/g, '/');
    for (const g of literalGroups(src)) {
      const before = src.slice(Math.max(0, g.start - 40), g.start);
      const isTr = /(^|[^\w.])tr\(\s*$/.test(before);
      // Data text shown through tr(x) later: any Vietnamese literal (with
      // DATA_ALL), plus diacritic-free words ('Kim') in DATA_FILES; ids are
      // camelCase or snake.
      const isData = !isTr && (((DATA_ALL || dataSet.has(file)) && groupTextHasVi(g)) ||
        (dataSet.has(file) && /^[A-Z][a-z]+( [A-Za-z]+)*[.!]?$/.test(groupValue(g) || '')));
      if (!isTr && !isData) continue;
      const v = groupValue(g);
      const lineNo = src.slice(0, g.start).split('\n').length;
      if (v === null) {
        if (isTr) warn.push(`${rel}:${lineNo}: interpolation inside a tr() key`);
        continue;
      }
      if (!keys.has(v)) keys.set(v, `${rel}:${lineNo}`);
    }
  }
  for (const lang of LANGS) {
    const jf = path.join(ROOT, 'assets', 'i18n', `${lang}.json`);
    const table = fs.existsSync(jf) ? JSON.parse(fs.readFileSync(jf, 'utf8')) : {};
    let added = 0;
    for (const k of keys.keys()) if (!(k in table)) { table[k] = ''; added++; }
    const unused = Object.keys(table).filter((k) => !keys.has(k));
    const missing = [...keys.keys()].filter((k) => !table[k]);
    fs.mkdirSync(path.dirname(jf), { recursive: true });
    fs.writeFileSync(jf, JSON.stringify(table, null, 1) + '\n');
    fs.writeFileSync(path.join(ROOT, 'tool', `i18n_${lang}_missing.txt`),
      missing.map((k) => `${keys.get(k)}\t${JSON.stringify(k)}`).join('\n') + '\n');
    console.log(`${lang}: ${keys.size} keys, ${keys.size - missing.length} translated, ${missing.length} missing (+${added} new), ${unused.length} unused`);
    if (unused.length) console.log('  unused: ' + unused.slice(0, 10).map((k) => JSON.stringify(k)).join(', ') + (unused.length > 10 ? ' …' : ''));
  }
  for (const w of warn) console.log('warn ' + w);
}

// ---------------------------------------------------------------- main

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === 'wrap' || cmd === 'wrap-lines') {
  // wrap-lines file:line file:line … also wraps diacritic-free text there.
  const byFile = new Map();
  for (const a of rest) {
    if (cmd === 'wrap') { byFile.set(a, null); continue; }
    const [f, ln] = a.split(/:(?=\d+$)/);
    if (!byFile.has(f)) byFile.set(f, new Set());
    byFile.get(f).add(+ln);
  }
  for (const [f, force] of byFile) {
    const report = { wrapped: 0, skipped: [] };
    const src = fs.readFileSync(f, 'utf8');
    let out = transform(src, report, f, force);
    if (out !== src && !/import '[./]*(core\/)?i18n\.dart'/.test(out)) {
      const rel = path.relative(path.dirname(path.resolve(f)), path.join(LIB, 'core', 'i18n.dart')).replace(/\\/g, '/');
      const imp = `import '${rel}';` + (out.includes('\r\n') ? '\r\n' : '\n');
      const m = /^import [^\n]*\n(?![\s\S]*^import )/m.exec(out);
      out = m ? out.slice(0, m.index + m[0].length) + imp + out.slice(m.index + m[0].length) : imp + out;
    }
    fs.writeFileSync(f, out);
    console.log(`${f}: wrapped ${report.wrapped}`);
    for (const s of report.skipped) console.log('  skipped ' + s);
  }
} else if (cmd === 'sync') {
  sync();
} else {
  console.log('usage: node tool/i18n.js wrap <files…> | sync');
  process.exit(1);
}
