const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.env.SOULBUDDY_SHARP || 'C:/Users/Son/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = __dirname;
const file = p => path.join(root, p);
const svg = (w,h,body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`);
const escape = s => s.replaceAll('&','&amp;').replaceAll('<','&lt;');
const png = async (input,out) => sharp(input).removeAlpha().png({compressionLevel:9}).toFile(file(out));
const items = [
 {src:'today-device.png',name:'01-grow-closer.png',lines:['Grow closer','to God.'],sub:'PRAYER · SCRIPTURE · REFLECTION',bg:'#173d31'},
 {src:'orientation-device.png',name:'02-lasting-fruit.png',lines:['Small seeds.','Lasting fruit.'],sub:'EIGHT NUGGETS · SEVEN TENETS',bg:'#263e33'}
];
async function screenshot(item) {
  // Only Android system bars are excluded. The app content is neither retouched nor recreated.
  const source=file('sources/'+item.src);
  const meta=await sharp(source).metadata();
  if(meta.width!==1280 || meta.height!==2800) throw new Error('Unexpected capture dimensions');
  const screenshot=await sharp(source).extract({left:0,top:158,width:1280,height:2505}).resize({width:738}).png().toBuffer();
  const sm=await sharp(screenshot).metadata();
  const top=405, left=171;
  const background=svg(1080,1920,`
    <defs><radialGradient id="light" cx="95%" cy="85%" r="90%"><stop stop-color="#6a6744"/><stop offset="1" stop-color="${item.bg}"/></radialGradient><filter id="shadow" x="-50%" y="-20%" width="200%" height="160%"><feGaussianBlur stdDeviation="28"/></filter></defs>
    <rect width="1080" height="1920" fill="url(#light)"/>
    <path d="M-100 1740 Q100 1200 570 1220 T1210 600" stroke="#d2b571" stroke-opacity=".12" stroke-width="2" fill="none"/>
    <path d="M-80 1770 Q140 1270 600 1250 T1240 650" stroke="#d2b571" stroke-opacity=".08" stroke-width="2" fill="none"/>
    <text x="76" y="74" font-family="Georgia" font-size="32" fill="#f9edd2">SoulBuddy</text>
    <path d="M920 63h84" stroke="#cba464" stroke-width="2"/>
    ${item.lines.map((s,i)=>`<text x="76" y="${184+i*93}" font-family="Georgia" font-size="91" letter-spacing="-3" fill="#fbf1dc">${escape(s)}</text>`).join('')}
    <text x="79" y="333" font-family="Segoe UI" font-size="23" letter-spacing="4" fill="#d6bd89">${item.sub}</text>
    <rect x="161" y="438" width="758" height="${sm.height}" rx="30" fill="#071e17" opacity=".6" filter="url(#shadow)"/>
    <rect x="163" y="397" width="754" height="${sm.height+16}" rx="10" fill="#d6c4a0"/>
    <rect x="165" y="399" width="750" height="${sm.height+12}" rx="8" fill="#fff5df"/>
  `);
  await png(await sharp(background).composite([{input:screenshot,left,top}]).toBuffer(), 'upload/en-GB/phone-screenshots/'+item.name);
}
const icons={
  prayer:'<path d="M24 8v25m0-19c-5-2-7 3-8 8l-4 10 9 7m3-25c5-2 7 3 8 8l4 10-9 7M12 32l-4 6 10 6 4-7m14-5 4 6-10 6-4-7"/>',
  scripture:'<path d="M24 12c-6-5-13-5-19-3v28c7-2 13-1 19 3 6-4 12-5 19-3V9c-6-2-13-2-19 3Zm0 0v28M11 17c3-1 5 0 7 1m-7 6c3-1 5 0 7 1m12-7c2-1 4-2 7-1m-7 8c2-1 4-2 7-1"/>',
  growth:'<path d="M24 41V25C12 27 8 20 8 10c11 0 17 5 16 15 0-12 6-18 17-19 0 12-5 19-17 19M9 42h30"/>',
  circles:'<circle cx="24" cy="14" r="5"/><path d="M15 32v-2a9 9 0 0 1 18 0v2M9 15a4 4 0 0 0 0 8m30-8a4 4 0 0 1 0 8M4 37v-4a7 7 0 0 1 6-7m34 11v-4a7 7 0 0 0-6-7M16 40h16"/>',
  persons:'<circle cx="24" cy="15" r="7"/><path d="M10 41v-3a14 14 0 0 1 28 0v3Z"/>',
  goals:'<path d="M11 42V7m0 3c10-9 16 8 27-1v22c-11 9-17-8-27 1M5 42h12"/>',
  remember:'<path d="M12 6h24a2 2 0 0 1 2 2v35L24 33 10 43V8a2 2 0 0 1 2-2Z"/>',
  altar:'<path d="m10 41 1-29 12-6 15 9 1 26ZM24 40V24m0 0-7-9m7 9 7-9"/>'
};
async function main(){
 await sharp(file('brand/soulbuddy-icon-1024.png')).resize(512,512).ensureAlpha().png({compressionLevel:9}).toFile(file('upload/en-GB/icon-512.png'));
 await sharp(file('sources/feature-graphic-master.png')).resize(1024,500,{fit:'cover',position:'centre'}).removeAlpha().png({compressionLevel:9}).toFile(file('upload/en-GB/feature-graphic-1024x500.png'));
 for(const item of items) await screenshot(item);
 for(const [name,body] of Object.entries(icons)){
   const data=svg(48,48,`<g fill="none" stroke="#94692d" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">${body}</g>`);
   fs.writeFileSync(file('brand/'+name+'.svg'),data);
   await sharp(data).resize(256,256).png().toFile(file('brand/'+name+'-256.png'));
 }
 for(const name of ['ascent','prayer','scripture','renewal']){
   await sharp(path.resolve(root,'../../../apps/soulbuddy/assets/images/sanctuary/'+name+'.png')).resize({width:800,withoutEnlargement:true}).jpeg({quality:92}).toFile(file('visuals/'+name+'.jpg'));
 }
 const proof=svg(1640,1160,`<rect width="1640" height="1160" fill="#eee8dd"/><text x="50" y="65" font-family="Georgia" font-size="35" fill="#183c30">SoulBuddy</text><text x="1600" y="61" text-anchor="end" font-family="Segoe UI" font-size="18" fill="#766a55">GOOGLE PLAY · ENGLISH</text><text x="50" y="567" font-family="Segoe UI" font-size="18" fill="#766a55">APP ICON</text><text x="50" y="1006" font-family="Segoe UI" font-size="18" fill="#766a55">REUSABLE SYMBOLS</text>`);
 const feature=await sharp(file('upload/en-GB/feature-graphic-1024x500.png')).resize(780).toBuffer();
 const icon=await sharp(file('upload/en-GB/icon-512.png')).resize(300).toBuffer();
 const screen1=await sharp(file('upload/en-GB/phone-screenshots/01-grow-closer.png')).resize(344).toBuffer();
 const screen2=await sharp(file('upload/en-GB/phone-screenshots/02-lasting-fruit.png')).resize(344).toBuffer();
 const layers=[{input:feature,left:50,top:110},{input:icon,left:50,top:590},{input:screen1,left:870,top:110},{input:screen2,left:1240,top:110}];
 let n=0;for(const name of Object.keys(icons)) {layers.push({input:await sharp(file('brand/'+name+'.svg')).resize(60,60).toBuffer(),left:60+n*90,top:1035});n++;}
 // Existing in-app artwork doubles as a reusable marketing library.
 for(const [i,name] of ['prayer','scripture','renewal'].entries()){layers.push({input:await sharp(file('visuals/'+name+'.jpg')).resize(222,305,{fit:'cover'}).toBuffer(),left:870+i*240,top:770});}
 await sharp(proof).composite(layers).jpeg({quality:92}).toFile(file('preview.jpg'));
 const checks=[];
 for(const rel of ['icon-512.png','feature-graphic-1024x500.png',...items.map(i=>'phone-screenshots/'+i.name)]){
   const p=file('upload/en-GB/'+rel), m=await sharp(p).metadata();
   if(rel.startsWith('icon') && (m.width!==512||m.height!==512||!m.hasAlpha||fs.statSync(p).size>1048576))throw new Error('Invalid icon');
   if(!rel.startsWith('icon') && m.hasAlpha)throw new Error('Unexpected alpha');
   if(rel.startsWith('feature') && (m.width!==1024||m.height!==500))throw new Error('Invalid feature');
   if(rel.startsWith('phone') && (m.width!==1080||m.height!==1920))throw new Error('Invalid screenshot');
   checks.push({file:rel,width:m.width,height:m.height,channels:m.channels,alpha:m.hasAlpha,bytes:fs.statSync(p).size});
 }
 fs.writeFileSync(file('validation.json'),JSON.stringify(checks,null,2)+'\n');console.log(JSON.stringify(checks,null,2));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
