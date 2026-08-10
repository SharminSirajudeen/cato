# tokenscope

**You don't know what your agent just spent. Neither did we.**

*Local token accounting for Claude Code. No API key, no telemetry, no network — it reads
the transcripts already sitting on your disk and does arithmetic.*

---

## The hour we wasted

Deep into a long agent session, we asked the obvious question: *how much did that cost?*

Nobody knew. So we guessed.

The session had taken 48 device screenshots. Images are expensive — everyone knows that.
We spent the next hour building tooling to downscale and crop them.

Then we measured:

```
tool                    calls  result bytes   ~tokens
Read                       75          4.7M      1.3M      ← the actual problem
Bash                      317        217.5k     60.4k
WebFetch                   20         24.2k       6.7k
Edit                       86         18.6k       5.2k

images embedded: 48   ~57.7k tokens                        ← what we "fixed"
```

**Twenty-two times.** The screenshots we optimised were 58k tokens. Seventy-five
`Read` calls — mostly whole files where we needed four lines — were 1.3M.

Agent cost intuition fails in a specific direction: you notice what *looks* heavy
(images, long outputs) and miss what quietly dominates (a 60KB file pulled into context
once, then re-read from cache on every turn after).

You cannot fix this by being careful. You fix it by looking.

---

## The receipt

```bash
$ ctok -c -b

session        when         msgs      in     out  cache_w  cache_r
1168c488-8f3   08-10 17:33  1155    2.1k    1.3M    12.2M   539.8M
--------------------------------------------------------------
TOTAL                       1155    2.1k    1.3M    12.2M   539.8M
billed units: 557.0M   (cache reads are the cheap bulk)
```

Add `-b` for the per-tool breakdown above. Add `--cost` for dollars. Add `-a` for every
project on the machine.

## In your status line, for free

```
✦ Sharmin's APEX · Opus 5 · checkout · ⎇ main · 1.3M out · $385
```

**This costs zero conversation tokens.** Status lines execute in the harness — the model
never sees the output, so measuring your spend doesn't add to it.

It's also incremental: a byte offset is cached per transcript, so each render parses only
newly-appended lines. **0.19s on a 1155-message transcript**, including bash startup.

```json
{ "statusLine": { "type": "command", "command": "$HOME/bin/ctok-status" } }
```

Already have a status line? Splice it in:

```bash
tokens=$(printf '%s' "$input" | "$HOME/bin/ctok-status" 2>/dev/null)
```

It reports Claude Code's own `total_cost_usd` when available — that figure is
authoritative, not an estimate.

## Install

```bash
git clone https://github.com/SharminSirajudeen/tokenscope
cd tokenscope && ./install.sh
```

Python 3, stdlib only. `shot` additionally uses `adb` and `sips` (macOS built-in).

Uninstall: `rm ~/bin/{ctok,ctok-status,shot} && rm -rf /tmp/.ctok-status`, and drop the
`statusLine` key from `~/.claude/settings.json`.

## The three tools

| | |
|---|---|
| **`ctok`** | What did it cost, and which tool ate it |
| **`ctok-status`** | Live cost in your status line, free |
| **`shot`** | Screenshots that print their own price before you read them |

### `shot`

```bash
$ shot screen.png
screen.png  360x640  ~307 tokens
```

```bash
shot out.png                      # 50% scale   ~4x cheaper
shot out.png 35                   # 35% scale   ~8x cheaper
shot out.png 100 0,900,720,380    # crop x,y,w,h — best when you know the region
```

Image cost scales with **pixel area** (`w × h / 750`), so halving each dimension quarters
the price — a 720×1280 device capture drops from ~1229 tokens to ~307. Cropping beats
scaling when you know where to look.

There is no way to make an image cheaper once it's in context. The only levers are fewer
pixels, or no image at all. (File size tells you nothing — PNG is compressed. `ctok`
decodes the IHDR header for real dimensions.)

## What the numbers taught us

- **Whole-file reads dominate.** Read once, pay forever: the content stays in context and
  is re-read from cache every subsequent turn. `Read` with `offset`/`limit`, or `grep`, is
  almost always what you meant.
- **Cache reads are most of the units and the cheapest per unit.** Don't panic at 500M —
  look at `out` and `cache_w`.
- **Images are rarely the problem.** They feel expensive. They mostly aren't.

### On our numbers

One session. 1155 messages. A long Android/API debugging run with heavy file reading.

That is n=1, and the shape of your sessions will differ — a research-heavy session will
skew toward `WebFetch`, a writing-heavy one toward `out`. We're not claiming 22× is
universal. We're claiming you don't know your own ratio until you measure it, and that
the measurement takes one command.

## FAQ

**Does this send anything anywhere?**
No. `ctok` reads `~/.claude/projects/`, `ctok-status` reads the transcript path Claude
Code hands it on stdin, `shot` talks to `adb` and `sips`. No network calls exist in the
codebase.

**Does running it cost tokens?**
`ctok` costs whatever its ~12 lines of output cost if an agent runs it. `ctok-status`
costs nothing — status lines never enter the conversation.

**Why is `cache_r` so enormous?**
Every turn re-reads the accumulated context. It's the cheapest per-unit rate and it's
expected. `out` and `cache_w` are where growth actually hurts.

**Do the dollar figures match my bill?**
`ctok-status` uses Claude Code's own `total_cost_usd` when present. `ctok` estimates from
token counts — edit `PRICE` at the top of `bin/ctok` for your plan.

**Other agent CLIs?**
Today it parses Claude Code's JSONL format. The transcript reader is ~30 lines; PRs for
other formats welcome.

## License

MIT — see [LICENSE](LICENSE).

---

Built by the team behind **[Drengr](https://github.com/SharminSirajudeen)** — eyes and hands for AI agents
on real mobile devices. tokenscope exists because we were instrumenting our own agent
runs and couldn't answer a basic question. If you're building agents that drive real
hardware, Drengr is the part that drives the device.
