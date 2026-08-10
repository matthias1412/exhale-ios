"""Mirrors NotificationCopy.swift so the whole first month can be read at once.

Kept in step by tools/lint-notifications.py, which fails if a case is added in
Swift and not here.
"""
import json
import pathlib

fonts = pathlib.Path("tools/preview/_fonts.css").read_text(encoding="utf-8")

REASONS = [
    ("health",  "My health"),
    ("money",   "The money"),
    ("someone", "Someone in particular"),
    ("freedom", "Being free of it"),
    ("fitness", "Fitness and breath"),
    ("smell",   "The smell of it"),
    ("none",    "Skipped the question"),
]

MILESTONES = [
    (0.34, "20 min",  "Heart rate settles",        "Pulse and blood pressure drift back toward normal."),
    (12,   "12 h",    "Carbon monoxide clears",    "Oxygen levels in your blood return to normal."),
    (48,   "48 h",    "Taste & smell sharpen",     "Nerve endings start repairing. Food gets better."),
    (72,   "72 h",    "Nicotine-free body",        "The nicotine itself is out of your system. It's habit now, not chemistry."),
    (168,  "1 week",  "Peak cravings behind you",  "The worst of the urges is statistically over."),
    (336,  "2 weeks", "Walking gets easier",       "Walking and exercise start feeling easier."),
    (720,  "1 month", "Sleep and mood level out",  "Sleep, focus and mood level out without the spikes."),
]


def person(name):
    n = (name or "").strip()
    return n or None


def day_one(reason, name):
    who = person(name)
    body = {
        "health":  "From this hour your body starts putting itself back. Twenty minutes for the first change.",
        "money":   "The meter starts now, and it runs in your favour from here.",
        "someone": f"This is the one for {who}." if who else "This is the one for the person you had in mind.",
        "freedom": "Nothing owns you from here. Today is the first day of that.",
        "fitness": "Your breath starts coming back today. You'll notice it on stairs first.",
        "smell":   "Give it a few days and your clothes will stop smelling of it.",
        "none":    "Day one starts now. Twenty minutes to the first change.",
    }[reason]
    return ("Day one", body)


def eve(reason, name):
    who = person(name)
    if reason == "money":
        body = "Last night of paying for it. Tomorrow the money starts staying put."
    elif reason == "someone":
        body = f"{who} is the reason. Tomorrow it starts." if who else "Tomorrow it starts."
    elif reason == "freedom":
        body = "Last night of needing it. Get some sleep."
    else:
        body = "Whatever's left, finish it or bin it tonight. Day one is tomorrow."
    return ("Tomorrow's the day", body)


def morning(day, reason, name):
    who = person(name)
    if day < 2:
        return (f"Day {day}", "The first day is the loudest one. It gets quieter from here.")
    if day == 2:
        return ("Day 2", "Day two is usually the worst of it. That's not a warning, it's the peak.")
    if day == 3:
        return ("Day 3", "By tonight the nicotine is out of you. What's left after that is habit.")
    if 4 <= day <= 6:
        return (f"Day {day}", f"{day - 1} days done. Today is just the next one.")
    later = {
        "money":   "Another day of not handing money over.",
        "someone": f"{who} is still the reason." if who else "Still going, for the reason you gave.",
        "health":  "Your lungs are further along than they were last week.",
        "fitness": "Around now, stairs start giving you less trouble.",
        "smell":   "Your clothes stopped carrying it a while ago.",
        "freedom": "Not smoking is turning into the ordinary thing you do.",
        "none":    "Not smoking is turning into the ordinary thing you do.",
    }[reason]
    return (f"Day {day}", later)


def weekly(this_week, total, reason, name):
    body = f"{this_week} stayed in your pocket this week. {total} since you stopped."
    return ("Another week clear", body)


# The figures are computed the way the app computes them, from a weekly spend,
# rather than typed in. An earlier hand-written pair read "€30 this week, €26
# since you stopped", which is arithmetically impossible and exactly the kind
# of thing a fake number sneaks past a review.
WEEKLY_SPEND = 30.0          # euros; whatever the user told us in onboarding
DAILY = WEEKLY_SPEND / 7


def money(days):
    return max(0.0, days) * DAILY


def euros(v):
    return "€" + f"{v:,.0f}"


def bill_at(days_quit):
    total = money(days_quit)
    this_week = max(0.0, total - money(days_quit - 7))
    return euros(this_week), euros(total)


def timeline(reason, name, scheduled):
    """Everything that lands in the first month, in order."""
    out = []
    if scheduled:
        out.append(("Sun 20:00", "eve", *eve(reason, name)))
    out.append(("Mon 08:00", "start", *day_one(reason, name)))
    out.append(("Mon 08:20", "milestone", MILESTONES[0][2], f"{MILESTONES[0][1]} in. {MILESTONES[0][3]}"))
    out.append(("Mon 20:00", "milestone", MILESTONES[1][2], f"{MILESTONES[1][1]} in. {MILESTONES[1][3]}"))
    out.append(("Tue 09:00", "morning", *morning(2, reason, name)))
    out.append(("Wed 08:00", "milestone", MILESTONES[2][2], f"{MILESTONES[2][1]} in. {MILESTONES[2][3]}"))
    out.append(("Wed 09:00", "morning", *morning(3, reason, name)))
    out.append(("Thu 08:00", "milestone", MILESTONES[3][2], f"{MILESTONES[3][1]} in. {MILESTONES[3][3]}"))
    out.append(("Thu 09:00", "morning", *morning(4, reason, name)))
    out.append(("Sun 10:00", "bill", *weekly(*bill_at(6.08), reason, name)))
    out.append(("Mon 08:00", "milestone", MILESTONES[4][2], f"{MILESTONES[4][1]} in. {MILESTONES[4][3]}"))
    out.append(("Sun 10:00", "bill", *weekly(*bill_at(13.08), reason, name)))
    out.append(("Mon 08:00", "milestone", MILESTONES[5][2], f"{MILESTONES[5][1]} in. {MILESTONES[5][3]}"))
    out.append(("Tue 09:00", "morning", *morning(16, reason, name)))
    out.append(("Sun 10:00", "bill", *weekly(*bill_at(20.08), reason, name)))
    out.append(("Wed 08:00", "milestone", MILESTONES[6][2], f"{MILESTONES[6][1]} in. {MILESTONES[6][3]}"))
    out.append(("Thu 09:00", "morning", *morning(32, reason, name)))
    return out


DATA = {
    key: {
        "label": label,
        "scheduled": timeline(key, "Emma", True),
        "immediate": timeline(key, "Emma", False),
    }
    for key, label in REASONS
}

page = """<meta charset="utf-8">
<title>Exhale — every notification</title>
<style>
""" + fonts + """
  :root{
    --ground:#0A1012; --panel:#12181A; --line:rgba(233,245,243,.10);
    --ink:#E9F5F3; --ink-2:rgba(233,245,243,.60); --ink-3:rgba(233,245,243,.38);
    --accent:#7FD8CB; --ember:#E8A87F;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--ground);color:var(--ink);
       font-family:'SG',ui-sans-serif,system-ui,sans-serif;padding:26px 26px 90px}
  h1{font-size:19px;margin:0 0 6px;letter-spacing:-.01em}
  .lede{font-size:13px;line-height:1.6;color:var(--ink-2);max-width:80ch;margin:0 0 20px}
  .lede b{color:var(--ink)}
  .rail{display:flex;flex-wrap:wrap;gap:12px;align-items:center;
        border-bottom:1px solid var(--line);padding-bottom:14px;margin-bottom:20px}
  .lbl{font-size:10.5px;letter-spacing:.14em;text-transform:uppercase;color:var(--ink-3)}
  button{font:inherit;font-size:12.5px;background:none;color:var(--ink-2);
         border:1px solid var(--line);border-radius:999px;padding:6px 13px;cursor:pointer}
  button:hover{color:var(--ink);border-color:rgba(233,245,243,.28)}
  button.on{background:var(--accent);color:#06181B;border-color:transparent;font-weight:700}
  button:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
  .feed{max-width:430px}
  .when{font-size:10.5px;color:var(--ink-3);letter-spacing:.06em;margin:16px 0 6px;
        text-transform:uppercase}
  .n{background:var(--panel);border-radius:17px;padding:11px 13px;margin-bottom:7px;
     display:flex;gap:10px;align-items:flex-start;
     box-shadow:0 1px 0 rgba(255,255,255,.03) inset}
  .ico{width:26px;height:26px;border-radius:7px;flex:none;position:relative;
       background:#081A1D;overflow:hidden}
  .nb{flex:1;min-width:0}
  .nt{font-size:12.5px;font-weight:700;line-height:1.3}
  .nx{font-size:12px;color:var(--ink-2);line-height:1.42;margin-top:2px}
  .tag{font-size:8.6px;letter-spacing:.09em;text-transform:uppercase;color:var(--ink-3);
       margin-left:auto;flex:none;padding-top:2px}
  .tag.start{color:var(--accent)}
  .tag.eve{color:var(--ember)}
  .count{font-size:11.5px;color:var(--ink-3);margin-top:18px}
</style>

<h1>Exhale — every notification</h1>
<p class="lede">The whole first month on one page, so the wording can be read the way it will be
received rather than found on a phone in three days. <b>The reason now reaches the lock screen</b> —
it drove the craving screen and the opening tab before, but every notification was generic, so
someone quitting for Emma never once saw her name. Switch reason and start type below.</p>
<p class="lede" style="margin-top:-10px">Every figure here is <b>computed from the plan</b>, not
typed in — this timeline assumes €30 a week, so a €90-a-week smoker sees three times these numbers.
The first Sunday reads the same twice because a partial first week <i>is</i> the whole total.</p>

<div class="rail">
  <span class="lbl">Reason</span><span id="reasonBar"></span>
</div>
<div class="rail" style="margin-top:-8px">
  <span class="lbl">Start</span><span id="startBar"></span>
</div>

<div class="feed" id="feed"></div>

<script>
const DATA = """ + json.dumps(DATA) + """;
const GOLD = 2.399963;
let REASON = "someone", MODE = "scheduled";

function markInto(el){
  const box = 26, n = 55, sc = box/26, c = 13*sc,
        hole = 3.1*sc, maxR = 12.4*sc, d = 1.85*sc;
  let h = '';
  for (let i = 0; i < n; i++){
    const t = i/(n-1), r = hole + (maxR-hole)*Math.sqrt(t), a = i*GOLD - 1.6;
    h += `<div style="position:absolute;left:${(c+r*Math.cos(a)-d/2).toFixed(2)}px;`
      +  `top:${(c+r*Math.sin(a)-d/2).toFixed(2)}px;width:${d.toFixed(2)}px;`
      +  `height:${d.toFixed(2)}px;border-radius:50%;`
      +  `background:hsl(${Math.round(18+t*154)} ${Math.round(85-t*25)}% ${Math.round(54+t*8)}%)"></div>`;
  }
  el.innerHTML = h;
}

function render(){
  const rows = DATA[REASON][MODE];
  const feed = document.getElementById('feed');
  let html = '', lastWhen = null;
  for (const [when, kind, title, body] of rows){
    if (when !== lastWhen){ html += `<div class="when">${when}</div>`; lastWhen = when; }
    html += `<div class="n"><div class="ico"></div><div class="nb">
      <div class="nt">${title}</div><div class="nx">${body}</div></div>
      <div class="tag ${kind}">${kind}</div></div>`;
  }
  html += `<div class="count">${rows.length} notifications in the first month —
    about ${(rows.length/4.3).toFixed(1)} a week.</div>`;
  feed.innerHTML = html;
  feed.querySelectorAll('.ico').forEach(markInto);
}

const rb = document.getElementById('reasonBar');
for (const [key, o] of Object.entries(DATA)){
  const b = document.createElement('button');
  b.textContent = o.label;
  if (key === REASON) b.className = 'on';
  b.onclick = () => { REASON = key;
    [...rb.children].forEach(x => x.className = ''); b.className = 'on'; render(); };
  rb.appendChild(b);
}
const sb = document.getElementById('startBar');
for (const [key, label] of [["scheduled","Picked a date (Monday)"],["immediate","Just had my last one"]]){
  const b = document.createElement('button');
  b.textContent = label;
  if (key === MODE) b.className = 'on';
  b.onclick = () => { MODE = key;
    [...sb.children].forEach(x => x.className = ''); b.className = 'on'; render(); };
  sb.appendChild(b);
}
render();
</script>
"""

pathlib.Path("tools/preview/notifications.html").write_text(page, encoding="utf-8")
print(f"wrote tools/preview/notifications.html  {len(page)/1024:.0f} KB")
print(f"reasons: {len(REASONS)}   messages per timeline: {len(DATA['someone']['scheduled'])}")
