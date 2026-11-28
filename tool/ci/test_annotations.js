#!/usr/bin/env node
// Reads `flutter test --reporter json` output (argv[2]) and prints one
// GitHub `::error` annotation per failing test (name, first error lines),
// so a failure is readable from the run page without opening the log.
const fs = require('fs');
const lines = fs.readFileSync(process.argv[2], 'utf8').split('\n');
const names = {}, errors = {}, failed = [];
for (const l of lines) {
  let e;
  try { e = JSON.parse(l); } catch { continue; }
  if (e.type === 'testStart') names[e.test.id] = e.test.name;
  if (e.type === 'error') (errors[e.testID] = errors[e.testID] || []).push(e.error);
  if (e.type === 'testDone' && e.result !== 'success' && !e.skipped) failed.push(e.testID);
}
const esc = (s) => s.replace(/%/g, '%25').replace(/\r/g, '').replace(/\n/g, '%0A');
for (const id of failed) {
  const msg = (errors[id] || ['(no message)']).join('\n').split('\n').slice(0, 25).join('\n');
  console.log(`::error title=${esc(names[id] || 'test ' + id).replace(/[:,]/g, ' ')}::${esc(msg)}`);
}
console.log(`${failed.length} failing test(s)`);
