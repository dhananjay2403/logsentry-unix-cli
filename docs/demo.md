# Recording the demo GIF

A 25-second terminal recording shows more than the screenshot grid does: the analysis, the JSON
output, and the exit code that makes the tool usable in CI. This file has the exact commands.

## Tools

```bash
brew install asciinema agg      # macOS
# Linux: pipx install asciinema && cargo install --git https://github.com/asciinema/agg
```

`asciinema` records the terminal as a small text cast file; `agg` converts that cast into a GIF.
Recording text rather than pixels is why the result is a few hundred KB instead of tens of MB.

## Before recording

```bash
cd /path/to/logsentry-unix-cli
./scripts/generate_demo_logs.sh /tmp/demo-logs   # realistic multi-service data
rm -rf /tmp/demo-out && mkdir -p /tmp/demo-out
export REPORT_DIR=/tmp/demo-out/reports BACKUP_ROOT=/tmp/demo-out/backups
export PS1='$ '                                  # a clean, short prompt
clear
```

Use a window around **90×24**. Anything wider renders as unreadably small text in a README.

## Record

```bash
asciinema rec docs/demo.cast --cols 90 --rows 24 --idle-time-limit 1.5
```

`--idle-time-limit 1.5` compresses your thinking pauses to 1.5 s, so you do not need to type fast.

Then run exactly these six commands, pausing about a second between them:

```bash
logsentry /tmp/demo-logs/microservices_sim

logsentry -t 3 /tmp/demo-logs/microservices_sim

logsentry --json /tmp/demo-logs/microservices_sim | jq '{files, errors, warnings}'

logsentry -q --fail-on-error 5 /tmp/demo-logs/microservices_sim; echo "exit: $?"

logsentry --keep 3 /tmp/demo-logs/microservices_sim

exit
```

That sequence tells a story in order: it works → it ranks what matters → it speaks JSON → it fails
a build on a threshold → it cleans up after itself.

## Convert to a GIF

```bash
agg --cols 90 --rows 24 --font-size 16 --speed 1.2 docs/demo.cast docs/demo.gif
ls -lh docs/demo.gif        # aim for under 2 MB
```

If it comes out too large, re-run `agg` with `--font-size 14`, or trim dead air by re-recording
with `--idle-time-limit 1.0`.

## Add it to the README

Once `docs/demo.gif` exists, paste this directly under the `## Overview` heading:

```markdown
<p align="center">
  <img src="docs/demo.gif" alt="LogSentry demo" width="100%" />
</p>
```

It is deliberately not in the README already — a missing image renders as a broken-image icon on
GitHub, which looks worse than having no demo at all.

Commit both files (`docs/demo.cast` is worth keeping; it is small and lets you regenerate the GIF
with different settings without re-recording).
