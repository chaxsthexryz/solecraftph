// Run: node dsl/pluscode_test.js
// The Plus Code regex lives inside a custom-widget string in edit.dart, so it
// cannot be imported by a Dart test. This mirrors it character for character;
// change one and change the other.
// Mirrors the Dart RegExp added to _composeAddress in dsl/edit.dart.
const plusCode = /^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b[\s,]*/;
const strip = s => s.replace(plusCode, '').trim();

const cases = [
  // [input, expected]  -- the two real saved addresses first
  ['M4F6+977',                      ''],
  ['M4C4+GXR Permaline Homes',      'Permaline Homes'],
  ['M4F6+977, San Mateo',           'San Mateo'],
  ['7Q63M4F6+977 Rodriguez',        'Rodriguez'],
  // must NOT be touched
  ['104 Magnolia St',               '104 Magnolia St'],
  ['San Mateo',                     'San Mateo'],
  ['Marikina',                      'Marikina'],
  ['Metro Manila',                  'Metro Manila'],
  ['Calabarzon',                    'Calabarzon'],
  ['CFGH Street',                   'CFGH Street'],   // alphabet letters, no '+'
  ['J. P. Rizal Street',            'J. P. Rizal Street'],
  ['Blk 12 Lot 4 Permaline',        'Blk 12 Lot 4 Permaline'],
];

let bad = 0;
for (const [input, want] of cases) {
  const got = strip(input);
  const ok = got === want;
  if (!ok) bad++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${JSON.stringify(input)} -> ${JSON.stringify(got)}${ok ? '' : `  (wanted ${JSON.stringify(want)})`}`);
}
console.log(bad === 0 ? '\nall ' + cases.length + ' cases pass' : `\n${bad} FAILURES`);
process.exit(bad === 0 ? 0 : 1);
