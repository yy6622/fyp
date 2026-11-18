import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const runtimeModules = 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules';
const modulePath = `${runtimeModules}/@oai/artifact-tool/dist/artifact_tool.mjs`;
const { PresentationFile, FileBlob } = await import(pathToFileURL(modulePath).href);

const templatePath = 'D:/Download/Poster Template A1 size (Project 2).pptx';
const presentation = await PresentationFile.importPptx(await FileBlob.load(templatePath));
const setText = (id, value) => { presentation.resolve(id).text = value; };

// Header: preserve the school's template identity and add the project logo as a
// separate transparent image. No duplicate brand name is typed into the text.
setText('sh/nydczmpk', 'Group Trip Planning App');
const subtitle = presentation.resolve('sh/mx4v6hoz');
subtitle.text = 'Plan together, travel better\nItinerary, polls and trip costs in one shared app';
subtitle.position = { left: 855, top: 145.14, width: 1150, height: 245.35 };
subtitle.text.style = { fontSize: 40, typeface: 'Arial', color: '#000000', bold: true, alignment: 'center', verticalAlignment: 'middle', autoFit: 'shrinkText' };

const readBytes = async (path) => new Uint8Array(await fs.readFile(path));
const slide = presentation.resolve('sl/y90nupkv');
slide.images.add({
  blob: await readBytes('C:/Users/Admin/StudioProjects/Voya/assets/images/voya_logo.png'),
  contentType: 'image/png',
  alt: 'Voya sail logo and wordmark',
  fit: 'contain',
  position: { left: 2005, top: 260, width: 205, height: 139 },
});

// Overview and purpose sections.
setText('sh/or6hcvu5', 'Abstract');
setText('sh/9sfylgbq', '\n\nThe group trip planning app gives friends one shared place to plan a getaway. Explore flights, hotels and activities, build a day-by-day itinerary, vote on choices, and keep travel details and shared costs together. AI planning help, weather updates, emergency information and a travel community support the group from the first idea to departure.');

setText('sh/432dwn6l', 'Problem Statement');
setText('sh/p4bu5s76', '\n\nGroup trips are planned across scattered chats, links and notes. Choices get buried, itineraries go out of date, and the group can lose track of bookings and shared costs. Travelers need one clear plan that everyone can see and update.');

setText('sh/vyp0je1s', 'Objectives');
setText('sh/uxgjq907', '\n\n1. Keep dates, bookings and activities in one shared itinerary.\n2. Help every traveler weigh in through group polls.\n3. Record shared costs, split bills and track payments.\n4. Make the latest plan easy for the whole group to find.');

setText('sh/h072l4jy', 'Trip Planning Flow');
setText('sh/wzy1szid', '\n\n1. CREATE A TRIP\nChoose a destination and dates, set a group budget, and invite friends.\n\n2. EXPLORE & SAVE\nSearch flights, hotels, restaurants and attractions; keep favorites for later.\n\n3. BUILD THE ITINERARY\nAdd activities to a shared daily timeline. Reorder plans or move them between days.\n\n4. DECIDE TOGETHER\nUse group polls to choose hotels, activities and dining.\n\n5. STAY ON TRACK\nKeep bookings, expenses, weather and emergency details close to the plan.');

// Replace the generic template copy with one-line feature explanations.
setText('sh/j2pkne14', 'App Features');
const features = [
  ['🗓', 'TRIP SETUP', 'Destination, dates, budget and group'],
  ['🔎', 'EXPLORE', 'Flights, stays, restaurants and attractions'],
  ['🗺', 'ITINERARY', 'A shared day-by-day activity plan'],
  ['✨', 'AI ASSIST', 'Group chat turned into reviewable ideas'],
  ['🗳', 'GROUP POLLS', 'Vote on hotels, activities and dining'],
  ['💳', 'EXPENSES', 'Split bills, scan receipts, track payments'],
  ['✈', 'TRAVEL DETAILS', 'Flight and hotel info kept with the plan'],
  ['☀', 'WEATHER', 'Check conditions and adjust outdoor plans'],
  ['🛟', 'SAFETY', 'Emergency info and shared group location'],
  ['🌍', 'COMMUNITY', 'Browse itineraries, reviews and insurance'],
];
const featureText = presentation.resolve('sh/i1gje90j');
featureText.text = '\n\n\n' + features.map(([icon, label, detail]) => `${icon}  ${label}  —  ${detail}`).join('\n\n');
featureText.text.style = { fontSize: 34, typeface: 'Times New Roman', color: '#000000', bold: false, alignment: 'left', verticalAlignment: 'top', autoFit: 'shrinkText' };
for (const [, label] of features) featureText.text.get(label).bold = true;

// Reuse the template's table/chart example area for a project travel photo.
presentation.delete(['tb/czidkn6l', 'ch/7m5s7yhs']);
slide.images.add({
  blob: await readBytes('C:/Users/Admin/StudioProjects/Voya/assets/images/community.jpg'),
  contentType: 'image/jpeg',
  alt: 'Hot air balloons above a mountain destination at sunrise',
  fit: 'cover',
  position: { left: 1285, top: 1785, width: 790, height: 390 },
  geometry: 'roundRect',
  borderRadius: 18,
});

setText('sh/nqxgjqtk', 'Why It Helps');
setText('sh/036h8but', '\nOne shared plan keeps the group in sync. Everyone can see what is decided, what still needs a vote, where the trip is headed and how the costs are adding up.');

setText('sh/z2xgf6to', 'Plan Together');
setText('sh/y5wjip0z', '\n\nPlan together, travel better. Keep the itinerary, group decisions and trip costs in one place—from the first “Where should we go?” to the journey home.');

for (const id of ['sh/or6hcvu5','sh/432dwn6l','sh/vyp0je1s','sh/h072l4jy','sh/j2pkne14','sh/nqxgjqtk','sh/z2xgf6to']) {
  presentation.resolve(id).bringToFront();
}

// Normalize body text to the template's serif type while preventing inherited
// sample emphasis and middle-aligned positioning from the placeholder copy.
for (const [id, fontSize, alignment] of [
  ['sh/9sfylgbq', 37.45, 'left'],
  ['sh/p4bu5s76', 37.45, 'left'],
  ['sh/uxgjq907', 37.45, 'left'],
  ['sh/wzy1szid', 37.45, 'left'],
  ['sh/036h8but', 37.45, 'left'],
  ['sh/y5wjip0z', 37.45, 'left'],
]) {
  const shape = presentation.resolve(id);
  shape.text.style = { fontSize, typeface: 'Times New Roman', color: '#000000', bold: false, alignment, verticalAlignment: 'top', autoFit: 'shrinkText' };
}
// Keep a little breathing room under the abstract's section tab.
presentation.resolve('sh/9sfylgbq').text = '\n\nThe group trip planning app gives friends one shared place to plan a getaway. Explore flights, hotels and activities, build a day-by-day itinerary, vote on choices, and keep travel details and shared costs together. AI planning help, weather updates, emergency information and a travel community support the group from the first idea to departure.';

// Save the editable draft and a rendered preview for visual review.
await fs.mkdir('.poster_build', { recursive: true });
const png = await presentation.export({ slide, format: 'png', scale: 0.5 });
await fs.writeFile('.poster_build/voya-a1-preview.png', new Uint8Array(await png.arrayBuffer()));
const layout = await slide.export({ format: 'layout' });
await fs.writeFile('.poster_build/voya-a1-layout.json', await layout.text());
const draft = await PresentationFile.exportPptx(presentation);
await draft.save('.poster_build/voya-a1-draft.pptx');
console.log((await presentation.inspect({ select: '$.slides[*]', include: ['id','index','layout','title','elements.id','elements.kind','elements.text','elements.position'], })).ndjson);
