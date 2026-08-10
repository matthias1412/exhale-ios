import json
import pathlib

fonts = pathlib.Path("tools/preview/_fonts.css").read_text(encoding="utf-8")

# ---------------------------------------------------------------- screens
# Each screen carries its variants. `body` and `foot` are raw markup; the
# scaffolding (status bar, header, progress) is shared.
S = []

S.append(dict(step="0 · Welcome", note="the one you objected to", prog=None, variants=[
  dict(name="Behind you", body="""
    <div class="body mid">
      <div class="dots" data-mark="46" style="width:46px;height:46px;margin-bottom:18px"></div>
      <div class="h">Your last one<br>is behind you.</div>
      <div class="sub">The first three days are the hard part. After that the nicotine is gone and
      what's left is habit, and habit is beatable.<br><br>
      <b>Exhale is built for those three days,</b> and every one after.</div>
    </div>""",
    foot='<div class="cta">Let\'s start</div><div class="cta ghost">I quit a while ago</div>'),

  dict(name="Already done", body="""
    <div class="body mid">
      <div class="dots" data-mark="46" style="width:46px;height:46px;margin-bottom:18px"></div>
      <div class="h">The hardest part<br>is already done.</div>
      <div class="sub">You decided. Everything after this is just getting through the days,
      and we'll count every single one of them with you.<br><br>
      <b>Starting with the next three.</b></div>
    </div>""",
    foot='<div class="cta">Let\'s start</div><div class="cta ghost">I quit a while ago</div>'),

  dict(name="72 hours", body="""
    <div class="body mid">
      <div class="dots" data-mark="46" style="width:46px;height:46px;margin-bottom:18px"></div>
      <div class="h">Seventy-two hours.</div>
      <div class="sub">That's how long the nicotine takes to leave. After that you're not fighting
      chemistry any more, you're breaking a habit, and habits break.<br><br>
      <b>This is for both halves.</b></div>
    </div>""",
    foot='<div class="cta">Let\'s start</div><div class="cta ghost">I quit a while ago</div>'),
]))

S.append(dict(step="1 · Product", note="settled", prog=0, variants=[
  dict(name="As built", body="""
    <div class="body">
      <div class="h sm">What are you quitting?</div>
      <div class="sub">No judgement. This only changes what we count.</div>
      <div class="row"><div style="flex:1"><div class="rt">Cigarettes</div>
        <div class="rs">packs, rollies</div></div><div class="ring"></div></div>
      <div class="row sel"><div style="flex:1"><div class="rt">Vape</div>
        <div class="rs">pods, disposables</div></div><div class="ring on"></div></div>
      <div class="row"><div style="flex:1"><div class="rt">Nicotine pouches</div>
        <div class="rs">snus, pouches</div></div><div class="ring"></div></div>
      <div class="note">Most people who smoke want to stop, and most who manage it needed more than
      one go. You're not doing something unusual.</div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),
]))

S.append(dict(step="2 · Amount", note="", prog=1, variants=[
  dict(name="As built", body="""
    <div class="body">
      <div class="h sm">Pods in a normal week?</div>
      <div class="sub">Your honest average. Rough is fine.</div>
      <div class="stepper"><div class="circ">−</div>
        <div><div class="num">5</div><div class="unit">PODS A WEEK</div></div>
        <div class="circ">+</div></div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),
]))

S.append(dict(step="3 · Spend", note="", prog=2, variants=[
  dict(name="As built", body="""
    <div class="body">
      <div class="h sm">Spend on vaping in a normal week?</div>
      <div class="sub">Prices in EUR · <b style="color:var(--accent)">Change</b></div>
      <div class="stepper" style="margin-top:18px"><div class="circ">−</div>
        <div class="price">€30</div><div class="circ">+</div></div>
      <div class="burn"><div class="burnm">≈ €130 a month, vanishing into vapour</div>
        <div class="burny">€1,560</div><div class="burnl">a year, gone</div></div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),
]))

S.append(dict(step="4 · Why", note="you liked this one", prog=3, variants=[
  dict(name="Why this time", body="""
    <div class="body">
      <div class="h sm">Why this time?</div>
      <div class="sub">Pick any that are true.</div>
      <div class="row"><div style="flex:1"><div class="rt">My health</div>
        <div class="rs">Lungs, heart, the long game</div></div><div class="ring"></div></div>
      <div class="row sel"><div style="flex:1"><div class="rt">Someone in particular</div>
        <div class="rs">A partner, a child, a parent</div></div>
        <div class="badge">MAIN</div><div class="ring on"></div></div>
      <div class="row"><div style="flex:1"><div class="rt">The money</div>
        <div class="rs">It adds up to real things</div></div><div class="ring"></div></div>
      <div class="row"><div style="flex:1"><div class="rt">Being free of it</div>
        <div class="rs">Not needing anything</div></div><div class="ring"></div></div>
      <div class="field">Emma</div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),

  dict(name="Who's it for", body="""
    <div class="body">
      <div class="h sm">Who is this for?</div>
      <div class="sub">We'll hand it back to you on the days it's hard.</div>
      <div class="row"><div style="flex:1"><div class="rt">Me</div>
        <div class="rs">My lungs, my heart, my money</div></div><div class="ring"></div></div>
      <div class="row sel"><div style="flex:1"><div class="rt">Someone in particular</div>
        <div class="rs">A partner, a child, a parent</div></div>
        <div class="badge">MAIN</div><div class="ring on"></div></div>
      <div class="row"><div style="flex:1"><div class="rt">The person I'd rather be</div>
        <div class="rs">Not needing anything</div></div><div class="ring"></div></div>
      <div class="field">Their name, if you like. Emma</div>
      <div class="note">Kept on your phone. Never sent anywhere.</div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),
]))

S.append(dict(step="5 · Cravings", note="new: normal, and we help", prog=4, variants=[
  dict(name="Three minutes", body="""
    <div class="body mid">
      <div class="h sm">A craving lasts about three minutes.</div>
      <div class="sub">It arrives, it peaks, and it goes, <b>whether you smoke or not.</b>
      That's not willpower talking, it's just how they work.<br><br>
      The trick is having somewhere to put those three minutes.</div>
      <div class="sos">I'm craving, help me through it</div>
      <div class="sub" style="margin-top:8px">On every screen. One tap starts a timer and a breath.</div>
    </div>""", foot='<div class="cta">Good to know</div>'),

  dict(name="Not a warning sign", body="""
    <div class="body mid">
      <div class="h sm">Cravings aren't a sign it's going wrong.</div>
      <div class="sub">Everyone gets them, they're worst in the first week, and they pass in about
      three minutes on their own.<br><br>
      What matters is what you do with those three minutes.</div>
      <div class="sos">I'm craving, help me through it</div>
      <div class="sub" style="margin-top:8px">This button is on every screen in the app.</div>
    </div>""", foot='<div class="cta">Good to know</div>'),

  dict(name="Willpower runs out", body="""
    <div class="body mid">
      <div class="quote">Willpower runs out. Everyone's does.<br><br>
      A craving doesn't care how motivated you are. It arrives, peaks in about three minutes
      and leaves, <em>whether you smoke or not</em>.<br><br>
      What gets people through is having something to do for those three minutes.</div>
      <div class="sos" style="margin-top:14px">I'm craving, help me through it</div>
    </div>""", foot='<div class="cta">Makes sense</div>'),
]))

S.append(dict(step="6 · Slips", note="new: it happens, and it is handled", prog=5, variants=[
  dict(name="Not a reset", body="""
    <div class="body mid">
      <div class="h sm">If you slip, you haven't failed.</div>
      <div class="sub">Most people who stop for good slipped on the way. One cigarette is one
      cigarette, and <b>it doesn't wipe out the forty days behind it.</b><br><br>
      There's a button for that too. Tell the truth, keep your history, carry on.</div>
      <div class="slip">I slipped</div>
    </div>""", foot='<div class="cta">Got it</div>'),

  dict(name="The dangerous bit", body="""
    <div class="body mid">
      <div class="h sm">The cigarette isn't the dangerous part.</div>
      <div class="sub">Deciding you've blown it is. That's what turns one slip into starting over
      in six months.<br><br>
      So log it, keep every day you've already earned, and keep going. The app is built to let
      you do exactly that.</div>
      <div class="slip">I slipped</div>
    </div>""", foot='<div class="cta">Got it</div>'),

  dict(name="Plain", body="""
    <div class="body mid">
      <div class="h sm">Slips happen.</div>
      <div class="sub">They happen to most people who eventually quit for good. What matters is
      what happens next.<br><br>
      Log it in one tap. Your streak keeps its history, the app doesn't lecture you, and you
      pick up where you were.</div>
      <div class="slip">I slipped</div>
    </div>""", foot='<div class="cta">Got it</div>'),
]))

S.append(dict(step="7 · Day one", note="", prog=6, variants=[
  dict(name="Now is strongest", body="""
    <div class="body">
      <div class="h sm">When does day one start?</div>
      <div class="sub">Now is the strongest answer. But a day you'll keep beats a day you won't.</div>
      <div class="cta out" style="margin-top:16px">Just had one, start now</div>
      <div class="or">OR PICK A DAY</div>
      <div class="chips"><div class="chip">Tomorrow</div><div class="chip on">Monday</div>
        <div class="chip">Pick a date</div></div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),

  dict(name="Already stopped", body="""
    <div class="body">
      <div class="h sm">When was your last one?</div>
      <div class="sub">If you've already stopped, we'll count from then. You shouldn't lose days
      you've already done.</div>
      <div class="cta out" style="margin-top:16px">Just had one, start now</div>
      <div class="or">OR</div>
      <div class="chips"><div class="chip on">Earlier today</div><div class="chip">Yesterday</div>
        <div class="chip">Pick a date</div><div class="chip">Starting Monday</div></div>
    </div>""", foot='<div class="cta">Continue</div><div class="back">Back</div>'),
]))

S.append(dict(step="8 · Reminders", note="new: asked in context", prog=7, variants=[
  dict(name="Named", body="""
    <div class="body">
      <div class="h sm">Stay on track</div>
      <div class="sub">The hard days are the ones you don't see coming.<br><br>
      We'll tell you the moment your body hits a milestone, and check in on the mornings that
      matter, <b>with Emma's name on it</b>, because that's what you said this was for.</div>
      <div class="note">Three a week at most. Never a guilt trip.</div>
    </div>""",
    foot='<div class="cta">Turn on reminders</div><div class="cta ghost">Maybe later</div>'),

  dict(name="What you'll get", body="""
    <div class="body">
      <div class="h sm">Want us to check in?</div>
      <div class="sub">Three kinds, and you can turn any of them off later:</div>
      <div class="bullet"><b></b><div><div class="bt">The moment a milestone lands</div>
        <div class="bd">"Your heart rate is back to normal", 20 minutes in</div></div></div>
      <div class="bullet"><b></b><div><div class="bt">Sunday's receipt</div>
        <div class="bd">What the week didn't cost you</div></div></div>
      <div class="bullet"><b></b><div><div class="bt">A morning nudge, if you want one</div>
        <div class="bd">Off by default</div></div></div>
    </div>""",
    foot='<div class="cta">Turn on reminders</div><div class="cta ghost">Maybe later</div>'),

  dict(name="Hardest days", body="""
    <div class="body">
      <div class="h sm">Day two and day three</div>
      <div class="sub">Statistically the worst of it. Most people who go back do it in the first
      week, usually somewhere they didn't expect.<br><br>
      Let us put something on your lock screen on those mornings.</div>
      <div class="note">Three a week at most, and Emma's name on the ones that matter.</div>
    </div>""",
    foot='<div class="cta">Turn on reminders</div><div class="cta ghost">Maybe later</div>'),
]))

S.append(dict(step="9 · Building", note="new: ~1.5s, and it is real work", prog=7, variants=[
  dict(name="Checklist", body="""
    <div class="body mid">
      <div class="h sm">Building your plan</div>
      <div class="load">
        <div class="li done"><b></b>Working out what this costs you</div>
        <div class="li done"><b></b>Mapping your 18 milestones</div>
        <div class="li"><b></b>Setting up the first three days</div>
      </div>
    </div>""", foot=''),

  dict(name="Just the mark", body="""
    <div class="body mid" style="align-items:center;text-align:center">
      <div class="dots" data-mark="58" style="width:58px;height:58px;margin:0 auto 20px"></div>
      <div class="h sm" style="text-align:center">Building your plan</div>
      <div class="sub" style="text-align:center">One moment.</div>
    </div>""", foot=''),
]))

S.append(dict(step="10 · Ready", note="new: the payoff", prog=7, variants=[
  dict(name="Money first", body="""
    <div class="body mid">
      <div class="sub" style="margin-top:0">Your plan is ready.</div>
      <div class="big">€1,560</div>
      <div class="sub" style="margin-top:2px">a year, staying in your pocket.</div>
      <div class="statline"><span>Milestones ahead</span><span>18</span></div>
      <div class="statline"><span>First one</span><span>20 minutes</span></div>
      <div class="statline"><span>Hardest stretch</span><span>days 1–3</span></div>
      <div class="sub" style="margin-top:14px">Emma's the reason. We'll remind you.</div>
    </div>""", foot='<div class="cta">Start day one</div>'),

  dict(name="Time first", body="""
    <div class="body mid">
      <div class="sub" style="margin-top:0">Your plan is ready.</div>
      <div class="big">20 minutes</div>
      <div class="sub" style="margin-top:2px">until your heart rate starts coming down.</div>
      <div class="statline"><span>Then</span><span>12 hours</span></div>
      <div class="statline"><span>Nicotine gone</span><span>3 days</span></div>
      <div class="statline"><span>A year of vaping</span><span>€1,560</span></div>
      <div class="sub" style="margin-top:14px">Emma's the reason. We'll remind you.</div>
    </div>""", foot='<div class="cta">Start day one</div>'),
]))

HEAD = """<meta charset="utf-8">
<title>Exhale onboarding options</title>
<style>
""" + fonts + """
  :root{
    --bg:#081A1D; --fg:#E9F5F3; --muted:rgba(233,245,243,.58);
    --faint:rgba(233,245,243,.40); --accent:#7FD8CB; --on:#06181B;
    --ember:#E8743B; --emberSoft:#E8A87F;
    --card:rgba(233,245,243,.14); --hair:rgba(233,245,243,.08); --ground:#0A1012;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--ground);color:var(--fg);
       font-family:'SG',ui-sans-serif,system-ui,sans-serif;padding:26px 26px 90px}
  h1{font-size:19px;margin:0 0 6px;letter-spacing:-.01em}
  .lede{font-size:13px;line-height:1.6;color:rgba(233,245,243,.62);max-width:80ch;margin:0 0 24px}
  .lede b{color:var(--fg)}
  .rail{display:flex;gap:20px;flex-wrap:wrap;align-items:flex-start}
  .wrap{width:266px}
  .step{font:600 10.5px ui-monospace,Menlo,monospace;color:var(--accent);letter-spacing:.05em}
  .step span{color:var(--faint);font-weight:400}
  .picks{display:flex;gap:4px;flex-wrap:wrap;margin:6px 0 8px;min-height:22px}
  .pick{font:inherit;font-size:9.6px;background:none;color:var(--muted);cursor:pointer;
        border:1px solid var(--card);border-radius:999px;padding:3px 8px}
  .pick:hover{color:var(--fg)}
  .pick.on{background:var(--accent);color:var(--on);border-color:transparent;font-weight:700}
  .pick:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
  .phone{width:266px;height:582px;background:var(--bg);border-radius:32px;position:relative;
         overflow:hidden;display:flex;flex-direction:column;padding:0 17px 20px;
         box-shadow:0 12px 44px rgba(0,0,0,.55)}
  .island{position:absolute;top:7px;left:50%;transform:translateX(-50%);
          width:84px;height:25px;border-radius:16px;background:#000;z-index:5}
  .status{height:32px;flex:none;display:flex;align-items:center;justify-content:space-between;
          padding:0 5px;font-size:9.5px;font-weight:500;opacity:.9}
  .hdr{display:flex;align-items:center;justify-content:space-between;flex:none;padding-top:2px}
  .mark{display:flex;align-items:center;gap:6px}
  .dots{position:relative;flex:none}
  .word{font-weight:700;letter-spacing:.22em;font-size:8.6px;color:var(--accent)}
  .prog{display:flex;gap:4px}
  .prog i{width:13px;height:2.6px;border-radius:2px;background:rgba(233,245,243,.15)}
  .prog i.on{background:var(--accent)}
  .body{flex:1;min-height:0;overflow:hidden;padding-top:18px;display:flex;flex-direction:column}
  .body.mid{justify-content:center;padding-bottom:18px}
  .h{font-size:24px;font-weight:700;line-height:1.14;letter-spacing:-.3px}
  .h.sm{font-size:19.5px;line-height:1.2}
  .sub{font-size:11.5px;line-height:1.55;color:var(--muted);margin-top:10px}
  .sub b{color:var(--fg);font-weight:500}
  .row{display:flex;align-items:center;gap:9px;padding:10px 12px;border-radius:13px;
       border:1.1px solid var(--card);margin-top:7px}
  .row.sel{border-color:var(--accent);background:rgba(127,216,203,.10)}
  .rt{font-size:11.6px;font-weight:700}
  .rs{font-size:8.8px;color:var(--muted);margin-top:1px}
  .ring{width:14px;height:14px;border-radius:50%;border:1.5px solid rgba(233,245,243,.30);flex:none}
  .ring.on{border-color:var(--accent);background:var(--accent)}
  .badge{font-size:6.4px;font-weight:700;letter-spacing:.09em;background:var(--accent);
         color:var(--on);border-radius:9px;padding:3px 5px}
  .cta{height:43px;border-radius:22px;background:var(--accent);color:var(--on);display:flex;
       align-items:center;justify-content:center;font-size:12.6px;font-weight:700}
  .cta.ghost{background:none;color:var(--muted);font-weight:500;height:36px}
  .cta.out{background:none;border:1.2px solid rgba(233,245,243,.26);color:var(--fg);font-weight:600}
  .foot{display:flex;flex-direction:column;gap:1px;flex:none}
  .back{font-size:10px;color:var(--muted);padding:5px;text-align:center}
  .sos{height:40px;border-radius:20px;margin-top:14px;display:flex;align-items:center;
       justify-content:center;font-size:11.5px;color:var(--emberSoft);
       background:rgba(232,116,59,.12);border:1.1px solid rgba(232,116,59,.62)}
  .slip{height:36px;border-radius:18px;margin-top:14px;display:flex;align-items:center;
        justify-content:center;font-size:11px;color:var(--muted);
        border:1.1px solid rgba(233,245,243,.20)}
  .stepper{display:flex;align-items:center;justify-content:center;gap:17px;margin-top:22px}
  .circ{width:38px;height:38px;border-radius:50%;border:1.1px solid rgba(233,245,243,.30);
        display:flex;align-items:center;justify-content:center;font-size:17px;color:var(--accent)}
  .num{font-size:42px;font-weight:700;line-height:1;font-variant-numeric:tabular-nums;text-align:center}
  .unit{font-size:8.4px;letter-spacing:.09em;color:var(--muted);margin-top:5px;text-align:center}
  .price{font-size:26px;font-weight:700;text-align:center;
         border-bottom:1.1px solid rgba(233,245,243,.16);padding-bottom:5px;width:132px;margin:0 auto}
  .burn{text-align:center;margin-top:14px}
  .burnm{font-size:9px;color:var(--muted)}
  .burny{font-size:24px;font-weight:700;color:var(--emberSoft);margin-top:3px}
  .burnl{font-size:9px;color:var(--muted);margin-top:2px}
  .field{border:1.1px solid var(--card);border-radius:12px;padding:9px 12px;margin-top:7px;
         font-size:10.2px;color:var(--faint)}
  .chips{display:flex;gap:5px;margin-top:8px;flex-wrap:wrap}
  .chip{border:1.1px solid var(--card);border-radius:10px;padding:6px 9px;font-size:9.4px}
  .chip.on{background:var(--accent);border-color:transparent;color:var(--on);font-weight:700}
  .or{font-size:8.2px;letter-spacing:.18em;color:var(--faint);text-align:center;margin-top:13px}
  .quote{font-size:13.4px;line-height:1.5;font-weight:500}
  .quote em{font-style:normal;color:var(--accent)}
  .note{font-size:10.4px;color:var(--muted);line-height:1.5;margin-top:12px;
        border-left:2px solid rgba(127,216,203,.35);padding-left:9px}
  .bullet{display:flex;gap:8px;align-items:flex-start;margin-top:11px}
  .bullet b{display:block;width:5px;height:5px;border-radius:50%;background:var(--accent);
            margin-top:5px;flex:none}
  .bt{font-size:11px;font-weight:700}
  .bd{font-size:9.4px;color:var(--muted);margin-top:1px;line-height:1.4}
  .load{display:flex;flex-direction:column;gap:9px;margin-top:20px}
  .li{display:flex;align-items:center;gap:9px;font-size:11px;color:var(--muted)}
  .li b{display:block;width:13px;height:13px;border-radius:50%;flex:none;
        border:1.4px solid rgba(233,245,243,.22)}
  .li.done b{background:var(--accent);border-color:transparent}
  .li.done{color:var(--fg)}
  .big{font-size:33px;font-weight:700;color:var(--accent);line-height:1.1;margin-top:4px}
  .statline{display:flex;justify-content:space-between;border-top:1px solid var(--hair);
            padding-top:8px;margin-top:8px;font-size:10.4px;color:var(--muted)}
  .statline span:last-child{font-weight:700;color:var(--fg)}
</style>
"""

page = HEAD + """
<h1>Exhale onboarding options</h1>
<p class="lede">Every screen with its alternatives. <b>Click the chips above each phone</b> to swap
copy, the same way the animation variants worked. Real Space Grotesk, real tokens, real numbers.
Two new beats since last time: <b>cravings are normal and there is a button for them</b>, and
<b>slipping happens, doesn't erase anything, and is handled in the app</b>. Those two are what
quietly ends most quits, so they are said out loud before day one rather than discovered later.</p>
<div class="rail" id="rail"></div>
<script>
const SCREENS = """ + json.dumps(S) + """;
const GOLD = 2.399963;

function markInto(el){
  const box = parseFloat(el.dataset.mark || 18);
  const n = 55, sc = box/26, c = 13*sc, hole = 3.1*sc, maxR = 12.4*sc, d = 1.85*sc;
  let h = '';
  for (let i = 0; i < n; i++){
    const t = i/(n-1), r = hole + (maxR-hole)*Math.sqrt(t), a = i*GOLD - 1.6;
    h += `<div style="position:absolute;left:${(c+r*Math.cos(a)-d/2).toFixed(2)}px;`
      +  `top:${(c+r*Math.sin(a)-d/2).toFixed(2)}px;width:${d.toFixed(2)}px;`
      +  `height:${d.toFixed(2)}px;border-radius:50%;`
      +  `background:hsl(${Math.round(18+t*154)} ${Math.round(85-t*25)}% ${Math.round(54+t*8)}%)"></div>`;
  }
  el.style.width = box + 'px'; el.style.height = box + 'px';
  el.innerHTML = h;
}

const rail = document.getElementById('rail');
SCREENS.forEach((s, si) => {
  const wrap = document.createElement('div');
  wrap.className = 'wrap';
  const picks = s.variants.length > 1
    ? s.variants.map((v, i) =>
        `<button class="pick${i === 0 ? ' on' : ''}" data-s="${si}" data-v="${i}">${v.name}</button>`
      ).join('')
    : '';
  wrap.innerHTML = `<div class="step">${s.step} <span>${s.note}</span></div>
    <div class="picks">${picks}</div>
    <div class="phone" id="ph${si}"></div>`;
  rail.appendChild(wrap);
  render(si, 0);
});

function render(si, vi){
  const s = SCREENS[si], v = s.variants[vi];
  const bar = s.prog === null ? '' :
    '<div class="hdr"><div class="mark"><div class="dots" data-mark="18"></div>' +
    '<div class="word">EXHALE</div></div><div class="prog">' +
    [...Array(8)].map((_, i) => `<i class="${i <= s.prog ? 'on' : ''}"></i>`).join('') +
    '</div></div>';
  const ph = document.getElementById('ph' + si);
  ph.innerHTML = '<div class="island"></div>' +
    '<div class="status"><span>9:41</span><span>▮▮▮ ᯤ 100%</span></div>' +
    bar + v.body + `<div class="foot">${v.foot}</div>`;
  ph.querySelectorAll('.dots').forEach(markInto);
}

rail.addEventListener('click', e => {
  const b = e.target.closest('.pick');
  if (!b) return;
  const si = +b.dataset.s, vi = +b.dataset.v;
  b.parentNode.querySelectorAll('.pick').forEach(x => x.classList.remove('on'));
  b.classList.add('on');
  render(si, vi);
});
</script>
"""

pathlib.Path("tools/preview/onboarding-v2.html").write_text(page, encoding="utf-8")
print(f"wrote tools/preview/onboarding-v2.html  {len(page)/1024:.0f} KB")
print(f"screens: {len(S)}   variants: {sum(len(s['variants']) for s in S)}")
