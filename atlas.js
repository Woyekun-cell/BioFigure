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
    count:n=>n+" 张图", types:n=>n+" 种图型", zoom:"原始尺寸"
  }
};
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
const comparison=$("comparison");
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
  $("detail-prev").setAttribute("aria-label",text().prev);
  $("detail-next").setAttribute("aria-label",text().next);
  sky?.translate(lang,text());
  if(!atlas)return;
  $("figure-total").textContent=text().count(atlas.figures.length);
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
  categoryNav();render();showGuide(guideStep,false);
  if(detail.open)fillDetail(currentFigure);
}
function show(index,direction) {
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
  if(play && onScreen && !document.hidden && !detail.open && !comparison.open && !focused && !hovered) {
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
    button.disabled=!selected&&count===2;
  }
}
function card(row, source) {
  const button=node("button","card action");button.type="button";
  const image=node("img");image.src=row.thumbnail;image.alt="";image.loading="lazy";image.decoding="async";
  const media=node("span","card-media");media.append(image);
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
    else if(selectedFigures.size<2)selectedFigures.set(row.id,row);
    updateComparison();
  });
  entry.append(button,compare);
  return entry;
}
function render({append=false,motion=false}={}) {
  const words=search.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
  const fileFilter=$("resource-filter").value;
  const rows=filteredRows=atlas.figures.filter(row=>{
    if(category!=="all"&&!row.categories.includes(category))return false;
    if((fileFilter==="code"||fileFilter==="both")&&!row.resources.code.length)return false;
    if((fileFilter==="data"||fileFilter==="both")&&!row.resources.data.length)return false;
    if(!words.length)return true;
    const terms=[row.title.en,row.title.zh,row.chart.en,row.chart.zh,...row.packages,
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
function fillDetail(row) {
  const currentImage=$("detail-image");
  if(currentImage?.dataset.figure===row.id) {
    currentImage.alt=row.chart[lang];
  } else {
    const preview=node("img");
    preview.id="detail-image";preview.dataset.figure=row.id;
    preview.alt=row.chart[lang];preview.src=row.thumbnail;
    const figure=$("detail-figure");
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
  const download=$("download");download.href=row.image;download.download=row.id+".webp";
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
    $("detail-image").animate([{opacity:.4,transform:"translateY(8px)"},{opacity:1,transform:"none"}],
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
  for(const dialog of [detail,comparison]){
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
  const byId=new Map(atlas.figures.map(row=>[row.id,row]));
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
  const skyRows=curatedRows("sky",6,[...atlas.editorial,...atlas.featured.slice(0,3)]);
  sky=window.createAtlasSky({
    rows:skyRows,
    open: row=>openDetail(row,skyRows),
    overlayOpen: ()=>detail.open||comparison.open,
    reduced:reduce,
  });
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
