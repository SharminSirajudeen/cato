# cato

**The censor for your agent's spending.**

*He disapproves of your extravagance. He has prepared an itemised list.*

---

Cato the Elder held the office of Censor. He audited what Romans owned, taxed luxury at
ten times its assessed value, expelled a senator for kissing his wife in daylight, and
ended every speech — on any topic, however unrelated — with the same sentence.

This tool does the same for your Claude Code sessions. Locally. No API key, no telemetry,
no network: it reads the transcripts already on your disk and does arithmetic.

## The hour we wasted

Deep into a long agent session we asked the obvious question — *how much did that cost?*

Nobody knew. So we guessed.

The session had taken 48 device screenshots. Images are expensive; everyone knows that.
We spent the next hour building tooling to downscale and crop them.

Then we measured:

```
$ cato -c -b

tool                    calls  result bytes   ~tokens
Read                       75          4.7M      1.3M      ← the actual problem
Bash                      325        221.9k     61.6k
WebFetch                   22         29.8k       8.3k
Edit                       86         18.6k       5.2k

images embedded: 48   ~57.7k tokens                        ← what we "fixed"

Ceterum censeo Read esse delendam.
```

**Twenty-two times.** The screenshots we optimised: 58k tokens. Seventy-five `Read`
calls — mostly whole files where we needed four lines: 1.3M.

Agent cost intuition fails in a predictable direction. You notice what *looks* heavy
(images, long outputs) and miss what quietly dominates: a 60KB file pulled into context
once, then re-read from cache on every turn thereafter.

You cannot fix this by being careful. You fix it by looking.

## The census

```bash
cato              # this project, every session
cato -c           # current session
cato -c -b        # + which tool ate what
cato -a --cost    # every project, in denarii
```

```
session        when         msgs      in     out  cache_w  cache_r
1168c488-8f3   08-10 17:33  1155    2.1k    1.3M    12.2M   539.8M
--------------------------------------------------------------
TOTAL                       1155    2.1k    1.3M    12.2M   539.8M
billed units: 557.0M   (cache reads are the cheap bulk)
```

Every run closes the way Cato closed every speech — naming whichever tool cost you most,
whether or not you asked.

## The censor in your status line, free

```
✦ Sharmin's APEX · Opus 5 · checkout · ⎇ main · 1.3M out · $385
```

**This costs zero conversation tokens.** Status lines execute in the harness — the model
never sees the output, so measuring your spend does not add to it.

It is also incremental: a byte offset is cached per transcript, so each render parses only
newly-appended lines. **0.19s on a 1155-message transcript**, including bash startup.

```json
{ "statusLine": { "type": "command", "command": "$HOME/bin/cato-status" } }
```

Already have a status line? Splice it in:

```bash
tokens=$(printf '%s' "$input" | "$HOME/bin/cato-status" 2>/dev/null)
```

It reports Claude Code's own `total_cost_usd` when available — authoritative, not an
estimate.

## imago — cheaper likenesses

Romans kept *imagines*, wax portrait masks of their ancestors. You keep screenshots. Yours
should cost less.

```bash
$ imago screen.png
screen.png  360x640  ~307 tokens
```

```bash
imago out.png                      # 50% scale   ~4x cheaper
imago out.png 35                   # 35% scale   ~8x cheaper
imago out.png 100 0,900,720,380    # crop x,y,w,h — best when you know the region
```

Image cost scales with **pixel area** (`w × h / 750`), so halving each dimension quarters
the price: a 720×1280 device capture drops from ~1229 tokens to ~307. Cropping beats
scaling when you know where to look.

Nothing makes an image cheaper once it is in context. The only levers are fewer pixels, or
no image at all. (File size tells you nothing — PNG is compressed. `cato` decodes the IHDR
header for true dimensions.)

## Install

```bash
git clone https://github.com/SharminSirajudeen/cato
cd cato && ./install.sh
```

Python 3, stdlib only. `imago` also uses `adb` and `sips` (macOS built-in).

Uninstall — Cato would approve of the thoroughness:

```bash
rm ~/bin/{cato,cato-status,imago} && rm -rf /tmp/.cato-status
# then drop the statusLine key from ~/.claude/settings.json
```

## What the numbers taught us

- **Whole-file reads dominate.** Read once, pay forever: the content stays in context and
  is re-read from cache every subsequent turn. `Read` with `offset`/`limit`, or `grep`, is
  almost always what you meant.
- **Cache reads are most of the units and the cheapest per unit.** Do not panic at 500M.
  Look at `out` and `cache_w`.
- **Images are rarely the problem.** They feel expensive. They mostly are not.

### On our numbers

One session. 1155 messages. A long Android/API debugging run, heavy on file reading.

That is n=1, and your sessions will differ — research-heavy work skews toward `WebFetch`,
writing-heavy work toward `out`. We are not claiming 22× is universal. We are claiming you
do not know your own ratio until you measure it, and that measuring takes one command.

## FAQ

**Does this send anything anywhere?**
No. `cato` reads `~/.claude/projects/`, `cato-status` reads the transcript path Claude Code
hands it on stdin, `imago` talks to `adb` and `sips`. There are no network calls in the
codebase.

**Does running it cost tokens?**
`cato` costs whatever its dozen lines of output cost, if an agent runs it. `cato-status`
costs nothing — status lines never enter the conversation.

**Why is `cache_r` so enormous?**
Every turn re-reads accumulated context. It is the cheapest per-unit rate and it is
expected. `out` and `cache_w` are where growth hurts.

**Do the dollar figures match my bill?**
`cato-status` uses Claude Code's own `total_cost_usd` when present. `cato` estimates from
token counts — edit `PRICE` at the top of `bin/cato` for your plan.

**Will he ever stop saying that?**
No.

**Other agent CLIs?**
Today it parses Claude Code's JSONL. The transcript reader is ~30 lines; PRs for other
formats welcome.

## License

MIT — see [LICENSE](LICENSE).

---

Built by the team behind **[Drengr](https://github.com/SharminSirajudeen)** — eyes and
hands for AI agents on real mobile devices. cato exists because we were instrumenting our
own agent runs and could not answer a basic question. If you are building agents that
drive real hardware, Drengr is the part that drives the device.
