const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
for(const p of ['qa','figma/html','screens/viewport','screens/full','boards','reference/recording'])fs.mkdirSync(path.join(root,p),{recursive:true});
