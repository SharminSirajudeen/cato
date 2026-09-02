# I measured 43 Claude Code sessions. Cost correlates with conversation *length* at r=0.989.

Not with what I did in them. Not with screenshots. With length.

---

Deep into a long agent session I asked the obvious question: how much did that cost?

Nobody knew. So I guessed. The session had taken 48 device screenshots — images are
expensive, everyone knows that — and I spent the next hour building tooling to downscale
and crop them.

Then I wrote a 180-line script to actually look, and it told me the screenshots were 58k
tokens. Seventy-five `Read` calls, mostly whole files where I needed four lines, were
**1.3 million.** Twenty-two times the thing I'd just spent an hour optimising.

That was the first surprise. The second one was bigger.

## The distribution

I pointed the same script at every transcript on my disk — 43 sessions, ~5 months.

```
sessions: 43        API-equivalent total: $15,156
  top  1 session  = $2,521  (16.6%)
  top  5 sessions = $8,744  (57.7%)
  top 10 sessions = $12,279 (81.0%)
  median session  = $52.69
```

Five sessions are **58% of the spend.** The median session is $53 and the largest is $2,521.

## The correlation

```
Pearson r (message count vs cost) = 0.989
```

That is not "related." That is nearly a straight line. Across 43 sessions doing wildly
different work — Rust, Flutter, market research, refactoring — what a session *cost* was
almost entirely predicted by how many messages it ran for.

And it is **superlinear**:

```
cost per message, 20 cheapest sessions:  $0.147
cost per message, 5 most expensive:      $0.402
```

Nearly 3× more per message in a long session, doing nothing different.

## Why

Every turn re-reads the accumulating context. My most expensive session: 5,663 messages
and **2.8 billion cache-read tokens**. The output was 13.5M tokens — cache reads were
**207× that.**

Cache reads are cheap per token (10% of input rate). They are not cheap at 2.8 billion.

So the cost of turn *n* is roughly proportional to everything that happened in turns 1
through n−1. You are not paying for what you asked. You are paying, repeatedly, for
everything you already asked.

## What this changes

The things I instinctively optimised — screenshot sizes, verbose tool output, trimming
`Bash` results — are rounding errors. In this very session, all tool results combined came
to **43.5k tokens** against **101.3M cache reads.** Optimising the tool output would have
moved 0.04% of the bill.

The lever that actually matters is one I never thought of as a lever: **when to start a
new session.** A fresh session resets the quadratic. Two 300-message sessions cost
dramatically less than one 600-message session doing the same work.

You cannot fix this by being careful about what you send. You fix it by looking at where
the money is, and by not letting one conversation run forever.

## The tool

`cato` — 180 lines of Python 3, standard library only. No API key, no telemetry, no
network. It reads the transcripts already on your disk and does arithmetic.

```bash
cato              # this project, every session
cato -c -b        # current session + which tool ate what
cato -a --cost    # every project, in dollars
```

MIT. https://github.com/SharminSirajudeen/cato

## Caveats, because they matter

- **`$15,156` is an API-equivalent cost, not my bill.** The script prices tokens at
  published Opus 5 rates ($5/$25 per MTok, cache write 1.25×, cache read 0.1×). What you
  actually pay depends on your plan. Read it as "what this usage is worth," not "what I was
  charged."
- **n = 43 sessions, one developer, one workflow.** The r=0.989 is real for my data. I have
  no idea whether it holds for yours — which is the point of shipping the script rather
  than the conclusion.
- The 22× screenshot finding is a single session, n=1.
- Token counts are estimated from result bytes for the tool breakdown; the session totals
  are the exact numbers Claude Code writes to its own transcripts.

Run it on your own transcripts. I would genuinely like to know if the correlation holds.
