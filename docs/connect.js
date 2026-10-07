const $ = (id) => document.getElementById(id);
const screens = ["signon", "dial", "online", "bye"];
let cancelled = false;
let audio;

const channels = {
  channels: ["Channels", "Fourteen doors, one phone line. Pick a keyword. Or don't. The line is metered in spirit only."],
  mail: ["You Have Mail", "Three messages. One is news. One is CoolDude95 asking if you are on. One is a bill for $0.00, which is the funniest number in telecom."],
  people: ["People Connection", "The lobby is full of people who are about to go to dinner. SoccerMom22 has been about to go to dinner since 1998."],
  news: ["Today's News", "The Senate is still talking. The hurricane is still considering it. The Dow is a fraction, because decimals had not yet won."],
  sports: ["Sports", "Someone won Game 2. Do not spoil it for the West Coast feed. The modem is already slow enough."],
  busy: ["Busy", "You have connected to the feeling of not connecting. This is the premium tier."]
};

function show(id) {
  screens.forEach((s) => $(s).classList.toggle("hidden", s !== id));
}
function toast(t) {
  const el = $("toast");
  el.textContent = t;
  el.classList.remove("hidden");
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.add("hidden"), 2400);
}
function tick() {
  const d = new Date();
  let h = d.getHours();
  const ap = h >= 12 ? "PM" : "AM";
  h = h % 12 || 12;
  $("clock").textContent = h + ":" + String(d.getMinutes()).padStart(2, "0") + " " + ap;
}
setInterval(tick, 10000); tick();

function beep(freq, dur, type, gain) {
  if (!$("speaker").checked) return;
  try {
    audio = audio || new (window.AudioContext || window.webkitAudioContext)();
    const o = audio.createOscillator();
    const g = audio.createGain();
    o.type = type || "sine";
    o.frequency.value = freq;
    g.gain.value = gain || 0.04;
    o.connect(g); g.connect(audio.destination);
    o.start();
    o.stop(audio.currentTime + dur);
  } catch (e) {}
}

function wait(ms) { return new Promise((r) => setTimeout(r, ms)); }

function validName(s) {
  return s.length >= 3 && s.length <= 16 && !/\s/.test(s);
}

async function connect() {
  const name = $("name").value.trim();
  if (!validName(name)) {
    toast("Screen names are 3 to 16 characters, no spaces. Spaces are a crime.");
    return;
  }
  cancelled = false;
  show("dial");
  const loc = $("loc").value;
  const steps = [
    ["Initializing metaphor...", "The sewing notion checks that it is still a thimble."],
    ["Dialing the " + loc + " line...", "555 numbers only. Your real phone is safe."],
    ["Ringing...", loc === "busy" ? "Someone is on the line. It might be you." : "One ring. Two. The modem clears its throat."],
    ["Connecting at 28800 bps of nostalgia...", "V.34, but make it a bit."],
    ["Requesting network attention...", "The network is a div and it is listening."],
    ["Checking password...", "Checked locally. Forgotten immediately. hunter2 remains a lifestyle."]
  ];
  beep(350, 0.2); beep(440, 0.25);
  for (let i = 0; i < steps.length; i++) {
    if (cancelled) return;
    $("status").textContent = steps[i][0];
    $("steps").textContent = steps[i][1];
    ["p1", "p2", "p3"].forEach((p, n) => $(p).classList.toggle("on", n === Math.min(2, Math.floor(i / 2))));
    beep(700 + i * 60, 0.08, "square", 0.03);
    await wait(loc === "busy" && i === 2 ? 1200 : 800);
    if (loc === "busy" && i === 2) {
      beep(480, 0.18); beep(620, 0.18);
      $("status").textContent = "Busy.";
      $("steps").textContent = "The access number is busy. This is the joke, and also the lesson.";
      await wait(700);
      if (!cancelled) { toast("Unable to connect. Try Home. Or enjoy the busy signal. Both are valid."); show("signon"); }
      return;
    }
  }
  if (cancelled) return;
  online(name);
}

function online(name) {
  show("online");
  $("who").textContent = name;
  $("hello").textContent = "Welcome, " + name;
  $("blurb").textContent = "You are connected. To this page. The phone line is free. You've got mail, in the theatrical sense.";
  render("mail");
  beep(523, 0.1); beep(659, 0.16);
  toast("You've got mail.");
}

function render(key) {
  const item = channels[key] || channels.channels;
  $("stories").innerHTML = "";
  Object.keys(channels).forEach((k) => {
    const d = document.createElement("div");
    d.className = "story";
    d.innerHTML = "<b>" + channels[k][0] + "</b><div>" + channels[k][1] + "</div>";
    d.onclick = () => { $("hello").textContent = channels[k][0]; $("blurb").textContent = channels[k][1]; };
    $("stories").appendChild(d);
  });
  $("hello").textContent = item[0];
  $("blurb").textContent = item[1];
}

$("connect").onclick = connect;
$("pass").addEventListener("keydown", (e) => { if (e.key === "Enter") connect(); });
$("cancel").onclick = () => { cancelled = true; show("signon"); toast("Call cancelled. The thimble hangs up."); };
$("setup").onclick = () => toast("Expert setup: no COM port, no init string, no CD in the mail.");
$("signoff").onclick = () => {
  show("bye");
  beep(400, 0.15, "sawtooth", 0.04);
  setTimeout(() => show("signon"), 1600);
};
document.body.addEventListener("click", (e) => {
  const ch = e.target.getAttribute && e.target.getAttribute("data-ch");
  if (ch) render(ch);
});
$("kwform").onsubmit = (e) => {
  e.preventDefault();
  const k = $("keyword").value.trim().toLowerCase();
  if (channels[k] || k === "chat") render(k === "chat" ? "people" : k);
  else toast("No keyword \"" + k + "\". Try mail, chat, news, busy.");
};
