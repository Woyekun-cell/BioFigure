"use strict";
window.createAtlasSky = function ({rows, open, overlayOpen, reduced}) {
  const sky = document.getElementById("sky");
  const canvas = document.getElementById("sky-canvas");
  const context = canvas.getContext("2d");
  const wordmark = document.getElementById("sky-title");
  let wordPulse;
  const tools = document.getElementById("sky-tools");
  const container = document.getElementById("sky-models");
  const pulseButton = document.getElementById("sky-pulse");
  const pauseButton = document.getElementById("sky-pause");
  const finePointer = matchMedia("(hover: hover) and (pointer: fine)");
  const pointer = {x: 0, y: 0, active: false};
  // Large and small arrangements keep the wordmark and reading controls clear.
  const layout = [
    [13, 31, 161, 17, 20, 83, 10, -19, -15],
    [32, 16, 110, 48, 13, 66, -15, 13, 10],
    [80, 20, 148, 80, 21, 89, 13, -21, 11],
    [87, 61, 168, 81, 75, 88, -16, -18, 14],
    [21, 74, 146, 17, 76, 84, -12, 13, -10],
    [68, 80, 116, 51, 83, 64, -16, 14, -11],
  ];
  const models = rows.map((row, index) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = "sky-model";
    const values = layout[index];
    const properties = ["model-x", "model-y", "model-size", "small-x", "small-y", "small-size", "rest-x", "rest-y", "rest-z"];
    properties.forEach((property, i) => element.style.setProperty(
      "--" + property, values[i] + (i >= 6 ? "deg" : i % 3 === 2 ? "px" : "%")
    ));
    const float = document.createElement("span");
    float.className = "sky-model-float";
    const face = document.createElement("span");
    face.className = "sky-model-face";
    const image = new Image();
    image.src = row.thumbnail;
    image.alt = "";
    image.decoding = "async";
    const name = document.createElement("span");
    name.className = "sky-model-name";
    name.setAttribute("aria-hidden", "true");
    face.append(image);
    float.append(face);
    element.append(float, name);
    element.addEventListener("click", () => open(row));
    container.append(element);
    return {row, element, float, face, name, lift: 0, depth: 0, offset: 0, velocity: 0, tiltX: values[6], tiltY: values[7]};
  });
  container.hidden = false;

  let language, copy;
  let width = 0, height = 0, stars = [], bounds, wave, elapsed = 0, lastTime = 0, frameId = 0;
  let userPaused = false, inView = false, scrollDirty = true, scrollShift = 0;

  function syncControls() {
    tools.hidden = reduced.matches;
    pauseButton.textContent = userPaused ? copy.skyResume : copy.skyPause;
    pulseButton.disabled = userPaused;
    sky.classList.toggle("sky-still", userPaused || reduced.matches);
  }

  function translate(lang, strings) {
    language = lang;
    copy = strings;
    for (const model of models) {
      model.name.textContent = model.row.chart[language];
      model.element.setAttribute("aria-label", copy.open + ": " + model.row.chart[language]);
    }
    container.setAttribute("role", "group");
    container.setAttribute("aria-label", copy.skyFigures);
    syncControls();
  }

  function measure() {
    bounds = sky.getBoundingClientRect();
    width = bounds.width;
    height = bounds.height;
    if (context) {
      const scale = Math.min(devicePixelRatio || 1, 1.7);
      canvas.width = Math.round(width * scale);
      canvas.height = Math.round(height * scale);
      context.setTransform(scale,0,0,scale,0,0);
      let seed = 712;
      const random = () => {
        seed = (seed * 1664525 + 1013904223) >>> 0;
        return seed / 4294967296;
      };
      stars = Array.from({length: width < 780 ? 105 : 205}, (_, index) => ({
        x: random() * width, y: random() * height,
        radius: index % 28 === 0 ? 2.4 : .45 + random() * 1.2,
        phase: random() * Math.PI * 2, alpha: .2 + random() * .54,
        tint: index % 5 === 0 ? "#e8dcff" : "#b3d9ff",
      }));
    }
    drawStars();
    syncGeometry();
  }

  function drawStars() {
    if (!context) return;
    context.clearRect(0,0,width,height);
    for (const star of stars) {
      const seconds = elapsed / 1000;
      let x = star.x + Math.sin(seconds * .42 + star.phase) * 4;
      let y = star.y + Math.cos(seconds * .35 + star.phase) * 5;
      if (pointer.active) {
        const dx = x - pointer.x, dy = y - pointer.y;
        const distance = Math.hypot(dx,dy);
        if (distance > .3 && distance < 128) {
          const step = 28 * (1 - distance / 128);
          x += dx / distance * step;
          y += dy / distance * step;
        }
      }
      if (wave) {
        const dx = x - wave.x, dy = y - wave.y;
        const distance = Math.hypot(dx,dy);
        const rim = Math.max(0, 1 - Math.abs(distance - wave.radius) / 88);
        if (distance > .3) {
          x += dx / distance * rim * 27;
          y += dy / distance * rim * 27;
        }
      }
      context.globalAlpha = star.alpha * (.83 + Math.sin(seconds * 1.32 + star.phase) * .16);
      context.fillStyle = star.tint;
      context.beginPath();
      context.arc(x,y,star.radius,0,Math.PI*2);
      context.fill();
      if (star.radius > 2) {
        context.globalAlpha *= .55;
        context.fillRect(x - 6,y - .5,12,1);
        context.fillRect(x - .5,y - 6,1,12);
      }
    }
    if (wave) {
      for (const ring of [wave.radius, Math.max(0,wave.radius - 22)]) {
        context.strokeStyle = "#afd7ff";
        context.lineWidth = 1.25;
        context.globalAlpha = Math.max(0, .62 * (1 - wave.radius / 440));
        context.beginPath();
        context.arc(wave.x,wave.y,ring,0,Math.PI*2);
        context.stroke();
      }
    }
    const flight = (elapsed % 8800) / 890;
    if (flight > 0 && flight < 1) {
      const x = width * (.86 - flight * .54);
      const y = height * (.08 + flight * .34);
      const tail = context.createLinearGradient(x,y,x + 98,y - 39);
      tail.addColorStop(0,"#d0e8ff");
      tail.addColorStop(1,"#87aafa00");
      context.globalAlpha = Math.sin(flight * Math.PI) * .85;
      context.strokeStyle = tail;
      context.lineWidth = 1.2;
      context.beginPath();
      context.moveTo(x,y);
      context.lineTo(x+98,y-39);
      context.stroke();
    }
    context.globalAlpha = 1;
  }

  function syncGeometry() {
    bounds = sky.getBoundingClientRect();
    for (const model of models) {
      model.centerX = model.element.offsetLeft;
      model.centerY = model.element.offsetTop;
    }
  }

  function drawModels(dt) {
    models.forEach((model,index) => {
      const phase = index * 1.61 + elapsed / 1650;
      const hovered = model.element.matches(":hover,:focus-visible") && (finePointer.matches || model.element.matches(":focus-visible"));
      const influence = Math.min(1, dt * .14);
      model.lift += ((hovered ? -22 : 0) - model.lift) * influence;
      model.depth += ((hovered ? .14 : 0) - model.depth) * influence;
      model.velocity = (model.velocity - model.offset * .052 * dt) * Math.pow(.88,dt);
      model.offset = Math.max(-62,Math.min(40,model.offset + model.velocity * dt));
      const orbit = width < 780 ? 10 : 22;
      const offsetX = (hovered ? 0 : Math.cos(phase) * orbit) + (pointer.active ? (pointer.x - width/2) * .014 : 0);
      const offsetY = Math.sin(phase) * orbit * .63 + model.lift + model.offset - scrollShift * (index % 2 ? 29 : 62);
      const overWithPointer = hovered && pointer.active;
      const tiltX = model.tiltX + Math.cos(phase) * 13 + (overWithPointer ? (pointer.y - model.centerY) * -.16 : 0);
      const tiltY = model.tiltY + Math.sin(phase) * 22 + (overWithPointer ? (pointer.x - model.centerX) * .16 : 0);
      model.float.style.transform = `translate3d(${offsetX}px,${offsetY}px,0) scale(${1 + model.depth})`;
      model.face.style.transform = `rotateX(${tiltX}deg) rotateY(${tiltY}deg) rotateZ(${Math.sin(phase) * 7}deg)`;
    });
  }

  function reset() {
    wordPulse?.cancel();
    wave = undefined;
    scrollShift = 0;
    pointer.active = false;
    for (const model of models) {
      Object.assign(model,{lift:0,depth:0,offset:0,velocity:0});
      model.face.style.removeProperty("transform");
      model.float.style.removeProperty("transform");
    }
    drawStars();
  }

  function canRun() {
    return inView && !userPaused && !reduced.matches && !document.hidden && !overlayOpen();
  }

  function frame(time) {
    frameId = 0;
    if (!canRun()) { lastTime = 0; return; }
    const step = lastTime ? Math.min(27,time - lastTime) : 16.7;
    lastTime = time;
    elapsed += step;
    if (scrollDirty) {
      scrollShift = Math.max(0,Math.min(1,(scrollY - sky.offsetTop) / height));
      syncGeometry();
      scrollDirty = false;
    }
    if (wave) {
      wave.radius += 6.7 * step / 16.7;
      if (wave.radius > 440) wave = undefined;
    }
    drawStars();
    drawModels(step / 16.7);
    frameId = requestAnimationFrame(frame);
  }

  function wake() {
    if (!frameId && canRun()) frameId = requestAnimationFrame(frame);
  }

  function burst(x,y) {
    if (!canRun()) return;
    wave = {x,y,radius:8};
    wordPulse?.cancel();
    wordPulse = wordmark.animate([
      {transform:"none",offset:0,easing:"cubic-bezier(.16,1,.3,1)"},
      {transform:"translateY(-13px)",offset:.34,easing:"cubic-bezier(.16,1,.3,1)"},
      {transform:"translateY(2px)",offset:.68,easing:"cubic-bezier(.16,1,.3,1)"},
      {transform:"none",offset:1},
    ],{duration:560});
    for (const model of models) {
      const distance = Math.hypot(model.centerX - x, model.centerY - y);
      model.velocity = -7 - Math.max(0,10 - distance * .021);
    }
  }

  sky.addEventListener("pointermove",event => {
    if (!canRun() || !finePointer.matches || event.pointerType === "touch") return;
    pointer.x = event.clientX - bounds.left;
    pointer.y = event.clientY - bounds.top;
    pointer.active = true;
  },{passive:true});
  sky.addEventListener("pointerleave",() => { pointer.active = false; });
  sky.addEventListener("pointerdown",event => {
    if (event.button !== 0 || event.target.closest("button,a")) return;
    burst(event.clientX - bounds.left,event.clientY - bounds.top);
  },{passive:true});
  pulseButton.addEventListener("click",() => burst(width/2,height *.48));
  pauseButton.addEventListener("click",() => {
    userPaused = !userPaused;
    reset();
    syncControls();
    wake();
  });
  addEventListener("scroll",() => {
    scrollDirty = true;
  },{passive:true});
  document.addEventListener("visibilitychange",wake);
  for (const dialog of document.querySelectorAll("dialog")) dialog.addEventListener("close",wake);
  reduced.addEventListener("change",() => {
    reset();
    syncControls();
    wake();
  });
  new ResizeObserver(measure).observe(sky);
  new IntersectionObserver(([entry]) => {
    inView = entry.isIntersecting;
    wake();
  }).observe(sky);
  document.fonts.ready.then(measure);
  measure();
  return {translate};
};
