"""Builds tools/preview/plan.html.

A proposal, not shipped code: one extra onboarding question and what it would
actually change. Interactive, so the claim that it is dynamic can be checked
rather than taken on trust.
"""
import json
import pathlib

fonts = pathlib.Path("tools/preview/_fonts.css").read_text(encoding="utf-8")

# Each trigger carries everything downstream of it. Nothing here is
# decorative: every field is consumed by something the user sees.
TRIGGERS = [
    dict(
        id="waking", label="First thing", sub="Before anything else",
        cig="With the first coffee", vape="Before I've done anything",
        hours=[7.0], days="every day", risk="high",
        why="The steepest overnight withdrawal. Nicotine has a two hour half life, so waking is the emptiest anyone gets.",
        craving="This is the morning one. It is the strongest and the shortest.",
        swaps=["Shower first", "Coffee outside", "Ten minutes of something else"],
    ),
    dict(
        id="coffee", label="With coffee", sub="The pairing",
        cig="With coffee", vape="With coffee",
        hours=[8.0, 14.0], days="every day", risk="high",
        why="A learned pairing rather than a chemical one, which is why it survives long after the nicotine is gone.",
        craving="Coffee is the cue, not the craving. It passes and the coffee stays.",
        swaps=["Drink it somewhere else", "Switch to tea for a fortnight", "Hold the cup with the other hand"],
    ),
    dict(
        id="meals", label="After eating", sub="Lunch and dinner",
        cig="After meals", vape="After meals",
        hours=[13.0, 19.5], days="every day", risk="medium",
        why="Twice daily and highly ritualised, so it is the trigger that most often ends a second-week quit.",
        craving="The after-dinner one. Stand up and it goes faster.",
        swaps=["Leave the table straight away", "Wash up immediately", "Walk round the block"],
    ),
    dict(
        id="driving", label="Driving", sub="Commute, errands",
        cig="In the car", vape="In the car",
        hours=[8.5, 17.5], days="weekdays", risk="medium",
        why="A confined space with a fixed routine. Strongly cued and impossible to avoid if you drive to work.",
        craving="You are in the car. It lasts less than the journey.",
        swaps=["Clean the car once, properly", "Different route for two weeks", "Something to chew"],
    ),
    dict(
        id="drink", label="With a drink", sub="Pub, wine, out",
        cig="When I'm drinking", vape="When I'm drinking",
        hours=[21.0], days="Fri and Sat", risk="highest",
        why="Alcohol lowers restraint and the setting is dense with other people doing it. The single most common cause of a first slip.",
        craving="Drinking makes this one louder, not stronger. Same three minutes.",
        swaps=["Tell one person you have stopped", "Stay away from the smoking area", "Leave before the last round"],
    ),
    dict(
        id="stress", label="Stress", sub="Work, pressure, rows",
        cig="When it gets much", vape="When it gets much",
        hours=[11.0, 16.0], days="weekdays", risk="high",
        why="The one people believe most firmly, and the one that is least true: nicotine relieves withdrawal, not stress.",
        craving="Nothing about this is calming you. It is the withdrawal, arriving on schedule.",
        swaps=["Outside for two minutes", "The breathing screen", "Text someone"],
    ),
    dict(
        id="boredom", label="Boredom", sub="Breaks, waiting, nothing on",
        cig="With nothing else on", vape="With nothing else on",
        hours=[15.0, 22.0], days="every day", risk="low",
        why="The least urgent and the easiest to redirect, because it is about the gap rather than the nicotine.",
        craving="Nothing is wrong. There is just a gap, and this used to fill it.",
        swaps=["Anything with your hands", "A short walk", "Put something on"],
    ),
    dict(
        id="others", label="Around others", sub="Friends who still do",
        cig="When others light up", vape="When others are on theirs",
        hours=[18.0], days="Fri and Sat", risk="high",
        why="Social cue plus availability plus permission. Being offered one is a different problem from wanting one.",
        craving="Someone else having one is not you needing one.",
        swaps=["Say it out loud once", "Stand somewhere else", "Have the sentence ready"],
    ),
]

IDEAS = [
    dict(name="Learn from slips", cost="Small", value="High", ships="With the trigger question",
         body="Logging a slip already exists. Add one tap: which of your triggers was it? "
              "After three or four the app knows the real pattern rather than the declared one, "
              "and can move a nudge to where slips actually happen. This is the only idea here "
              "that makes the plan get better over time, which is what makes it a plan."),
    dict(name="First seventy-two hours", cost="Small", value="High", ships="Independent",
         body="For three days the headline is the countdown to nicotine leaving, not the money, "
              "and the craving button is bigger. Reverts on its own. No new screens, only a "
              "different emphasis during the days that decide it."),
    dict(name="Warn before, not after", cost="Small", value="High", ships="Needs triggers",
         body="A nudge fifteen minutes ahead of a known hard moment beats one afterwards. "
              "First week only, then it stops. Being told at 20:45 on a Friday is useful once "
              "and irritating by the fourth time."),
    dict(name="The sentence you'll use", cost="Small", value="Medium", ships="Needs triggers",
         body="For the top trigger only, pick what you will do instead. Written as an if-then, "
              "which is among the better evidenced behaviour change techniques. It then appears "
              "on the craving screen at that hour, in the user's own words."),
    dict(name="Backdating properly", cost="Medium", value="Medium", ships="Independent",
         body="The picker stops at six days back, so 'I quit a while ago' has nowhere to go. "
              "Extending it means past milestones must be marked as already seen, with at most "
              "one summary, or someone backdating a month gets six celebrations in a row."),
    dict(name="First Friday", cost="Small", value="Medium", ships="Needs triggers",
         body="If drinking is a trigger, the first Friday night after stopping is the highest "
              "risk evening of the quit. One message, that evening, once ever."),
    dict(name="Widget or Live Activity", cost="Large", value="Medium", ships="Independent",
         body="The day count and the money on the lock screen. Genuinely useful and genuinely "
              "a lot of work, including a second rendering path for the spiral. Worth it later, "
              "not now."),
    dict(name="A coach voice", cost="Large", value="Low", ships="Not recommended",
         body="Listed because the running app has one and it would be easy to copy. Exhale has "
              "no voice to pick between, so it would be a screen that exists to look like there "
              "is more configuration than there is."),
]

page = """<meta charset="utf-8">
<title>Exhale: one more question</title>
<style>
""" + fonts + """
  :root{
    --bg:#081A1D; --fg:#E9F5F3; --muted:rgba(233,245,243,.60);
    --faint:rgba(233,245,243,.40); --accent:#7FD8CB; --on:#06181B;
    --ember:#E8743B; --emberSoft:#E8A87F; --card:rgba(233,245,243,.14);
    --hair:rgba(233,245,243,.08); --ground:#0A1012; --panel:#12181A;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--ground);color:var(--fg);
       font-family:'SG',ui-sans-serif,system-ui,sans-serif;padding:26px 26px 100px}
  h1{font-size:19px;margin:0 0 6px;letter-spacing:-.01em}
  h2{font-size:11.5px;margin:34px 0 10px;letter-spacing:.16em;text-transform:uppercase;
     color:var(--accent)}
  .lede{font-size:13px;line-height:1.62;color:var(--muted);max-width:82ch;margin:0 0 8px}
  .lede b{color:var(--fg)}
  .cols{display:flex;gap:22px;flex-wrap:wrap;align-items:flex-start}
  .phone{width:262px;flex:none;background:var(--bg);border-radius:32px;position:relative;
         overflow:hidden;display:flex;flex-direction:column;padding:0 17px 20px;height:566px;
         box-shadow:0 12px 44px rgba(0,0,0,.55)}
  .island{position:absolute;top:7px;left:50%;transform:translateX(-50%);
          width:84px;height:25px;border-radius:16px;background:#000;z-index:5}
  .status{height:32px;flex:none;display:flex;align-items:center;justify-content:space-between;
          padding:0 5px;font-size:9.5px;font-weight:500;opacity:.9}
  .body{flex:1;min-height:0;overflow:hidden;padding-top:16px;display:flex;flex-direction:column}
  .h{font-size:19.5px;font-weight:700;line-height:1.2}
  .sub{font-size:11.4px;line-height:1.5;color:var(--muted);margin-top:8px}
  .opt{display:flex;align-items:center;gap:9px;padding:8px 11px;border-radius:12px;
       border:1.1px solid var(--card);margin-top:6px;cursor:pointer;
       transition:border-color .12s,background .12s}
  .opt:hover{border-color:rgba(233,245,243,.30)}
  .opt.on{border-color:var(--accent);background:rgba(127,216,203,.10)}
  .ot{font-size:11.6px;font-weight:700}
  .os{font-size:8.8px;color:var(--muted);margin-top:1px}
  .ck{width:14px;height:14px;border-radius:50%;flex:none;
      border:1.5px solid rgba(233,245,243,.30)}
  .opt.on .ck{background:var(--accent);border-color:transparent}
  .cta{height:42px;border-radius:21px;background:var(--accent);color:var(--on);display:flex;
       align-items:center;justify-content:center;font-size:12.4px;font-weight:700;margin-top:auto}
  .cta.off{background:rgba(233,245,243,.10);color:var(--faint)}
  .out{flex:1;min-width:330px}
  .panel{background:var(--panel);border:1px solid var(--hair);border-radius:16px;
         padding:14px 16px;margin-bottom:12px}
  .pt{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);
      margin-bottom:9px}
  .empty{font-size:12px;color:var(--faint);line-height:1.6}
  .clock{display:flex;gap:2px;margin:4px 0 10px;align-items:flex-end;height:52px}
  .hr{flex:1;background:rgba(233,245,243,.07);border-radius:2px;position:relative;height:12px}
  .hr.lit{background:var(--accent);height:38px}
  .hr.lit.hot{background:var(--ember)}
  .hrlab{display:flex;justify-content:space-between;font-size:9px;color:var(--faint);
         margin-bottom:12px}
  .msg{border-left:2px solid rgba(127,216,203,.4);padding:2px 0 2px 11px;margin-bottom:11px}
  .mw{font-size:9.6px;color:var(--faint);letter-spacing:.05em}
  .mt{font-size:12px;font-weight:700;margin-top:2px}
  .mx{font-size:11.6px;color:var(--muted);line-height:1.45;margin-top:1px}
  .row2{display:flex;justify-content:space-between;font-size:11.6px;padding:6px 0;
        border-bottom:1px solid var(--hair)}
  .row2 span:last-child{color:var(--muted);text-align:right;max-width:62%}
  .ideas{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(280px,1fr))}
  .idea{background:var(--panel);border:1px solid var(--hair);border-radius:16px;padding:14px}
  .in{font-size:13px;font-weight:700}
  .ib{font-size:11.5px;color:var(--muted);line-height:1.5;margin-top:7px}
  .tags{display:flex;gap:5px;margin-top:9px;flex-wrap:wrap}
  .tag{font-size:9px;letter-spacing:.06em;text-transform:uppercase;padding:3px 7px;
       border-radius:999px;border:1px solid var(--hair);color:var(--faint)}
  .tag.v{color:var(--accent);border-color:rgba(127,216,203,.3)}
  .tag.c{color:var(--emberSoft);border-color:rgba(232,116,59,.3)}
  .prodbar{display:flex;gap:6px;margin-bottom:14px}
  .pb{font:inherit;font-size:12px;background:none;color:var(--muted);border:1px solid var(--card);
      border-radius:999px;padding:5px 12px;cursor:pointer}
  .pb.on{background:var(--accent);color:var(--on);border-color:transparent;font-weight:700}
</style>

<h1>One more question, and what it would actually do</h1>
<p class="lede">A proposal. The argument against a "building your plan" screen is that there is no
plan to build: a start date, a spend figure, and a milestone list identical for everyone. This is the
one question that would change that, plus everything downstream of it.
<b>Pick triggers on the left and watch the right side change.</b> Nothing here is decorative; every
field feeds something the user sees.</p>
<p class="lede" style="margin-bottom:18px">The honest test for each idea below: does it change what
the app <i>does</i>, or only what it <i>says</i>?</p>

<div class="prodbar" id="prodBar"></div>

<div class="cols">
  <div class="phone">
    <div class="island"></div>
    <div class="status"><span>9:41</span><span>|||  100%</span></div>
    <div class="body">
      <div class="h" id="qh">When does it usually happen?</div>
      <div class="sub">Pick the ones you recognise. Two or three is plenty.</div>
      <div id="opts" style="margin-top:10px;overflow:auto"></div>
      <div class="cta" id="cta">Continue</div>
    </div>
  </div>
  <div class="out" id="out"></div>
</div>

<h2>Other ideas, ranked by whether they earn their space</h2>
<div class="ideas" id="ideas"></div>

<script>
const TRIGGERS = """ + json.dumps(TRIGGERS) + """;
const IDEAS = """ + json.dumps(IDEAS) + """;
let PRODUCT = "cig";
const picked = new Set(["coffee", "drink"]);

const PRODUCTS = [["cig","Cigarettes"],["vape","Vape"],["pouch","Pouches"]];
const VERB = {cig:"smoke", vape:"vape", pouch:"have one"};

function label(t){ return PRODUCT === "vape" ? t.vape : t.cig; }

function renderQuestion(){
  document.getElementById('qh').textContent =
    `When do you usually ${VERB[PRODUCT]}?`;
  document.getElementById('opts').innerHTML = TRIGGERS.map(t => `
    <div class="opt ${picked.has(t.id) ? 'on' : ''}" data-id="${t.id}">
      <div style="flex:1"><div class="ot">${label(t)}</div><div class="os">${t.sub}</div></div>
      <div class="ck"></div></div>`).join('');
  const cta = document.getElementById('cta');
  cta.className = 'cta' + (picked.size ? '' : ' off');
  cta.textContent = picked.size ? 'Continue' : 'Skip this';
}

function hours(){
  const set = new Map();
  for (const t of TRIGGERS){
    if (!picked.has(t.id)) continue;
    for (const h of t.hours) set.set(h, t);
  }
  return [...set.entries()].sort((a,b) => a[0]-b[0]);
}

function fmt(h){
  const hh = Math.floor(h), mm = Math.round((h - hh) * 60);
  return `${String(hh).padStart(2,'0')}:${String(mm).padStart(2,'0')}`;
}

function render(){
  renderQuestion();
  const out = document.getElementById('out');
  if (!picked.size){
    out.innerHTML = `<div class="panel"><div class="pt">What changes</div>
      <div class="empty">Nothing. Skipping is allowed, and the app behaves exactly as it does
      today: one morning nudge at 09:00, a generic craving screen, and a milestone list shared
      with everyone else. That is the current product, and it is the thing worth beating.</div>
      </div>`;
    return;
  }

  const chosen = TRIGGERS.filter(t => picked.has(t.id));
  const top = chosen.slice().sort((a,b) =>
    ["low","medium","high","highest"].indexOf(b.risk) -
    ["low","medium","high","highest"].indexOf(a.risk))[0];
  const all = hours();
  // Picking everything would mean a dozen warnings a day, which is worse than
  // none. The app has to cap it, so the preview caps it too and says so.
  const CAP = 3;
  const hs = all.slice(0, CAP);
  const trimmed = all.length - hs.length;

  const bars = [...Array(24)].map((_, i) => {
    const hit = hs.find(([h]) => Math.floor(h) === i);
    const dim = !hit && all.find(([h]) => Math.floor(h) === i);
    const hot = hit && hit[1].risk === "highest";
    return `<div class="hr ${hit ? 'lit' : ''} ${hot ? 'hot' : ''}"
      style="${dim ? 'background:rgba(127,216,203,.22);height:22px' : ''}"></div>`;
  }).join('');

  out.innerHTML = `
    ${trimmed > 0 ? `<div class="panel" style="border-color:rgba(232,116,59,.4)">
      <div class="pt" style="color:var(--emberSoft)">Capped</div>
      <div class="empty" style="font-size:11.5px">You picked enough to generate
      <b style="color:var(--fg)">${all.length} warnings a day</b>. Nobody survives that, and an
      app that buzzes twelve times is one people turn off entirely. Only the
      ${CAP} riskiest are used; the rest still shape the craving screen, which
      costs nothing because it is only read when opened.</div></div>` : ''}
    <div class="panel">
      <div class="pt">Your hours</div>
      <div class="clock">${bars}</div>
      <div class="hrlab"><span>00:00</span><span>06:00</span><span>12:00</span>
        <span>18:00</span><span>23:00</span></div>
      <div class="empty" style="font-size:11.5px">Derived, not asked for. These replace the fixed
      09:00 nudge with the times this person is actually at risk.</div>
    </div>

    <div class="panel">
      <div class="pt">Notifications, first week only</div>
      ${hs.map(([h, t]) => `
        <div class="msg">
          <div class="mw">${fmt(h - 0.25)} &middot; ${t.days}</div>
          <div class="mt">About now</div>
          <div class="mx">${t.craving}</div>
        </div>`).join('')}
      <div class="empty" style="font-size:11.2px">Ahead of the moment rather than after it, and
      only for seven days. A warning that keeps arriving becomes furniture.</div>
    </div>

    <div class="panel">
      <div class="pt">Craving screen, when opened at ${fmt(hs[0][0])}</div>
      <div class="mt" style="font-size:13px">${hs[0][1].craving}</div>
      <div class="empty" style="margin-top:8px;font-size:11.2px">Today this says the same sentence
      at every hour. With a trigger and a clock it can name the one you are in.</div>
    </div>

    <div class="panel">
      <div class="pt">What the app now knows</div>
      ${chosen.map(t => `<div class="row2"><span>${label(t)}</span>
        <span>${t.why}</span></div>`).join('')}
    </div>

    <div class="panel">
      <div class="pt">The plan screen, earned</div>
      <div class="row2"><span>Hardest moment</span><span>${label(top)}, ${top.days}</span></div>
      <div class="row2"><span>Watch out at</span><span>${hs.map(([h]) => fmt(h)).join(', ')}</span></div>
      <div class="row2"><span>Your swap</span><span>${top.swaps[0]}</span></div>
      <div class="row2" style="border:none"><span>First test</span>
        <span>${top.days.includes('Fri') ? 'This Friday evening' : 'Tomorrow ' + fmt(hs[0][0])}</span></div>
      <div class="empty" style="margin-top:10px;font-size:11.2px">This is the difference between a
      loading screen that pretends and one that has something to show at the end of it.</div>
    </div>`;
}

document.getElementById('opts').addEventListener('click', e => {
  const el = e.target.closest('.opt');
  if (!el) return;
  const id = el.dataset.id;
  picked.has(id) ? picked.delete(id) : picked.add(id);
  render();
});

const pb = document.getElementById('prodBar');
pb.innerHTML = PRODUCTS.map(([k, n]) =>
  `<button class="pb ${k === PRODUCT ? 'on' : ''}" data-k="${k}">${n}</button>`).join('');
pb.addEventListener('click', e => {
  const b = e.target.closest('.pb'); if (!b) return;
  PRODUCT = b.dataset.k;
  [...pb.children].forEach(x => x.classList.remove('on'));
  b.classList.add('on');
  render();
});

document.getElementById('ideas').innerHTML = IDEAS.map(i => `
  <div class="idea">
    <div class="in">${i.name}</div>
    <div class="ib">${i.body}</div>
    <div class="tags"><span class="tag v">Value ${i.value}</span>
      <span class="tag c">Cost ${i.cost}</span>
      <span class="tag">${i.ships}</span></div>
  </div>`).join('');

render();
</script>
"""

pathlib.Path("tools/preview/plan.html").write_text(page, encoding="utf-8")
print(f"wrote tools/preview/plan.html  {len(page)/1024:.0f} KB")
print(f"triggers: {len(TRIGGERS)}   ideas: {len(IDEAS)}")
