# Kite : Studio checklist

`--> ["the order"]`

Do these in order. Each one assumes the last one passed.

## 1) put the package in place

```text
ReplicatedStorage/
  Packages/
    Kite/          <- the Kite folder from Releases/Kite 0.1.0.rbxmx
                      or from the repository
```

Play in Studio. Nothing should print yet, because nothing is mounted.

## 2) reactivity

Drop `Validation/ReactivityValidation.client.luau` into
`StarterPlayerScripts` as a LocalScript. Play.

Expected: `[Kite] reactivity validation · 18 passed · 0 failed`

## 3) mount

Drop `Validation/MountValidation.client.luau` in. Play.

Expected: `[Kite] mount validation · 26 passed · 0 failed`

If a row name check fails, check that the list has a `UIListLayout`.

## 4) lint

Drop `Validation/LintValidation.client.luau` in. Play.

Expected: `[Kite] lint validation · 24 passed · 0 failed`

Read the strict output while you are there. It is the same voice you get when
you make a mistake for real.

## 5) profiler and motion

Drop `Validation/ProfilerValidation.client.luau` in. Play.

Expected: `[Kite] profiler validation · 27 passed · 0 failed`

This one waits about three seconds for motion to settle. That is on purpose.

## 6) the examples

- `Examples/Counter.client.luau` — read this one first
- `Examples/Boot.client.luau` — the workflow in one file
- `Examples/CommandBar.client.luau` — press **Quote**, try Tab and ↑↓
- `Examples/Inventory.client.luau` — press **shuffle** and watch the rows keep
  their own state

## 7) the benchmarks

`Examples/Benchmarks/BenchmarksVSvide.client.luau`. Play, read the output.

Do not trust the milliseconds. Trust the ratios.

---

`--> ["if something fails"]`

- **unknown property errors on a class Kite should know**
  teach it once: `Kite.know("ShinyFrame", "Frame", { Glow = "number" })`
- **a strict report you do not agree with**
  run the same tree through `Kite.creative` and compare. Strict refuses sugar
  on purpose
- **a binding that never fires**
  check that you are reading the source inside the function. `Text = count`
  works, `Text = count()` writes the value once and stops
- **a list that rebuilds rows on every change**
  you forgot the key function. `Kite.keys(source, render, function(item)
  return item.id end)`
- **motion that never settles**
  the motion is owned by a scope that died, or the precision is too tight for
  the values you are moving

---

`--> ["headless, before Studio"]`

```bash
python3 build.py --luau
luau Tests/run.luau
./tools/analyze.sh
```

95 assertions. If this is green and Studio is not, it is the engine, not the
package.
