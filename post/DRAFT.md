# I pay $200/month for Claude Code. In 93 days I used $15,177 of API-equivalent compute.

That is 25×. I only know because I wrote 180 lines of Python to look.

---

Deep into a long agent session I asked the obvious question: how much did that cost?

Nobody knew. So I guessed. The session had taken 48 device screenshots — images are
expensive, everyone knows that — and I spent the next hour building tooling to downscale
and crop them.

Then I wrote a script to actually look. The screenshots were 58k tokens. Seventy-five
`Read` calls, mostly whole files where I needed four lines, were **1.3 million.** Twenty-two
times the thing I had just spent an hour optimising.

That was the first surprise. There were two bigger ones.

## Surprise 1: the subscription is doing more than I thought

I pointed the script at every transcript on disk. 43 sessions, 93 days.

```
month     sessions   API-equivalent   vs $200/mo
2026-06          1             $716          4x
2026-07          5           $7,749         39x
2026-08         35           $6,675         33x
---------------------------------------------
93 days         43          $15,177         25x
```

Priced at published Opus 5 rates. I am on a flat subscription, so this is not my bill — it
is what the same usage would cost through the API. In July I used **39× the subscription
price** in compute.

If you are on a subscription and have never measured this, you are probably in the same
position and have no idea.

## Surprise 2: cost is a function of conversation *length*, not of what you do

```
Pearson r (message count vs session cost) = 0.989
```

Across 43 sessions doing completely different work — Rust, Flutter, market research,
refactoring — what a session cost was almost entirely predicted by how many messages it ran
for. That is not "correlated." That is nearly a straight line.

And it is superlinear:

```
cost per message, 20 cheapest sessions:  $0.147
cost per message, 5 most expensive:      $0.402
```

Nearly 3× more per message in a long session, doing nothing different.

Spend is also brutally concentrated. Five sessions are **58%** of the total; ten are 81%.
The median session is $53. The largest is $2,521.

## Why

Every turn re-reads the accumulating context. My most expensive session: 5,663 messages and
**2.8 billion cache-read tokens** against 13.5M output tokens — **207×**.

Cache reads are cheap per token (10% of input rate). They are not cheap at 2.8 billion.

The cost of turn *n* is roughly proportional to everything in turns 1 through n−1. You are
not paying for what you asked. You are paying, repeatedly, for everything you already asked.

## What this changes

The things I instinctively optimised — screenshot sizes, verbose tool output, trimming
`Bash` results — are rounding errors. In one session I measured, all tool results combined
came to **43.5k tokens** against **101.3M cache reads.** Optimising tool output would have
moved 0.04% of the bill.

The lever I never thought of as a lever: **when to start a new session.** A fresh session
resets the accumulation. Two 300-message sessions cost dramatically less than one
600-message session doing the same work.

You cannot fix this by being careful about what you send. You fix it by looking, and by not
letting one conversation run forever.

## The tool

`cato` — 180 lines of Python 3, standard library only. No API key, no telemetry, no network.
It reads the transcripts already on your disk and does arithmetic.

```bash
cato              # this project, every session
cato -c -b        # current session + which tool ate what
cato -a --cost    # every project, in dollars
```

MIT. https://github.com/SharminSirajudeen/cato

## Caveats

- **The dollar figures are API-equivalent, not billed.** Priced at Opus 5 rates ($5/$25 per
  MTok; cache write 1.25×, cache read 0.1×). On a subscription you pay the subscription.
  Read it as "what this usage is worth."
- The model mix is ~93% Opus-tier, so a single Opus price is a fair approximation here. If
  your usage is mostly Sonnet, the script will overstate it — it does not yet price per
  model. That is the first thing I would fix.
- **n = 43 sessions, one developer, one workflow.** The r=0.989 is real for my data. I have
  no idea whether it holds for yours — which is why I am shipping the script rather than the
  conclusion.
- The 22× screenshot finding is a single session, n=1.
- Tool-level token counts are estimated from result bytes; session totals are the exact
  numbers Claude Code writes to its own transcripts.

Run it on your own transcripts. I would genuinely like to know if the correlation holds.
