import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const modulePath = 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-737-0_26.1112.737.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs';
const { PresentationFile, FileBlob } = await import(pathToFileURL(modulePath).href);
const input = 'D:/Download/Poster Template A1 size (Project 2).pptx';
const presentation = await PresentationFile.importPptx(await FileBlob.load(input));
console.log('slides', presentation.slides.items.length);
console.log((await presentation.inspect({select:'$.slides[*]',include:['id','index','layout','title','elements.id','elements.kind','elements.text','elements.position','elements.style','elements.alt'],})).ndjson);
for (let i=0; i<presentation.slides.items.length; i++) {
  const slide = presentation.slides.getItem(i);
  const png = await presentation.export({slide,format:'png',scale:0.5});
  await fs.writeFile(`.poster_build/template-slide-${i+1}.png`, new Uint8Array(await png.arrayBuffer()));
  const layout = await slide.export({format:'layout'});
  await fs.writeFile(`.poster_build/template-slide-${i+1}.layout.json`, await layout.text());
}
console.log('slideSize', JSON.stringify(presentation.slideSize));
const chart = presentation.resolve('ch/7m5s7yhs');
const logo = presentation.resolve('im/ri9kvmxs');
console.log('chartData', JSON.stringify({title:chart.title,categories:chart.categories,series:chart.series.items.map(s=>({name:s.name,categories:s.categories,values:s.values}))}));
console.log('templateImage', JSON.stringify({fit:logo.fit,crop:logo.crop,geometry:logo.geometry,frame:logo.frame}));
for (const id of ['sh/p4bu5s76','sh/uxgjq907','sh/wzy1szid','sh/i1gje90j','sh/9sfylgbq','sh/nydczmpk','sh/mx4v6hoz']) { const s=presentation.resolve(id); console.log(id,JSON.stringify({style:s.text.style,vertical:s.text.verticalAlignment,autoFit:s.text.autoFit,wrap:s.text.wrap,insets:s.text.insets})); }
