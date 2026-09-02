# I wrote a tool to measure my Claude Code usage. The first thing it found was a bug in itself.

And then a real result: **cost scales with conversation *length*, at r=0.987 — not with what
you do in the conversation.**

---

Deep into a long agent session I asked how much it had cost. Nobody knew. So I guessed: the
session had taken 48 screenshots, images are expensive, everyone knows that. I spent an hour
building tooling to downscale and crop them.

Then I measured. The screenshots were 58k tokens. Seventy-five `Read` calls, mostly whole
files where I needed four lines, were **1.3 million.** 22× the thing I had just optimised.

So I pointed the script at every transcript on disk — 43 sessions, 93 days — and got a number.
Then I tried to check the number, and that is where this gets interesting.

## The bug

Claude Code writes its own cost figure, `totalCostUSD`, into the transcript. Exactly one of my
43 sessions has it (I am on a subscription, so there is usually no per-token cost to record).
One ground-truth data point. I checked my script against it:

```
Claude Code's own figure:                $3.20
  my script, summing usage records:      $4.23    1.33x too high
  after deduplicating by message id:     $1.11    2.9x too LOW
```

Streaming writes each chunk of a message into the transcript with the same message id and
*cumulative* usage. Summing every record double-counts: **54% of the cache-read tokens my
script counted were duplicates.** But naively deduplicating by taking the max per id
overshoots the other way, and I do not yet know why.

So I have two methods, both wrong, and one calibration point. **I am not publishing a dollar
figure.** If you have run something like this and know the right reconciliation, I would like
to hear it — that is half of why this post exists.

## What survives

The token counts come from the API's own `usage` records, and the structural findings are
stable under both methods:

```
                          naive     deduped
r(messages, cache reads)  0.999       0.987
top 5 of 43 sessions        58%         56%   of all cache reads
```

**Cost scales with conversation length, almost perfectly, and superlinearly.** Across 43
sessions doing completely different work — Rust, Flutter, market research, refactoring — what
a session consumed was predicted almost entirely by how many messages it ran for. Five
sessions account for well over half of everything.

## Why

Every turn re-reads the accumulating context. My largest session: 5,663 messages, billions of
cache-read tokens against 13.5M output tokens.

The cost of turn *n* is roughly proportional to everything in turns 1 through n−1. You are not
paying for what you asked. You are paying, repeatedly, for everything you already asked.

That is also why the things I instinctively optimised are rounding errors. In one session, all
tool results combined came to 43.5k tokens against 101.3M cache reads — optimising tool output
would have moved 0.04% of it.

The lever I never thought of as a lever: **when to start a new session.** A fresh session
resets the accumulation. Two 300-message sessions cost dramatically less than one 600-message
session doing the same work.

## The tool

`cato` — Python 3, standard library only. No API key, no telemetry, no network. It reads the
transcripts already on your disk and does arithmetic.

```bash
cato              # this project, every session
cato -c -b        # current session + which tool ate what
cato -a --cost    # every project (see the caveat above about --cost)
```

MIT. https://github.com/SharminSirajudeen/cato

**Known bugs, since I just found them:** `--cost` double-counts streamed messages and prices
every session at one model's rates regardless of which model ran. Both are being fixed. The
token counts and the per-tool breakdown are unaffected.

## Caveats

- n = 43 sessions, one developer, one workflow. The r=0.987 is real for my data. I have no
  idea whether it holds for yours — which is why I am shipping the script and not the
  conclusion.
- The 22× screenshot finding is a single session, n=1.
- Tool-level token counts are estimated from result bytes; session totals are exact.

Run it on your own transcripts. I would like to know whether the correlation holds, and I
would very much like to know how to reconcile that $3.20.
