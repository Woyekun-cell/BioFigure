"use strict";
const copy = {
  en:{
    title:"Figure Atlas", skip:"Skip to figures", catalog:"Atlas", allFiles:"Any files", withCode:"With plotting code", withData:"With plot data",
    withBoth:"With code and data", galleryLayout:"Gallery layout", fileFilter:"Filter by available files", gridMode:"Grid", largeMode:"Large",
    skyIntro:"A figure atlas for genomics and multi-omics.",
    skyDescription:"Open a figure for available code and data.",
    skyExplore:"Explore the atlas",
    skyPulse:"Pulse", skyScroll:"Scroll to the figures", skyPause:"Pause motion", skyResume:"Resume motion",
    skyFigures:"Figures in the constellation", editorialNav:"Collections", guideNav:"Workflow",
    heroFirst:"Selected figures", heroSecond:"from the atlas.",
    intro:"Explore figures for genomics and multi-omics. Open any example to see available plotting code and data.",
    catalogHeading:"Explore the atlas", catalogIntro:"Find a chart type, figure name, or plotting package.", inspect:"Inspect figure", reviewFiles:"View code and data",
    guideTitle:"From an example to your own figure.",
    guideIntro:"BioFigure is an open-source skill for designing, drawing and reviewing figures in biological research.",
    readDocs:"Read the documentation", footerLine:"An open atlas for biological research figures.",
    guideSteps:[
      ["Find a reference","Start with your data","Choose a chart by the relationship you need to show. Start with matrices, genomic tracks, or groups of samples."],
      ["Inspect the figure","Read the figure at full size","Check the labels, scales, and panel alignment. Open a published example and switch to its original dimensions."],
      ["Reuse the materials","Work from the available files","Open the plotting script and input tables where provided. Check whether the example uses simulated data before adapting it."]
    ],
    browse:"Explore the atlas", compare:"Compare", uncompare:"Remove from comparison", compareOpen:"Compare figures", compareClear:"Clear", compareClose:"Close comparison", compareCount:n=>n===1?"One figure selected. Add another.":"Two figures selected.", categories:"Chart types", all:"All figures", more:"Show more", download:"Download figure", close:"Close figure",
    search:"Search figures or packages", empty:"No matching figures.", error:"The atlas could not load. Refresh to try again.",
    editorial:"Multi-panel figures", editorialIntro:"See how aligned tracks, annotations, and panels work together.",
    showcase:"Featured figures", prev:"Previous figure", next:"Next figure", pause:"Pause slideshow", play:"Play slideshow",
    code:"Plotting code", data:"Plot data", noCode:"No verified public plotting script for this figure.",
    noData:"No verified public plot table for this figure.", inlineData:"The plotting script generates the simulated inputs.", sim:"Simulated data", open:"Open figure",
    publisherImage:"View publisher image", viewPaper:"View paper", source:"Source",
    count:n=>n===1?"1 figure":n+" figures", types:n=>n+" chart types", zoom:"Original size"
  },
  zh:{
    title:"科研图谱", skip:"跳到图库", catalog:"图库", allFiles:"不限文件", withCode:"有绘图代码", withData:"有绘图数据",
    withBoth:"有代码和数据", galleryLayout:"图库布局", fileFilter:"按可用文件筛选", gridMode:"网格", largeMode:"大图",
    skyIntro:"基因组与多组学图谱。",
    skyDescription:"点开图例，查看可用的代码和数据。",
    skyExplore:"浏览图谱",
    skyPulse:"触发脉冲", skyScroll:"向下浏览图谱", skyPause:"暂停动效", skyResume:"继续动效",
    skyFigures:"星空中的图例", editorialNav:"精选组图", guideNav:"使用流程",
    heroFirst:"科研图谱", heroSecond:"精选图例",
    intro:"浏览基因组与多组学图例，打开成图查看可用的代码和数据。",
    catalogHeading:"探索图库", catalogIntro:"按图型、图名或绘图包检索。", inspect:"查看大图", reviewFiles:"查看代码和数据",
    guideTitle:"从图例到自己的科研图。",
    guideIntro:"BioFigure 是用于生物科研图设计、绘制和审查的开源技能。",
    readDocs:"阅读文档", footerLine:"开放的生物科研图谱。",
    guideSteps:[
      ["找图例","从数据关系出发","按需要表达的关系选图。可以先看矩阵、基因组轨道或样本分组。"],
      ["看细节","用原始尺寸查看","核对标注、刻度和面板对齐。打开图例，可以切换到原始尺寸。"],
      ["取文件","查看公开文件","打开可用的绘图脚本和输入表。改用自己的数据前，留意示例是否使用模拟数据。"]
    ],
    browse:"浏览图库", compare:"加入对照", uncompare:"移出对照", compareOpen:"图型对照", compareClear:"清空", compareClose:"关闭对照", compareCount:n=>n===1?"已选 1 张，再选 1 张即可对照。":"已选 2 张图。", categories:"图型", all:"全部图例", more:"显示更多", download:"下载成图", close:"关闭图例",
    search:"搜索图型或绘图包", empty:"没有匹配的图例。", error:"图库加载失败，请刷新重试。",
    editorial:"多面板组图", editorialIntro:"对齐的基因组轨道、多层注释和共享坐标的组图。",
    showcase:"精选图例", prev:"上一张", next:"下一张", pause:"暂停轮播", play:"播放轮播",
    code:"绘图代码", data:"绘图数据", noCode:"这张图暂缺已核验的公开绘图脚本。",
    noData:"这张图暂缺已核验的公开绘图表。", inlineData:"绘图脚本生成图中使用的模拟输入。", sim:"模拟数据", open:"打开图例",
    publisherImage:"查看出版社原图", viewPaper:"查看论文", source:"来源",
    count:n=>n+" 张图", types:n=>n+" 种图型", zoom:"原始尺寸"
  }
};

Object.assign(copy.en, {
  apiOpenAI:"OpenAI-compatible", apiAnthropic:"Claude (Anthropic)", apiGemini:"Gemini", apiProtocol:"API protocol", apiBaseUrl:"Base URL (required)", apiClearKey:"Clear saved API Key", apiKeySaved:"API Key saved. Leave the password blank to keep it.", apiKeyMissing:"No API Key saved for this connection.", apiKeyChanged:"Changing the protocol or Base URL requires a new API Key.", apiKeyPlaceholder:"Enter an API Key", apiKeyKeep:"Saved · leave blank to keep", apiModelPlaceholder:"Enter the API model name", apiNeedsSetup:"Set a model and API Key", apiModelMissing:"Model not set", apiReadyHint:"Use a model that supports images and tool calls for questions and redraws.",
  agentSettings:"Connection settings", agentHost:"Agent connection", agentModel:"Model (optional)", apiModelLabel:"API model (required)", modelPlaceholder:"Use the selected CLI configuration", defaultModel:"CLI default model", saveAgent:"Save connection settings", savingAgent:"Saving…", savedAgent:"Connection settings saved for this profile.", hostNotInstalled:"Not installed", installHost:"Install and sign in to the selected CLI to use it.", hostInstalled:"Installed CLI. The selected host runs questions and figure revisions.", hostBusy:"Finish the current question or render before changing the connection.",
  manage:"Manage figures", manageLocal:"Changes apply to your local gallery profile.", managePreview:"View figure", manageSearch:"Search cards", manageShow:"Show", manageVisible:"In gallery", manageRemoved:"Removed", manageSelected:n=>n+" selected", manageRemove:"Remove selected", manageRestore:"Restore selected", manageClose:"Close figure manager", manageEdit:"Edit", manageSave:"Save", manageBack:"Back", manageReset:"Reset details", manageTitleEn:"English title", manageTitleZh:"Chinese title", manageIntroEn:"English description", manageIntroZh:"Chinese description", manageHidden:n=>n+" removed. Restore them from Removed.", manageRestored:n=>n+" restored.", manageSaved:"Changes saved.", manageResetDone:"Original details restored.",
  compareCount:n=>n+" selected", compare:"Select", uncompare:"Selected",
  askTitle:"Ask BioFigure", askSelected:"Ask with selection", askFigure:"Ask with this figure",
  starredOnly:"Starred", referenceSource:"References", selectedRefs:"Selected figures", starredRefs:"Starred figures", textOnly:"Text only",
  localSetup:"Start your local BioFigure CLI, then continue with your selected figures and question.", openLocal:"Connect local CLI",
  disconnected:"Connect your local CLI to ask and redraw.", connected:"Connected to", noHost:"CLI is unavailable",
  checking:"Checking local connection…", questionLabel:"What would you like to draw or change?", hostHint:"Your question and chosen figures go to the selected Agent connection.",
  sendQuestion:"Ask", thinking:"The Agent is preparing a proposal…", reply:"Design proposal", execute:"Execute this revision", targetLabel:"Figure to modify", noReferences:"No figures included",
  needsInput:"More input is needed before rendering.", rendering:"Rendering your revision…", rendered:"New figure ready", renderFailed:"Rendering failed. You can retry the proposal.", renderQueued:"Revision queued…",
  followupLabel:"Continue editing this result", renderAgain:"Render another revision", reviewHint:"Rendered output · check the figure before using it.",
  actionApplied:"Applied", saveReference:"Add reference", removeReference:"Remove reference", starAction:"Star reference", unstarAction:"Remove star",
  missingTarget:"Choose a figure to modify.", connectionError:"The local CLI connection is unavailable.", starError:"The star could not be saved.", askClose:"Close question", removeRef:"Remove reference"
});
Object.assign(copy.zh, {
  apiOpenAI:"OpenAI兼容", apiAnthropic:"Claude (Anthropic)", apiGemini:"Gemini", apiProtocol:"API 协议", apiBaseUrl:"API 地址（Base URL，必填）", apiClearKey:"清除已保存的 API Key", apiKeySaved:"API Key 已保存，密码框留空可保留。", apiKeyMissing:"该连接尚未保存 API Key。", apiKeyChanged:"切换协议或 API 地址后，需要重新填写 API Key。", apiKeyPlaceholder:"输入 API Key", apiKeyKeep:"已保存，留空保留", apiModelPlaceholder:"填写 API 模型名称", apiNeedsSetup:"请配置模型与 API Key", apiModelMissing:"尚未配置模型", apiReadyHint:"模型需支持图像和工具调用，用于提问和重绘。",
  agentSettings:"服务设置", agentHost:"服务", agentModel:"模型（选填）", apiModelLabel:"API 模型（必填）", modelPlaceholder:"沿用所选 CLI 配置", defaultModel:"CLI 默认模型", saveAgent:"保存服务设置", savingAgent:"正在保存…", savedAgent:"已保存到当前个人档案。", hostNotInstalled:"未安装", installHost:"安装并登录所选 CLI 后即可使用。", hostInstalled:"已找到该 CLI，提问和重绘由它执行。", hostBusy:"当前提问或重绘完成后可切换服务。",
  manage:"管理图卡", manageLocal:"更改保存在本机个人图库档案中。", managePreview:"查看原图", manageSearch:"搜索图卡", manageShow:"显示", manageVisible:"图库中", manageRemoved:"已移除", manageSelected:n=>"已选 "+n+" 张", manageRemove:"移除所选", manageRestore:"恢复所选", manageClose:"关闭图卡管理", manageEdit:"编辑", manageSave:"保存", manageBack:"返回", manageReset:"恢复原信息", manageTitleEn:"英文图名", manageTitleZh:"中文图名", manageIntroEn:"英文说明", manageIntroZh:"中文说明", manageHidden:n=>"已移除 "+n+" 张，可在「已移除」中恢复。", manageRestored:n=>"已恢复 "+n+" 张。", manageSaved:"已保存。", manageResetDone:"已恢复原始信息。",
  compareCount:n=>"已选 "+n+" 张", compare:"选择", uncompare:"已选择",
  askTitle:"问 BioFigure", askSelected:"带所选图提问", askFigure:"带这张图提问",
  starredOnly:"星标", referenceSource:"参考图", selectedRefs:"所选图", starredRefs:"星标图", textOnly:"仅文字",
  localSetup:"启动本机 BioFigure CLI 后，继续使用所选图和问题。", openLocal:"连接本机 CLI",
  disconnected:"连接本机 CLI 后即可提问、重绘。", connected:"已连接", noHost:"CLI 尚不可用",
  checking:"正在检查本机连接…", questionLabel:"想画什么，或想怎样修改？", hostHint:"问题和所选图会交给当前选择的服务。",
  sendQuestion:"提交问题", thinking:"Agent 正在准备方案…", reply:"设计方案", execute:"执行此修改", targetLabel:"要修改的图", noReferences:"本次没有附图",
  needsInput:"需要补充材料后才能重绘。", rendering:"正在重绘…", rendered:"新图已生成", renderFailed:"重绘失败，可以重试方案。", renderQueued:"修改已排队…",
  followupLabel:"继续修改这张新图", renderAgain:"再次重绘", reviewHint:"已生成成图，请核对后使用。",
  actionApplied:"已应用", saveReference:"加入参考", removeReference:"移出参考", starAction:"标记星标", unstarAction:"取消星标",
  missingTarget:"请选择要修改的图。", connectionError:"本机服务连接暂不可用。", starError:"星标未能保存。", askClose:"关闭提问", removeRef:"移出参考"
});

const $=id=>document.getElementById(id);
const text=()=>copy[lang];
const search=$("search"), grid=$("grid"), detail=$("detail"), empty=$("empty"), showcase=$("showcase");
const reduce=matchMedia("(prefers-reduced-motion: reduce)");
const hoverable=matchMedia("(hover: hover)");
const pageSize=24;
let layoutMotion, largeLayout=false;
let sky;
let filteredRows=[], detailRows=[], detailIndex=0;
const selectedFigures=new Map();
const comparison=$("comparison"), ask=$("ask"), manager=$("manage");
let hiddenFigures=new Set(), figureEdits={}, figureById=new Map(), skyRows=[];
let managing=false, managedId=null;
const manageSelected=new Set();
const localAtlas=["127.0.0.1","localhost"].includes(location.hostname);
const browserStarsKey="biofigure-atlas-stars";
const renderSessionKey="biofigure-render-session";
let stars=new Set(), starredOnly=false, libraryConnected=false, hostAvailable=false, checkingHost=localAtlas;
let askRefs=[], asking=false, rendering=false, lastRenderJob=null, renderRequest=null, renderPoll=0;
let hostStatus=null, hostSaving=false;
try { stars=new Set(JSON.parse(localStorage.getItem(browserStarsKey)||"[]")); } catch {}

let lang="en", atlas, categories, featured=[], plates=[], current=0, currentFigure, category="all", limit=pageSize;
let play=!reduce.matches, onScreen=false, timer, animation, meterAnimation, startPoint, lastSwipe=-Infinity;
try { if (localStorage.getItem("biofigure-atlas-lang")==="zh") lang="zh"; } catch {}
let guideStep=0;
const label=id=>id==="all"?text().all:categories.get(id)[lang];
function node(tag, name, value) {
  const el=document.createElement(tag);
  if(name)el.className=name;
  if(value)el.textContent=value;
  return el;
}
function icon(name) {
  const el=document.createElementNS("http://www.w3.org/2000/svg","svg");
  const use=document.createElementNS("http://www.w3.org/2000/svg","use");
  el.setAttribute("class","icon");el.setAttribute("aria-hidden","true");
  use.setAttribute("href","#i-"+name);el.append(use);
  return el;
}
function setLanguage() {
  document.documentElement.lang=lang==="en"?"en":"zh-CN";
  document.title="BioFigure · "+text().title;
  document.querySelectorAll("[data-copy]").forEach(el=>{el.textContent=text()[el.dataset.copy];});
  $("language").textContent=lang==="en"?"中文":"English";
  $("language").lang=lang==="en"?"zh-CN":"en";
  search.placeholder=text().search;search.setAttribute("aria-label",text().search);
  $("close").setAttribute("aria-label",text().close);
  $("category-mobile").setAttribute("aria-label",text().categories);
  $("resource-filter").setAttribute("aria-label",text().fileFilter);
  document.querySelector(".layout-controls").setAttribute("aria-label",text().galleryLayout);
  showcase.setAttribute("aria-label",text().showcase);
  $("prev").setAttribute("aria-label",text().prev);$("next").setAttribute("aria-label",text().next);
  $("compare-close").setAttribute("aria-label",text().compareClose);
  updateComparison();
  updateAgent();
  updateStars();
  $("detail-prev").setAttribute("aria-label",text().prev);
  $("detail-next").setAttribute("aria-label",text().next);
  sky?.translate(lang,text());
  updateSkyCuration();
  if(!atlas)return;
  $("figure-total").textContent=text().count(atlas.figures.length-hiddenFigures.size);
  $("type-total").textContent=text().types(categories.size);
  const thumbs=featured.map((row,i)=>{
    const button=node("button","thumb action");
    button.type="button";button.dataset.index=i;
    button.setAttribute("aria-label",row.chart[lang]);
    button.title=row.chart[lang];
    const image=node("img");image.src=row.thumbnail;image.alt="";
    const caption=node("span","thumb-caption");
    caption.append(node("strong","",row.chart[lang]),node("span","",label(row.category)));
    button.append(image,caption);
    return button;
  });
  $("thumbs").replaceChildren(...thumbs);
  show(current,0);
  updatePlayback();
  $("plates").replaceChildren(...plates.map(row=>card(row,plates)));
  $("editorial").hidden=plates.length===0;
  if(manager.open)renderManager();
  categoryNav();render();showGuide(guideStep,false);
  if(detail.open)fillDetail(currentFigure);
}
function show(index,direction) {
  if(!featured.length){showcase.hidden=true;return;}
  showcase.hidden=false;
  current=(index+featured.length)%featured.length;
  const row=featured[current];
  const previous=$("featured-image");
  $("featured-title").textContent=row.chart[lang];
  $("feature-type").textContent=label(row.category)+(row.simulated?" · "+text().sim:"");
  $("feature-position").textContent=(current+1)+" / "+featured.length;
  $("featured").setAttribute("aria-label",text().open+" — "+row.chart[lang]);
  for(const button of $("thumbs").children)
    button.setAttribute("aria-current",String(Number(button.dataset.index)===current));
  if(previous?.getAttribute("src")===row.thumbnail)return;
  animation?.cancel();
  const stage=$("featured");
  stage.querySelector(".stage-outgoing")?.remove();
  const image=node("img");
  image.id="featured-image";image.alt="";image.fetchPriority=previous?"auto":"high";image.src=row.thumbnail;
  if(previous)previous.replaceWith(image);
  else stage.prepend(image);
  showcase.style.setProperty("--position",(current+1)/featured.length);
  if(direction&&!reduce.matches&&previous?.complete&&previous.naturalWidth){
    previous.id="";
    previous.className="stage-outgoing";
    stage.prepend(previous);
    image.decode().then(()=>{
      if(!image.isConnected||image.id!=="featured-image")return;
      previous.animate([{opacity:1},{opacity:0}],{duration:320,fill:"forwards"});
      animation=image.animate([{opacity:.18,transform:`translateX(${direction*24}px)`},{opacity:1,transform:"none"}],
        {duration:420,easing:"cubic-bezier(.16,1,.3,1)"});
      animation.finished.catch(()=>{}).then(()=>previous.remove());
    }).catch(()=>previous.remove());
  }
}

function updatePlayback() {
  clearTimeout(timer);
  meterAnimation?.cancel();
  const control=$("autoplay");
  control.setAttribute("aria-pressed",String(play));
  control.setAttribute("aria-label",play?text().pause:text().play);
  control.querySelector("use").setAttribute("href",play?"#i-pause":"#i-play");
  const focused=showcase.contains(document.activeElement)&&document.activeElement!==control;
  const hovered=hoverable.matches&&showcase.matches(":hover")&&!control.matches(":hover");
  if(play && featured.length>1 && onScreen && !document.hidden && !detail.open && !comparison.open && !ask.open && !manager.open && !focused && !hovered) {
    if(!reduce.matches){
      meterAnimation=showcase.querySelector(".feature-meter span").animate(
        [{transform:"scaleX(0)"},{transform:"scaleX(1)"}],{duration:4800,fill:"both"}
      );
    }
    timer=setTimeout(()=>{show(current+1,1);updatePlayback();},4800);
  }
}
function manual(index,direction) {
  show(index,direction);
  updatePlayback();
}
function categoryNav() {
  const choices=["all",...categories.keys()];
  $("category-nav").replaceChildren(...choices.map(id=>{
    const button=node("button","action",label(id));button.type="button";button.dataset.category=id;
    button.setAttribute("aria-pressed",String(id===category));return button;
  }));
  $("category-mobile").replaceChildren(...choices.map(id=>new Option(label(id),id,false,id===category)));
}
function chooseCategory(id) {
  category=id;limit=pageSize;
  if(id==="graphical-abstracts")$("resource-filter").selectedIndex=0;
  $("category-mobile").value=id;
  for(const button of $("category-nav").querySelectorAll("button"))
    button.setAttribute("aria-pressed",String(button.dataset.category===id));
  render({motion:true});
  if($("catalog").getBoundingClientRect().top<0)$("catalog").scrollIntoView();
}
function showGuide(index,motion=true) {
  guideStep=index;
  const steps=text().guideSteps;
  document.querySelectorAll("[data-guide]").forEach((button,i)=>{
    button.textContent=steps[i][0];
    button.setAttribute("aria-pressed",String(index===i));
  });
  $("guide-step-title").textContent=steps[index][1];
  $("guide-step-copy").textContent=steps[index][2];
  const links=$("guide-links");
  links.replaceChildren();
  if(index===0){
    for(const id of ["heatmap","genome","scatter"]){
      const button=node("button","guide-chip action",label(id));
      button.type="button";
      button.addEventListener("click",()=>{
        search.value="";
        chooseCategory(id);
        $("catalog").scrollIntoView();
        search.focus({preventScroll:true});
      });
      links.append(button);
    }
  }else{
    const row=index===1?featured[1]:featured[0];
    const button=node("button","guide-chip action",index===1?text().inspect:text().reviewFiles);
    button.type="button";
    button.addEventListener("click",()=>openDetail(row,featured));
    links.append(button);
  }
  if(motion&&!reduce.matches){
    const panel=$("guide-panel");
    panel.getAnimations().forEach(animation=>animation.cancel());
    panel.animate([{opacity:.42,transform:"translateX(14px)"},{opacity:1,transform:"none"}],
      {duration:290,easing:"cubic-bezier(.16,1,.3,1)"});
  }
}
document.querySelector(".guide-choices").addEventListener("click",event=>{
  const step=event.target.closest("[data-guide]");
  if(atlas&&step)showGuide(Number(step.dataset.guide));
});
function packageTags(packages) {
  return packages.map(name=>node("span","package",name));
}
function updateComparison() {
  const count=selectedFigures.size;
  $("compare-dock").hidden=count===0;
  $("compare-status").textContent=count?text().compareCount(count):"";
  $("compare-open").disabled=count<2;
  for(const button of document.querySelectorAll("[data-compare-id]")){
    const selected=selectedFigures.has(button.dataset.compareId);
    button.textContent=selected?text().uncompare:text().compare;
    button.setAttribute("aria-pressed",String(selected));
    button.disabled=false;
  }
}
function card(row, source) {
  const button=node("button","card action");button.type="button";
  const media=node("span","card-media");
  if(row.thumbnail){
    const image=node("img");image.src=row.thumbnail;image.alt="";image.loading="lazy";image.decoding="async";
    media.append(image);
  }else{
    media.append(node("span","publisher-note",row.intro[lang]));
  }
  const packages=node("span","package-list");
  packages.append(...packageTags(row.packages));
  button.append(media,node("strong","",row.chart[lang]),packages);
  button.addEventListener("click",()=>openDetail(row,source??filteredRows));
  const entry=node("article","figure-entry");
  entry.dataset.figureId=row.id;
  const compare=node("button","compare-action action");
  compare.type="button";
  compare.dataset.compareId=row.id;
  compare.title=row.chart[lang];
  compare.addEventListener("click",()=>{
    if(selectedFigures.has(row.id))selectedFigures.delete(row.id);
    else selectedFigures.set(row.id,row);
    updateComparison();
  });
  entry.append(button);
  const controls=node("div","figure-actions");
  const star=node("button","star-action action",stars.has(row.id)?"★":"☆");
  star.type="button";star.dataset.starId=row.id;
  star.title=row.chart[lang];star.setAttribute("aria-label",text().starAction+" · "+row.chart[lang]);
  star.setAttribute("aria-pressed",String(stars.has(row.id)));
  star.addEventListener("click",()=>setStar(row.id,!stars.has(row.id)).catch(error=>showGalleryError(error.message)));
  if(row.thumbnail)controls.append(compare);
  if(localAtlas)controls.append(star);entry.append(controls);
  return entry;
}
function render({append=false,motion=false}={}) {
  const words=search.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const fileFilter=$("resource-filter").value;
  const rows=filteredRows=[...rowsById().values()].filter(row=>{
    if(hiddenFigures.has(row.id))return false;
    if(starredOnly&&!stars.has(row.id))return false;
    if(category!=="all"&&!row.categories.includes(category))return false;
    if((fileFilter==="code"||fileFilter==="both")&&!row.resources.code.length)return false;
    if((fileFilter==="data"||fileFilter==="both")&&!row.resources.data.length)return false;
    if(!words.length)return true;
    const ref=row.reference;
    const metadata=ref?[ref.doi,ref.credit,String(ref.year),...ref.tags]:[];
    const terms=[row.title.en,row.title.zh,row.chart.en,row.chart.zh,...row.packages,...metadata,
      ...row.categories.flatMap(id=>Object.values(categories.get(id)))].join(" ").toLowerCase();
    return words.every(word=>terms.includes(word));
  });
  const next=rows.slice(append?grid.children.length:0,limit).map(row=>card(row));
  if(append)grid.append(...next);else grid.replaceChildren(...next);
  if((motion||append)&&!reduce.matches){
    next.slice(0,8).forEach((entry,index)=>entry.animate(
      [{opacity:.25,transform:"translateY(12px)"},{opacity:1,transform:"none"}],
      {duration:310,delay:index*28,fill:"backwards",easing:"cubic-bezier(.16,1,.3,1)"}
    ));
  }
  $("catalog-title").textContent=label(category);
  $("result-count").textContent=text().count(rows.length);
  empty.hidden=Boolean(rows.length);empty.textContent=text().empty;
  $("more").hidden=limit>=rows.length;
  updateComparison();
  if(append&&next.length)next[0].querySelector(".card").focus();
}
function resources(kind,items) {
  const target=$("detail-"+kind);
  if(!items.length) {
    target.replaceChildren(node("p","",kind==="code"?text().noCode:text().noData));return;
  }
  const list=node("ul");
  let prefix=[];
  if(kind==="data"&&items.length>1){
    const names=items.map(item=>item.name.split("_"));
    prefix=names[0].slice(0,-1);
    while(prefix.length&&!names.every(name=>name.slice(0,prefix.length).join("_")===prefix.join("_")))
      prefix.pop();
  }
  for(const item of items) {
    const short=item.name.split("_").slice(prefix.length).join("_").replace(/_20\d{6}(?=\.)/,"");
    const link=node("a","",short||item.name);link.href=item.url;link.title=item.name;
    if(item.origin==="github"){link.target="_blank";link.rel="noopener";link.append(icon("link"));}
    else{link.download=item.name;link.append(icon("down"));}
    const li=node("li");li.append(link);list.append(li);
  }
  target.replaceChildren(list);
}
function publisherLink(url,label) {
  const link=node("a","",label);
  link.href=url;link.target="_blank";link.rel="noopener noreferrer";
  return link;
}
function fillDetail(row) {
  const ref=row.reference;
  const currentImage=$("detail-image");
  const figure=$("detail-figure");
  const zoom=$("detail-zoom");
  zoom.hidden=!row.thumbnail;
  if(!row.thumbnail){
    figure.classList.remove("actual-size");
    figure.removeAttribute("tabindex");
    zoom.disabled=true;
    zoom.setAttribute("aria-pressed","false");
    const original=publisherLink(ref.original,text().publisherImage);
    original.className="secondary action";
    original.append(icon("link"));
    figure.replaceChildren(original);
  } else if(currentImage?.dataset.figure===row.id) {
    currentImage.alt=row.chart[lang];
  } else {
    const preview=node("img");
    preview.id="detail-image";preview.dataset.figure=row.id;
    preview.alt=row.chart[lang];preview.src=row.thumbnail;
    figure.classList.remove("actual-size");
    figure.removeAttribute("tabindex");
    figure.scrollTo(0,0);
    $("detail-zoom").disabled=true;
    $("detail-zoom").setAttribute("aria-pressed","false");
    figure.replaceChildren(preview);
    const full=new Image();
    full.src=row.image;
    full.decode().then(()=>{
      if(!preview.isConnected||!detail.open)return;
      full.id=preview.id;full.dataset.figure=row.id;full.alt=preview.alt;
      preview.replaceWith(full);
      $("detail-zoom").disabled=false;
    }).catch(()=>{ /* Keep the current preview if the full-size image fails. */ });
  }
  $("detail-title").textContent=row.chart[lang];
  $("detail-packages").replaceChildren(...packageTags(row.packages));
  const description=row.intro[lang];
  $("detail-intro").textContent=row.simulated&&!/simulat|模拟/i.test(description)?text().sim+". "+description:description;
  const download=$("download");
  download.hidden=Boolean(ref&&!row.image);
  download.href=ref?ref.original:(row.pdf||row.image);
  download.querySelector("span").textContent=ref?text().publisherImage:text().download;
  download.querySelector("use").setAttribute("href",ref?"#i-link":"#i-down");
  if(ref){
    download.removeAttribute("download");
    download.target="_blank";download.rel="noopener noreferrer";
  }else{
    download.download=row.id+(row.pdf?".pdf":".webp");
    download.removeAttribute("target");download.removeAttribute("rel");
  }
  $("detail-code").closest("section").hidden=Boolean(ref);
  $("detail-data").closest("section").hidden=Boolean(ref);
  const source=$("detail-source");
  source.hidden=!ref;
  if(ref){
    const credit=node("p","",ref.credit+" · "+ref.journal+" · "+ref.year);
    const sources=node("p");
    sources.append(publisherLink(ref.paper,text().viewPaper));
    if(ref.license){
      const license=ref.license.split("/").at(-3).toUpperCase();
      sources.append(" · ",publisherLink(ref.license,"CC "+license+" 4.0"));
    }
    source.replaceChildren(node("h3","",text().source),credit,sources);
  }
  const data=row.resources.data;
  $("data-title").textContent=data.length&&data.every(item=>item.origin==="synthetic")?
    text().data+" · "+text().sim:text().data;
  resources("code",row.resources.code);
  if(row.data_in_code&&!data.length)$("detail-data").replaceChildren(node("p","",text().inlineData));
  else resources("data",data);
}
function showDetail(index) {
  detailIndex=(index+detailRows.length)%detailRows.length;
  currentFigure=detailRows[detailIndex];
  $("detail-position").textContent=(detailIndex+1)+" / "+detailRows.length;
  $("detail-prev").disabled=$("detail-next").disabled=detailRows.length<2;
  fillDetail(currentFigure);
  if(detail.open&&!reduce.matches){
    $("detail-image")?.animate([{opacity:.4,transform:"translateY(8px)"},{opacity:1,transform:"none"}],
      {duration:250,easing:"cubic-bezier(.16,1,.3,1)"});
  }
}
function openDetail(row, source) {
  detailRows=source;
  showDetail(detailRows.indexOf(row));
  detail.showModal();
  detail.scrollTop=0;
  updatePlayback();
}
$("language").addEventListener("click",()=>{
  lang=lang==="en"?"zh":"en";try{localStorage.setItem("biofigure-atlas-lang",lang);}catch{}
  setLanguage();
});
$("category-nav").addEventListener("click",event=>{
  const button=event.target.closest("button[data-category]");if(button)chooseCategory(button.dataset.category);
});
$("category-mobile").addEventListener("change",event=>chooseCategory(event.target.value));
$("resource-filter").addEventListener("change",()=>{limit=pageSize;render({motion:true});});
function setGalleryLayout(large) {
  if(largeLayout===large)return;
  largeLayout=large;
  const update=()=>{
    if(largeLayout!==large)return;
    grid.classList.toggle("large-grid",large);
    $("layout-grid").setAttribute("aria-pressed",String(!large));
    $("layout-large").setAttribute("aria-pressed",String(large));
  };
  layoutMotion?.skipTransition();
  if(reduce.matches||!document.startViewTransition) {
    update();
    return;
  }
  const root=document.documentElement;
  root.classList.add("gallery-transition");
  const cards=[...grid.children].filter(card=>{
    const rect=card.getBoundingClientRect();
    return rect.bottom>0&&rect.top<innerHeight;
  });
  for(const card of cards)card.style.viewTransitionName="figure-"+card.dataset.figureId;
  const transition=document.startViewTransition(update);
  layoutMotion=transition;
  transition.finished.catch(()=>{}).finally(()=>{
    if(layoutMotion!==transition)return;
    root.classList.remove("gallery-transition");
    for(const card of grid.children)card.style.removeProperty("view-transition-name");
    layoutMotion=undefined;
  });
}
$("layout-grid").addEventListener("click",()=>setGalleryLayout(false));
$("layout-large").addEventListener("click",()=>setGalleryLayout(true));

search.addEventListener("input",()=>{if(atlas){limit=pageSize;render({motion:true});}});
$("more").addEventListener("click",()=>{limit+=pageSize;render({append:true});});
$("close").addEventListener("click",()=>detail.close());
// Older browsers retain light dismissal when the gesture starts on the backdrop.
if (!("closedBy" in HTMLDialogElement.prototype)) {
  for(const dialog of [detail,comparison,ask,manager]){
    let beganOnBackdrop=false;
    dialog.addEventListener("pointerdown",event=>{beganOnBackdrop=event.target===dialog;});
    dialog.addEventListener("click",event=>{
      if(beganOnBackdrop&&event.target===dialog)dialog.close();
      beganOnBackdrop=false;
    });
  }
}
$("compare-clear").addEventListener("click",()=>{
  selectedFigures.clear();
  updateComparison();
  search.focus({preventScroll:true});
});
$("compare-open").addEventListener("click",()=>{
  const figures=Array.from(selectedFigures.values()).map(row=>{
    const plate=node("figure","compare-plate");
    const image=node("img");
    image.src=row.image;
    image.alt=row.chart[lang];
    const caption=node("figcaption","compare-caption");
    caption.append(node("strong","",row.chart[lang]),node("span","",label(row.category)+(row.simulated?" · "+text().sim:"")));
    plate.append(image,caption);
    return plate;
  });
  $("compare-grid").replaceChildren(...figures);
  comparison.showModal();
  updatePlayback();
});
$("compare-close").addEventListener("click",()=>comparison.close());
comparison.addEventListener("close",updatePlayback);
$("detail-prev").addEventListener("click",()=>showDetail(detailIndex-1));
$("detail-next").addEventListener("click",()=>showDetail(detailIndex+1));
$("detail-zoom").addEventListener("click",()=>{
  const figure=$("detail-figure");
  const enlarged=figure.classList.toggle("actual-size");
  $("detail-zoom").setAttribute("aria-pressed",String(enlarged));
  if(enlarged)figure.tabIndex=0;
  else{figure.removeAttribute("tabindex");figure.scrollTo(0,0);}
});
detail.addEventListener("keydown",event=>{
  if(event.altKey||event.metaKey||event.ctrlKey||$("detail-figure").classList.contains("actual-size")||detailRows.length<2)return;
  const direction=event.key==="ArrowRight"?1:event.key==="ArrowLeft"?-1:0;
  if(direction){event.preventDefault();showDetail(detailIndex+direction);}
});
detail.addEventListener("close",()=>{
  if(!detail.open)$("detail-figure").replaceChildren();
  updatePlayback();
});
$("prev").addEventListener("click",()=>manual(current-1,-1));
$("next").addEventListener("click",()=>manual(current+1,1));
$("autoplay").addEventListener("click",()=>{play=!play;updatePlayback();});
$("thumbs").addEventListener("click",event=>{
  const button=event.target.closest("button[data-index]");
  if(button){const index=Number(button.dataset.index);manual(index,Math.sign(index-current));}
});
$("featured").addEventListener("click",()=>{
  if(performance.now()-lastSwipe>350)openDetail(featured[current],featured);
});
showcase.addEventListener("keydown",event=>{
  const direction=event.key==="ArrowRight"?1:event.key==="ArrowLeft"?-1:0;
  if(direction){event.preventDefault();manual(current+direction,direction);}
});
for(const event of ["pointerenter","pointerleave","focusin"])
  showcase.addEventListener(event,updatePlayback);
showcase.addEventListener("focusout",()=>setTimeout(updatePlayback,0));
for(const event of ["pointerenter","pointerleave"])
  $("autoplay").addEventListener(event,updatePlayback);
$("featured").addEventListener("pointerdown",event=>{
  if(event.pointerType==="touch")startPoint=[event.clientX,event.clientY];
});
$("featured").addEventListener("pointercancel",()=>{startPoint=null;});
$("featured").addEventListener("pointerup",event=>{
  if(!startPoint)return;
  const [x,y]=startPoint;startPoint=null;
  const dx=event.clientX-x,dy=event.clientY-y;
  if(Math.abs(dx)>45&&Math.abs(dx)>Math.abs(dy)*1.5){
    const direction=-Math.sign(dx);manual(current+direction,direction);
    lastSwipe=performance.now();
  }
});
const heroSurface=document.querySelector(".upper");
const finePointer=matchMedia("(hover: hover) and (pointer: fine)");
heroSurface.addEventListener("pointermove",event=>{
  if(reduce.matches||!finePointer.matches||event.pointerType==="touch")return;
  const rect=heroSurface.getBoundingClientRect();
  heroSurface.style.setProperty("--light-x",`${event.clientX-rect.left}px`);
  heroSurface.style.setProperty("--light-y",`${event.clientY-rect.top}px`);
  heroSurface.classList.add("is-lit");
},{passive:true});
heroSurface.addEventListener("pointerleave",()=>heroSurface.classList.remove("is-lit"));
document.addEventListener("visibilitychange",updatePlayback);
reduce.addEventListener("change",()=>{
  if(reduce.matches){
    play=false;
    heroSurface.classList.remove("is-lit");
    document.getAnimations().forEach(animation=>animation.cancel());
    document.querySelector(".stage-outgoing")?.remove();
  }
  updatePlayback();
});
new IntersectionObserver(([entry])=>{onScreen=entry.isIntersecting;updatePlayback();},{threshold:.35}).observe(showcase);
setLanguage();
try {
  atlas=JSON.parse($("atlas-data").textContent);
  categories=new Map(atlas.categories.map(item=>[item.id,item.label]));
  const byId=figureById=new Map(atlas.figures.map(row=>[row.id,row]));
  const settings=window.biofigureShowcase;
  function curatedRows(key, count, fallback) {
    const ids=settings?.[key];
    if(!Array.isArray(ids)||ids.length!==count||new Set(ids).size!==count||ids.some(id=>!byId.has(id))){
      return fallback.map(id=>byId.get(id)).filter(Boolean);
    }
    return ids.map(id=>byId.get(id));
  }
  featured=curatedRows("featured",5,atlas.featured);
  plates=atlas.editorial.map(id=>byId.get(id));
  skyRows=curatedRows("sky",6,[...atlas.editorial,...atlas.featured.slice(0,3)]);
  sky=window.createAtlasSky({
    rows:skyRows,
    open: row=>{
      const current=rowsById().get(row.id);
      if(current&&!hiddenFigures.has(row.id)){
        const visible=skyRows.filter(item=>!hiddenFigures.has(item.id));
        openDetail(current,visible.includes(current)?visible:[current]);
      }
    },
    overlayOpen: ()=>detail.open||comparison.open||ask.open||manager.open,
    reduced:reduce,
  });
  document.querySelectorAll("#sky-models .sky-model").forEach((button,index)=>{button.dataset.figureId=skyRows[index]?.id||"";});
  $("inventory").hidden=false;
  showcase.hidden=false;
  $("editorial").hidden=false;
  const params=new URLSearchParams(location.search);
  const requestedType=params.get("type");
  const directFigure=byId.get(params.get("figure"));
  if(categories.has(requestedType))category=requestedType;
  else if(directFigure)category=directFigure.category;
  setLanguage();
  if(directFigure){
    const selection=filteredRows.includes(directFigure)?filteredRows:[directFigure];
    openDetail(directFigure,selection);
    detail.addEventListener("close",()=>search.focus({preventScroll:true}),{once:true});
  }
  connectLibrary();
  consumeAskTransfer();
  resumeRender();
  // A short, one-time entrance based on the React Bits Animated Content pattern.
  if(!reduce.matches&&window.anime){
    const {createTimeline,stagger}=window.anime;
    const entrance=createTimeline()
      .add(".hero-line", {y:[24,0],opacity:[.15,1],duration:660,delay:stagger(105)},0)
      .add(".hero-intro, .hero-actions, .inventory",{y:[12,0],opacity:[.5,1],duration:430,delay:stagger(60)},225)
      .add(showcase,{y:[18,0],opacity:[.5,1],duration:570},140);
    reduce.addEventListener("change",()=>{if(reduce.matches)entrance.revert();});
  }
} catch(error) {
  empty.textContent=text().error;
  empty.hidden=false;
  console.error(error);
}

function showGalleryError(message="") {
  $("gallery-error").textContent=message;
  $("gallery-error").hidden=!message;
}
async function api(route,body) {
  const options=body===undefined?{cache:"no-store"}:{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body)};
  const response=await fetch("./api/"+route,options);
  let result;
  try { result=await response.json(); }
  catch { throw new Error(text().connectionError); }
  if(!response.ok)throw new Error(result.error||response.statusText);
  return result;
}
function rowsById() {
  return figureById;
}
function updateStars() {
  const rows=rowsById();
  $("star-count").textContent=String([...stars].filter(id=>rows.has(id)&&!hiddenFigures.has(id)).length);
  $("filter-stars").setAttribute("aria-pressed",String(starredOnly));
  for(const button of document.querySelectorAll("[data-star-id]")) {
    const starred=stars.has(button.dataset.starId);
    button.textContent=starred?"★":"☆";
    button.setAttribute("aria-pressed",String(starred));
    button.setAttribute("aria-label",text()[starred?"unstarAction":"starAction"]+" · "+(rows.get(button.dataset.starId)?.chart[lang]||""));
  }
}
const starRequests=new Set();
async function setStar(id,marked) {
  if(starRequests.has(id))return;
  starRequests.add(id);
  try {
    if(libraryConnected)await api("star",{id,starred:marked});
    if(marked)stars.add(id);else stars.delete(id);
    if(!libraryConnected)localStorage.setItem(browserStarsKey,JSON.stringify([...stars]));
    updateStars();
    if(starredOnly)render();
    renderAskRefs();
  } finally { starRequests.delete(id); }
}
$("filter-stars").addEventListener("click",()=>{
  starredOnly=!starredOnly;
  limit=pageSize;
  if(starredOnly){search.value="";$("resource-filter").value="all";chooseCategory("all");}
  updateStars();render();
});
function currentAskIds() {
  const mode=$("ask-source").value;
  const ids=mode==="text"?[]:mode==="starred"?[...stars]:askRefs;
  const rows=rowsById();
  return [...new Set(ids)].filter(id=>rows.has(id)&&!hiddenFigures.has(id));
}
function updateLocalLink() {
  const params=new URLSearchParams();
  const ids=currentAskIds();
  if(ids.length)params.set("ask_ids",ids.join(","));
  const question=$("ask-question").value.trim().slice(0,4000);
  if(question)params.set("ask_question",question);
  const link=new URL("http://127.0.0.1:18807/BioFigure/");
  link.hash=params.toString();
  $("open-local").href=link.href;
}
function renderAskRefs() {
  const rows=rowsById();
  const ids=currentAskIds();
  $("ask-references").replaceChildren(...(ids.length?ids.map(id=>{
    const button=node("button","reference-chip",rows.get(id).chart[lang]+" ×");
    button.type="button";button.setAttribute("aria-label",text().removeRef+" · "+rows.get(id).chart[lang]);
    button.addEventListener("click",()=>{
      askRefs=currentAskIds().filter(key=>key!==id);
      $("ask-source").value="selected";
      renderAskRefs();
    });
    return button;
  }):[node("span","ask-hint",text().noReferences)]));
  updateLocalLink();
}
function updateRenderControls() {
  updateHostSettings();
  for(const button of document.querySelectorAll(".execute-render"))
    button.disabled=rendering||hostSaving||!hostAvailable||Boolean(button.dataset.started)||!button.dataset.hasTarget;
  $("render-again").disabled=rendering||hostSaving||!hostAvailable||!lastRenderJob;
}
function updateAgent() {
  $("ask-close").setAttribute("aria-label",text().askClose);
  $("manage-close").setAttribute("aria-label",text().manageClose);
  let connection=text()[checkingHost?"checking":"disconnected"];
  if(libraryConnected&&!checkingHost){
    const selected=hostStatus?.hosts?.find(host=>host.id===hostStatus.selected_host);
    const host=hostStatus?.host||selected?.label||hostStatus?.selected_host||"Agent";
    const viaApi=hostStatus?.selected_host==="api";
    connection=hostAvailable?text().connected+" "+host:host+" · "+text()[viaApi?"apiNeedsSetup":"noHost"];
    connection+=" · "+(hostStatus?.model||text()[viaApi?"apiModelMissing":"defaultModel"]);
  }
  $("agent-status").textContent=connection;
  updateHostSettings();
  $("agent-connect").hidden=hostAvailable;
  $("ask-send").disabled=!hostAvailable||asking||hostSaving;
  $("ask-send").textContent=text()[asking?"thinking":"sendQuestion"];
  renderAskRefs();
  updateRenderControls();
}
function openAsk(ids) {
  if(comparison.open)comparison.close();
  if(detail.open)detail.close();
  if(!localAtlas)return;
  askRefs=[...new Set(ids)];
  $("ask-source").value="selected";
  updateAgent();
  if(!ask.open)ask.showModal();
  updatePlayback();
}
$("ask-open").addEventListener("click",()=>openAsk([...selectedFigures.keys()]));
$("compare-ask").addEventListener("click",()=>openAsk([...selectedFigures.keys()]));
$("detail-ask").addEventListener("click",()=>openAsk([currentFigure.id]));
$("ask-close").addEventListener("click",()=>ask.close());
ask.addEventListener("close",()=>{ $("agent-api-key").value="";updatePlayback(); });
$("ask-source").addEventListener("change",renderAskRefs);
$("ask-question").addEventListener("input",updateLocalLink);
function consumeAskTransfer() {
  if(!localAtlas||!location.hash.includes("ask_"))return;
  const params=new URLSearchParams(location.hash.slice(1));
  const raw=params.get("ask_ids")||"";
  const question=params.get("ask_question")||"";
  if(raw.length>12000||question.length>4000)return;
  const rows=rowsById();
  const ids=raw.split(",").filter(id=>rows.has(id)).slice(0,100);
  $("ask-question").value=question;
  openAsk(ids);
  history.replaceState(null,"",location.pathname+location.search+"#catalog");
}
async function connectLibrary() {
  if(!localAtlas){updateAgent();return;}
  for(const id of ["ask-open","compare-ask","detail-ask","filter-stars"])$(id).hidden=false;
  $("agent-settings").hidden=false;
  try {
    const status=await api("status");
    libraryConnected=true;
    applyHostStatus(status);
    if(Array.isArray(status.stars))stars=new Set(status.stars);
    try {
      const state=await api("curation");
      if(!Array.isArray(state.hidden)||!state.edits||typeof state.edits!=="object")throw new Error("Invalid gallery state");
      applyCuration(state);$("manage-open").hidden=false;setLanguage();
    } catch { /* A plain static localhost preview can still show the atlas. */ }
  } catch {libraryConnected=false;hostAvailable=false;}
  checkingHost=false;
  updateAgent();updateStars();
}
function showProposedActions(result) {
  const rows=rowsById();
  const ids=(Array.isArray(result.ids)?result.ids:currentAskIds()).filter(id=>rows.has(id));
  const actions=Array.isArray(result.actions)?result.actions:[];
  $("ask-actions").replaceChildren(...actions.map(action=>{
    const block=node("div","proposal-action");
    if(action.kind==="revision") {
      const instruction=String(action.instruction||"").trim();
      if(!instruction)return block;
      const targetLabel=node("label","",text().targetLabel);
      const target=node("select");
      for(const id of ids)target.append(new Option(rows.get(id).chart[lang],id));
      if(ids.includes(action.id))target.value=action.id;
      targetLabel.append(target);
      const button=node("button","primary action execute-render",text().execute);
      button.type="button";
      if(ids.length)button.dataset.hasTarget="true";
      button.addEventListener("click",async()=>{
        const request={ids,instruction,target_id:target.value};
        if(!request.target_id){showGalleryError(text().missingTarget);return;}
        try {await beginRender(request,button);}
        catch(error){showGalleryError(error.message);}
      });
      block.append(node("p","",instruction),targetLabel,button);
    } else if(["star","unstar","add_reference","remove_reference"].includes(action.kind)&&ids.includes(action.id)) {
      const captions={star:"starAction",unstar:"unstarAction",add_reference:"saveReference",remove_reference:"removeReference"};
      const button=node("button","secondary action",text()[captions[action.kind]]+" · "+rows.get(action.id).chart[lang]);
      button.type="button";
      button.addEventListener("click",async()=>{
        button.disabled=true;
        try {
          if(action.kind==="star"||action.kind==="unstar")await setStar(action.id,action.kind==="star");
          else {
            const refs=new Set(currentAskIds());
            if(action.kind==="add_reference")refs.add(action.id);else refs.delete(action.id);
            askRefs=[...refs];$("ask-source").value="selected";renderAskRefs();
          }
          button.textContent=text().actionApplied;
        } catch(error){button.disabled=false;showGalleryError(error.message);}
      });
      block.append(button);
    }
    return block;
  }));
  updateRenderControls();
}
$("ask-form").addEventListener("submit",async event=>{
  event.preventDefault();
  if(!hostAvailable||asking||hostSaving)return;
  asking=true;updateAgent();showGalleryError();
  try {
    const result=await api("ask",{question:$("ask-question").value,ids:currentAskIds()});
    $("ask-answer").textContent=result.answer;
    showProposedActions(result);
    $("ask-result").hidden=false;
  } catch(error){showGalleryError(error.message);}
  finally {asking=false;updateAgent();}
});
function persistRender() {
  try {sessionStorage.setItem(renderSessionKey,JSON.stringify({request:renderRequest,current:renderPoll,last:lastRenderJob}));} catch {}
}
function artifactUrl(value,jobId) {
  const url=new URL(value,location.href);
  if(url.origin!==location.origin||!url.pathname.startsWith("/BioFigure/api/render/"+jobId+"/files/"))
    throw new Error(text().connectionError);
  return url.href;
}
function displayRender(job) {
  const preview=artifactUrl(job.preview,job.id);
  const image=$("render-preview");
  image.src=preview;image.alt=rowsById().get(renderRequest?.target_id)?.chart[lang]||text().rendered;
  const links=(Array.isArray(job.files)?job.files:[]).map(file=>{
    const link=node("a","secondary action",file.name);
    link.href=artifactUrl(file.url,job.id);link.download=file.name;
    return link;
  });
  $("render-files").replaceChildren(...links);
  $("render-output").hidden=false;
  $("render-instruction").value="";
}
async function beginRender(request,button) {
  if(rendering||hostSaving)return;
  rendering=true;renderRequest=request;
  updateHostSettings();
  $("render-panel").hidden=false;
  $("render-status").textContent=text().renderQueued;
  $("render-error").hidden=true;
  updateRenderControls();showGalleryError();
  try {
    const job=await api("render",request);
    if(!/^[a-z0-9-]{16,64}$/i.test(job.id||""))throw new Error(text().connectionError);
    renderPoll=job.id;
    if(button)button.dataset.started=job.id;
    persistRender();
    pollRender(job.id);
  } catch(error) {
    rendering=false;updateRenderControls();
    $("render-status").textContent=text().renderFailed;
    throw error;
  }
}
async function pollRender(id) {
  if(renderPoll!==id)return;
  try {
    const job=await api("render/"+encodeURIComponent(id));
    $("render-status").textContent=text()[job.status==="completed"?"rendered":job.status==="needs_input"?"needsInput":job.status==="failed"?"renderFailed":job.status==="queued"?"renderQueued":"rendering"];
    if(job.status==="completed") {
      displayRender(job);
      lastRenderJob={...job,request:renderRequest};
      renderPoll=0;rendering=false;persistRender();updateRenderControls();
    } else if(job.status==="failed"||job.status==="needs_input") {
      $("render-error").textContent=job.message||job.error||text()[job.status==="needs_input"?"needsInput":"renderFailed"];
      $("render-error").hidden=false;
      for(const button of document.querySelectorAll(".execute-render"))if(button.dataset.started===id)delete button.dataset.started;
      renderPoll=0;rendering=false;persistRender();updateRenderControls();
    } else setTimeout(()=>pollRender(id),1500);
  } catch(error) {
    $("render-error").textContent=error.message;
    $("render-error").hidden=false;
    // Keep the persisted job ID so reload can resume after a connection returns.
    rendering=false;updateRenderControls();
  }
}
$("render-followup").addEventListener("submit",async event=>{
  event.preventDefault();
  if(!lastRenderJob||rendering)return;
  const request={...lastRenderJob.request,instruction:$("render-instruction").value,previous_job:lastRenderJob.id};
  try {await beginRender(request);}
  catch(error){showGalleryError(error.message);}
});
function resumeRender() {
  if(!localAtlas)return;
  try {
    const session=JSON.parse(sessionStorage.getItem(renderSessionKey)||"null");
    if(!session||!session.request||!Array.isArray(session.request.ids))return;
    renderRequest=session.request;
    if(session.last?.status==="completed") {
      lastRenderJob=session.last;
      displayRender(lastRenderJob);
      $("render-panel").hidden=false;
      $("render-status").textContent=text().rendered;
    }
    if(typeof session.current==="string"&&/^[a-z0-9-]{16,64}$/i.test(session.current)) {
      renderPoll=session.current;rendering=true;
      $("render-panel").hidden=false;pollRender(renderPoll);
    }
  } catch { /* Invalid browser state is ignored. */ }
  updateRenderControls();
}


function showError(target,message="") {
  target.textContent=message;target.hidden=!message;
}
function applyCuration(state) {
  hiddenFigures=new Set(state.hidden.filter(id=>atlas.figures.some(row=>row.id===id)));
  figureEdits=state.edits;
  figureById=new Map(atlas.figures.map(row=>{
    const edits=figureEdits[row.id];
    return [row.id,edits?{...row,...edits,title:edits.chart}:row];
  }));
  const priorId=featured[current]?.id;
  const pick=(key,fallback,count)=>{
    const preference=window.biofigureShowcase?.[key];
    const ids=Array.isArray(preference)?[...preference,...fallback]:fallback;
    return [...new Set(ids)].filter(id=>figureById.has(id)&&!hiddenFigures.has(id)).slice(0,count).map(id=>figureById.get(id));
  };
  featured=pick("featured",[...atlas.featured,...atlas.figures.filter(row=>row.thumbnail).map(row=>row.id)],5);
  current=Math.max(0,featured.findIndex(row=>row.id===priorId));
  plates=atlas.editorial.filter(id=>!hiddenFigures.has(id)&&figureById.has(id)).map(id=>figureById.get(id));
  skyRows=pick("sky",[...atlas.editorial,...atlas.featured],6);
  updateSkyCuration();
  for(const id of selectedFigures.keys()){
    if(hiddenFigures.has(id))selectedFigures.delete(id);
    else selectedFigures.set(id,figureById.get(id));
  }
  if(currentFigure&&figureById.has(currentFigure.id))currentFigure=figureById.get(currentFigure.id);
}

function refreshManageSelection() {
  const removed=$("manage-filter").value==="removed";
  const apply=$("manage-apply");
  apply.disabled=managing||!manageSelected.size;
  apply.classList.toggle("remove-cards",!removed);
  apply.textContent=removed?text().manageRestore:text().manageRemove;
  $("manage-count").textContent=text().manageSelected(manageSelected.size);
}
function renderManager() {
  const removed=$("manage-filter").value==="removed";
  const query=$("manage-search").value.trim().toLowerCase();
  const list=$("manage-list");
  const scroll=list.scrollTop;
  const rows=[...figureById.values()].filter(row=>hiddenFigures.has(row.id)===removed &&
    [row.id,row.chart.en,row.chart.zh,row.title.en,row.title.zh].some(value=>value.toLowerCase().includes(query)));
  $("manage-empty").hidden=rows.length>0;
  list.replaceChildren(...rows.map(row=>{
    const item=node("li","manage-row");
    const label=node("label");
    const check=node("input");
    check.type="checkbox";
    check.dataset.manageId=row.id;
    check.checked=manageSelected.has(row.id);
    check.addEventListener("change",()=>{
      if(check.checked)manageSelected.add(row.id);
      else manageSelected.delete(row.id);
      refreshManageSelection();
    });
    const preview=node("button","manage-preview");
    preview.type="button";
    preview.setAttribute("aria-label",text().managePreview+" · "+row.chart[lang]);
    preview.addEventListener("click",()=>openDetail(row,rows));
    const thumb=node("img");
    if(row.thumbnail)thumb.src=row.thumbnail;
    thumb.alt="";
    thumb.loading="lazy";
    thumb.decoding="async";
    const caption=node("span","manage-preview-label");
    caption.append(icon("open"),node("span","",text().managePreview));
    preview.append(thumb,caption);
    label.append(check,node("span","",row.chart[lang]));
    const edit=node("button","secondary",text().manageEdit);
    edit.type="button";
    edit.setAttribute("aria-label",text().manageEdit+" · "+row.chart[lang]);
    edit.addEventListener("click",()=>openEditor(row));
    const actions=node("div","manage-card-actions");
    actions.append(label,edit);
    item.append(preview,actions);
    return item;
  }));
  list.scrollTop=scroll;
  refreshManageSelection();
}
function editMode(enabled) {
  $("manage-picker").hidden=enabled;
  $("manage-editor").hidden=!enabled;
}
function openEditor(row) {
  managedId=row.id;
  editMode(true);
  $("manage-edit-title").textContent=row.chart[lang];
  $("manage-reset").hidden=!figureEdits[row.id];
  for(const field of ["chart","intro"])
    for(const locale of ["en","zh"])$("manage-"+field+"-"+locale).value=row[field][locale];
  showError($("manage-status"));
  showError($("manage-error"));
  $("manage-chart-"+lang).focus();
}
function returnToManager() {
  editMode(false);
  renderManager();
  if(manager.open)$("manage-search").focus({preventScroll:true});
}
async function saveCuration(operation, message, done) {
  if(managing||!localAtlas)return;
  managing=true;
  refreshManageSelection();
  $("manage-save").disabled=$("manage-reset").disabled=true;
  showError($("manage-error"));
  showError($("manage-status"));
  try {
    const state=await api("curation",operation);
    applyCuration(state);
    setLanguage();
    done();
    showError($("manage-status"),message);
  } catch(error) {
    showError($("manage-error"),error.message);
  } finally {
    managing=false;
    $("manage-save").disabled=$("manage-reset").disabled=false;
    refreshManageSelection();
  }
}
$("manage-open").addEventListener("click",()=>{
  if(!localAtlas||!libraryConnected)return;
  manageSelected.clear();
  $("manage-search").value="";
  $("manage-filter").value="visible";
  showError($("manage-error"));
  showError($("manage-status"));
  editMode(false);
  renderManager();
  manager.showModal();
  updatePlayback();
});
$("manage-close").addEventListener("click",()=>manager.close());
manager.addEventListener("close",()=>{
  $("manage-open").focus({preventScroll:true});
  updatePlayback();
});
$("manage-search").addEventListener("input",renderManager);
$("manage-filter").addEventListener("change",()=>{
  manageSelected.clear();
  renderManager();
});
$("manage-apply").addEventListener("click",()=>{
  const remove=$("manage-filter").value!=="removed";
  const ids=[...manageSelected];
  if(!ids.length)return;
  saveCuration({action:remove?"hide":"restore",ids},
    (remove?text().manageHidden:text().manageRestored)(ids.length),()=>{
      manageSelected.clear();
      renderManager();
      if(manager.open)$("manage-search").focus({preventScroll:true});
    });
});
$("manage-back").addEventListener("click",returnToManager);
$("manage-reset").addEventListener("click",()=>{
  saveCuration({action:"reset",ids:[managedId]},text().manageResetDone,returnToManager);
});
$("manage-editor").addEventListener("submit",event=>{
  event.preventDefault();
  const fields={};
  for(const field of ["chart","intro"]) {
    fields[field]={en:$("manage-"+field+"-en").value,zh:$("manage-"+field+"-zh").value};
  }
  saveCuration({action:"edit",ids:[managedId],fields},text().manageSaved,returnToManager);
});


function updateSkyCuration() {
  for(const button of document.querySelectorAll("#sky-models .sky-model")) {
    const row=figureById.get(button.dataset.figureId);
    button.hidden=!row||hiddenFigures.has(row.id);
    if(row){
      button.setAttribute("aria-label",text().open+" · "+row.chart[lang]);
      const caption=button.querySelector(".sky-model-name");
      if(caption)caption.textContent=row.chart[lang];
    }
  }
}


function applyHostStatus(status) {
  const hosts=Array.isArray(status.hosts)?status.hosts:[];
  const fallback=hosts.find(host=>host.label===status.host)?.id||hostStatus?.selected_host||"";
  hostStatus={host:status.host||null,selected_host:status.selected_host||fallback,
    model:typeof status.model==="string"?status.model:null,hosts,
    api:status.api&&typeof status.api==="object"?{
      protocol:typeof status.api.protocol==="string"?status.api.protocol:"openai",
      base_url:typeof status.api.base_url==="string"?status.api.base_url:"",
      model:typeof status.api.model==="string"?status.api.model:"",
      key_set:status.api.key_set===true
    }:null};
  hostAvailable=typeof status.available==="boolean"?status.available:Boolean(status.host);
  renderHostForm();
}
function renderHostForm() {
  const select=$("agent-host");
  const selected=hostStatus?.selected_host||"";
  select.replaceChildren(...(hostStatus?.hosts||[]).map(host=>new Option(
    host.label+(host.installed?"":" · "+text().hostNotInstalled),host.id,false,host.id===selected)));
  if(selected)select.value=selected;
  $("agent-model").value=hostStatus?.model||"";
  $("agent-api-protocol").value=hostStatus?.api?.protocol||"openai";
  $("agent-api-url").value=hostStatus?.api?.base_url||"";
  $("agent-api-key").value="";
  $("agent-api-clear").checked=false;
  updateHostSettings();
}
function updateHostSettings() {
  const viaApi=$("agent-host").value==="api";
  $("agent-model").placeholder=text()[viaApi?"apiModelPlaceholder":"modelPlaceholder"];
  $("agent-model").required=viaApi;
  $("agent-model-label").textContent=text()[viaApi?"apiModelLabel":"agentModel"];
  $("agent-api-settings").hidden=!viaApi;
  for(const option of $("agent-host").options){
    const host=hostStatus?.hosts?.find(item=>item.id===option.value);
    if(host)option.textContent=host.label+(host.installed?"":" · "+text().hostNotInstalled);
  }
  const busy=asking||rendering||Boolean(renderPoll)||hostSaving;
  $("agent-host").disabled=$("agent-model").disabled=busy||!libraryConnected;
  $("agent-save").disabled=busy||!libraryConnected||!hostStatus?.hosts?.length;
  $("agent-save").textContent=text()[hostSaving?"savingAgent":"saveAgent"];
  const selected=hostStatus?.hosts?.find(host=>host.id===$("agent-host").value);
  $("agent-host-hint").textContent=busy?text().hostBusy:viaApi?text().apiReadyHint:selected?.installed?text().hostInstalled:text().installHost;
  for(const id of ["agent-api-protocol","agent-api-url","agent-api-clear"])$(id).disabled=busy||!libraryConnected||!viaApi;
  $("agent-api-key").disabled=busy||!libraryConnected||!viaApi||$("agent-api-clear").checked;
  $("agent-api-url").required=viaApi;
  const saved=hostStatus?.api;
  const sameConnection=saved&&saved.protocol===$("agent-api-protocol").value&&saved.base_url.replace(/\/+$/,"")===$("agent-api-url").value.trim().replace(/\/+$/,"");
  const kept=Boolean(sameConnection&&saved.key_set);
  $("agent-api-key").placeholder=text()[kept?"apiKeyKeep":"apiKeyPlaceholder"];
  $("agent-api-key-status").textContent=text()[!sameConnection&&saved?.key_set?"apiKeyChanged":kept?"apiKeySaved":"apiKeyMissing"];
}
function settingsChanged() {
  $("agent-settings-status").hidden=true;
  $("agent-settings-error").hidden=true;
  updateHostSettings();
}
$("agent-host").addEventListener("change",()=>{
  if($("agent-host").value==="api")$("agent-model").value=hostStatus?.api?.model||"";
  else $("agent-model").value=$("agent-host").value===hostStatus?.selected_host?(hostStatus?.model||""):"";
  $("agent-api-key").value="";
  $("agent-api-clear").checked=false;
  settingsChanged();
});
$("agent-api-protocol").addEventListener("change",()=>{
  const defaults={openai:"https://api.openai.com/v1",anthropic:"https://api.anthropic.com/v1",gemini:"https://generativelanguage.googleapis.com/v1beta"};
  const address=$("agent-api-url").value.trim().replace(/\/+$/,"");
  if(!address||Object.values(defaults).includes(address))$("agent-api-url").value=defaults[$("agent-api-protocol").value];
  $("agent-api-key").value="";settingsChanged();
});
$("agent-api-url").addEventListener("input",settingsChanged);
$("agent-api-key").addEventListener("input",settingsChanged);
$("agent-api-clear").addEventListener("change",()=>{
  if($("agent-api-clear").checked)$("agent-api-key").value="";
  settingsChanged();
});
$("agent-model").addEventListener("input",settingsChanged);
$("agent-settings-form").addEventListener("submit",async event=>{
  event.preventDefault();
  if(!localAtlas||!libraryConnected||asking||rendering||renderPoll||hostSaving)return;
  const host=$("agent-host").value;
  if(!hostStatus?.hosts?.some(item=>item.id===host))return;
  const model=$("agent-model").value.trim();
  const body={host,model:model||null};
  if(host==="api"){
    body.protocol=$("agent-api-protocol").value;
    body.base_url=$("agent-api-url").value.trim();
    body.clear_key=$("agent-api-clear").checked;
    const key=$("agent-api-key").value.trim();
    if(key&&!body.clear_key)body.api_key=key;
  }
  hostSaving=true;showError($("agent-settings-error"));showError($("agent-settings-status"));updateAgent();
  try {
    const status=await api("host",body);
    applyHostStatus(status);
    showError($("agent-settings-status"),text().savedAgent);
  } catch(error) {
    renderHostForm();
    showError($("agent-settings-error"),error.message);
  } finally {
    $("agent-api-key").value="";
    hostSaving=false;updateAgent();
  }
});
