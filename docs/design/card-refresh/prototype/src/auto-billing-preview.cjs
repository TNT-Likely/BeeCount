const fs=require('fs'),path=require('path'),m=require('./auto-billing-module.cjs'),fixtures=require('./auto-billing-samples.cjs');
const here=path.resolve(__dirname,'..'),root=path.resolve(here,'../../../..'),out=path.join(root,'.docs/v4-ui-migration');let html=fs.readFileSync(path.join(here,'demo.html'),'utf8');
if(html.includes('const ab92Texts='))throw Error('Module already in root build');
html=html.replace('const views={',()=>m.javascript+'\nconst views={').replace('</head>',()=>'<style>'+m.css+'</style></head>');
for(const f of ['vendor/lucide.min.js','scene-presets.js'])html=html.replace(`<script src="${f}"></script>`,()=>'<script>'+fs.readFileSync(path.join(here,f),'utf8')+'</script>');
html=html.replace('const qInitialScene=qApplyPreviewLink();',"if(!new URLSearchParams(location.search).has('page'))state.page='flow-auto-billing-ios';\nconst qInitialScene=qApplyPreviewLink();");
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'r92-auto-billing-preview.html'),html);fs.writeFileSync(path.join(out,'r92-auto-billing-guide.html'),'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>自动记账两平台</title><style>body{background:#f5f6f7}'+m.css+'</style>'+fixtures.guide.replaceAll('../prototype/demo.html','r92-auto-billing-preview.html')+'</html>');
console.log('Independent r92 preview/guide written; 15 page states + controlled components.');
