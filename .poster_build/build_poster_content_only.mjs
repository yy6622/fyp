import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const modulePath = 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs';
const { PresentationFile, FileBlob } = await import(pathToFileURL(modulePath).href);
const source = 'D:/Download/Poster Template A1 size (Project 2).pptx';
const presentation = await PresentationFile.importPptx(await FileBlob.load(source));
const slide = presentation.resolve('sl/y90nupkv');

function setText(id, value, style = undefined) {
  const shape = presentation.resolve(id);
  const position = shape.position;
  shape.text = value;
  if (style) shape.text.style = style;
  // Keep the placeholder's exact frame even if its source text used auto-fit.
  shape.position = position;
  return shape;
}

// Keep the established project title and requested tagline in the existing
// header frames; preserve all template styling and geometry.
setText('sh/nydczmpk', 'Group Trip Planning App', {
  fontSize: 80.25, typeface: 'Arial', color: '#000000', bold: true,
  alignment: 'center', verticalAlignment: 'middle', autoFit: 'resizeShapeToFitText',
  insets: { top: 30.8908, right: 12.3563, bottom: 30.8908, left: 12.3563 },
});
setText('sh/mx4v6hoz', 'Plan together, travel better', {
  fontSize: 53.49, typeface: 'Arial', color: '#000000', bold: true,
  alignment: 'center', verticalAlignment: 'middle',
  insets: { top: 12.3563, right: 12.3563, bottom: 12.3563, left: 12.3563 },
});

// Replace the image inside the template's existing logo frame. The transparent
// Voya artwork remains proportionate and has no background fill.
const logo = presentation.resolve('im/ri9kvmxs');
const originalLogoFrame = logo.frame;
logo.replace({
  blob: new Uint8Array(await fs.readFile('C:/Users/Admin/StudioProjects/Voya/assets/images/voya_logo.png')),
  contentType: 'image/png',
  alt: 'Voya logo with transparent background',
  fit: 'contain',
});
logo.frame = originalLogoFrame;

function setBody(id, value, alignment, fontSize = 37.45) {
  return setText(id, value, {
    fontSize,
    typeface: 'Times New Roman',
    color: '#000000',
    bold: false,
    alignment,
    verticalAlignment: 'middle',
  });
}

// Section headings stay exactly as printed in the template. Only body text changes.
const body = {};
body.abstract = setBody('sh/9sfylgbq', '\nGroup travel spans chats, booking sites and spreadsheets, obscuring decisions, itineraries and costs. This project links a Flutter app and admin/partner web console through Firebase for chat summaries, voting, route planning, bookings, insurance, community and expense tracking. Unit, integration, Cloud Function and web tests accompany public-dialogue results: 92.5% travel accuracy, 97.6% off-topic recognition.', 'justify');
body.problem = setBody('sh/p4bu5s76', '\n\n1. Trip plans split across chats, booking sites and spreadsheets.\n2. Agreed places disappear in long conversations.\n3. Manual bill splits lose cents and hide who owes whom.\n4. Generic suggestions ignore preferences, access and travel time.\n5. Safety and insurance details sit apart from the trip.', 'left');
body.objectives = setBody('sh/uxgjq907', '\n1. Plan, chat, vote and split costs together.\n2. Turn group chat into reviewed trip ideas.\n3. Optimise routes and book travel securely.\n4. Connect travellers, insurers and admins.', 'left');
body.methodology = setBody('sh/wzy1szid', '\n\nTARGET USERS\nFriends, families and student travellers; insurance partners and administrators.\n\nDEVELOPMENT\nFeature-based iterations; API limits drove an in-house char-TF-IDF/LogReg model trained with public dialogues.\n\nARCHITECTURE\nFlutter/Dart app + HTML/JS console → Firebase Auth, Firestore, Storage and Node.js Cloud Functions.\n\nCONSOLE + SERVICES\nModerates community; manages places, plans, claims, refunds and reports. Duffel/RollingGo, OSM (Wikipedia photo fallback), Stripe/PayPal, OpenAI moderation.\n\nREQUIREMENTS\nAndroid 8+ phone, internet and GPS for location features; Chrome/Edge console. Dev: Windows 10/11, 8 GB RAM.\nService model: partner insurance commissions and flight/hotel checkout.', 'justify');

// Keep the template's native table and chart in place, following its guidance
// on implementation resources, interface/logic, testing and figure captions.
const constructionText = [
  '', '', '', '',
  'AI SUMMARY — 12-step, consent-gated; extract places + stance, check flights/hotels; user applies suggestions.',
  '', '',
  'OPTIMISE — Two-opt groups district stops and cuts travel time; meals, hours and bookings stay fixed.',
  '', '',
  'RECOMMEND — Budget/access/open-now filters; weighted preference, rating, distance and schedule score.',
  '', '',
  'VOTE + COSTS — Transactions secure votes; largest-remainder cents keep equal/custom/itemised totals exact.',
  '', '',
  'TESTS — 76/83 pass; 3 fail; 4 unrun (Oct 2026).',
  '\t\t\tTable 1. Development tools and system architecture\t\t\t',
  '', '', '', '', '', '', '', '', '',
  '', '', '', '', '', '', '',
  '\t\tFigure 1. Before vs. after public-data training\t\t',
];
body.features = setBody('sh/i1gje90j', constructionText.join('\n'), 'justify');
for (const label of ['AI SUMMARY','OPTIMISE','RECOMMEND','VOTE + COSTS','TESTS']) {
  body.features.text.get(label).bold = true;
}

body.contribution = setBody('sh/036h8but', '\nCOMMERCIAL — Potential partner-insurance commissions and booking checkout. SOCIAL — Moderation, emergency/embassy information, accessible-place filters and consent. TECHNICAL — Classifier tested on unseen destinations, two-opt optimiser, transaction-safe voting and exact-cent splits.', 'left');
body.conclusion = setBody('sh/y5wjip0z', '\n\nGroup planning, booking and insurance are integrated across the mobile app and partner console. Public-dialogue training raised travel-message accuracy to 92.5%; the October test report still lists 3 failures and 4 unrun cases to resolve.', 'justify');

// Update the existing table's cell content without changing its dimensions or style.
const table = presentation.resolve('tb/czidkn6l');
const tableRows = [
  ['Layer', 'Stack', 'Role', 'Where'],
  ['App', 'Flutter', 'Trip UI', 'Mobile'],
  ['Console', 'HTML/JS', 'Admin', 'Web'],
  ['Core', 'Firebase', 'Auth/data', 'Both'],
  ['Logic', 'Node.js', 'AI/routes', 'Cloud'],
];
for (let row = 0; row < tableRows.length; row++) {
  for (let col = 0; col < tableRows[row].length; col++) {
    table.getCell(row, col).value = tableRows[row][col];
  }
}

// Update the existing chart series only; retain its three-series structure,
// chart type, colors and frame. Values show classifier performance before
// and after public dialogue data was added.
const chart = presentation.resolve('ch/7m5s7yhs');
const seriesData = [
  { name: 'Human travel', values: [15.2, 92.5, 0, 0] },
  { name: 'Small talk', values: [72.2, 81.7, 0, 0] },
  { name: 'Off-topic', values: [7.5, 97.6, 0, 0] },
];
seriesData.forEach((data, index) => chart.series.getItemAt(index).apply({
  name: data.name,
  categories: ['Before', 'After public data', '', ''],
  values: data.values,
}));

await fs.mkdir('.poster_build', { recursive: true });
const preview = await presentation.export({ slide, format: 'png', scale: 0.5 });
await fs.writeFile('.poster_build/voya-a1-content-only-preview.png', new Uint8Array(await preview.arrayBuffer()));
const layout = await slide.export({ format: 'layout' });
await fs.writeFile('.poster_build/voya-a1-content-only-layout.json', await layout.text());
const draft = await PresentationFile.exportPptx(presentation);
await draft.save('.poster_build/voya-a1-content-only-draft.pptx');
console.log((await presentation.inspect({ select: '$.slides[*]', include: ['id','index','layout','title','elements.id','elements.kind','elements.text','elements.position'], })).ndjson);
