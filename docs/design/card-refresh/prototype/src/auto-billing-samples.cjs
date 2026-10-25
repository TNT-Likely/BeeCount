const fs=require('fs'),path=require('path');
const binding=fs.readFileSync(path.resolve(__dirname,'../../../../../lib/presentation/v4/bindings/ios_auto_billing_actions.dart'),'utf8');
const urls=[...binding.matchAll(/Uri.parse\(\s*'(https:[^']+)'/g)].map(m=>m[1]);
if(urls.length!==2)throw Error('Original shortcut/tutorial URLs unavailable');
const defaults={platform:'android',enabled:false,healthy:false,canRequest:true,busy:false,loading:false,loadError:false,batteryError:false,permission:true,enableError:false,disableError:false,oldIOS:false,expanded:false,openError:false};
const scenes=[
 ['auto-billing-android','Android · 默认关闭',{}],['auto-billing-android-on','Android · 已开启',{enabled:true}],
 ['auto-billing-battery-ok','Android · 电池已豁免',{enabled:true,healthy:true}],
 ['auto-billing-battery-error','Android · 电池读取失败',{batteryError:true}],
 ['auto-billing-no-battery-request','Android · 系统不支持请求',{canRequest:false}],
 ['auto-billing-load-error','Android · 状态读取失败可重试',{loadError:true}],
 ['auto-billing-permission-denied','Android · 权限拒绝',{permission:false}],
 ['auto-billing-enable-error','Android · 启用失败',{enableError:true}],
 ['auto-billing-disable-error','Android · 停用失败',{enabled:true,disableError:true}],
 ['auto-billing-busy','Android · 操作处理中',{busy:true}],
 ['auto-billing-ios','iOS · 一键导入与手动兜底',{platform:'ios'}],
 ['auto-billing-ios-old','iOS · 16以下提示',{platform:'ios',oldIOS:true}],
 ['auto-billing-ios-manual','iOS · 展开六步引导',{platform:'ios',expanded:true}],
 ['auto-billing-ios-open-error','iOS · 导入失败',{platform:'ios',openError:true}],
 ['auto-billing-ios-opening','iOS · 外部打开中防重',{platform:'ios',busy:true}],
].map(([key,title,patch])=>({key,title,data:{...defaults,...patch}}));
const guide=`<article class="ab92-guide"><h3>自动记账 · Android / iOS 原平台流程</h3><p>Android 保留截图权限的照片→存储 fallback、监听开关、电池状态和可用时的系统设置入口；iOS 保留原快捷指令导入、视频教程、iOS16要求、轻点背面和折叠六步手动配置。两端动作分开呈现。</p><p>组件只接数据与回调。此独立示例的开关、错误和外部打开只修改局部合成状态，不请求权限、不启用真实监听、不运行快捷指令、不打开外部网页。真实目录 preview 仅读既有启用偏好或iOS支持性。</p><section><b>受控纯组件样例</b><p>教程入口 / 版本提示 / 信息卡 / 操作卡 / 监听状态 / 电池状态 / 手动步骤 / 电池弹窗，全部保持当前业务组件组成。</p><a href="../prototype/demo.html?page=flow-auto-billing-sample">打开与 Flutter 相同的两平台受控样例</a></section><div class="ab92-links">${scenes.map(s=>`<a href="../prototype/demo.html?page=flow-${s.key}">${s.title}</a>`).join('')}</div><p>独立浏览器验证不代表 Android / iOS 原生权限或快捷指令验收。</p></article>`;
module.exports={defaults,scenes,shortcutUrl:urls[0],tutorialUrl:urls[1],guide};
