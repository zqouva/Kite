# Kite : Validation

`--> ["what this is"]`

Studio side validation. Each file is a LocalScript you drop into
StarterPlayerScripts and run once. They assert the package against the real
Roblox engine instead of the stub.

```text
Validation/
  ReactivityValidation.client.luau   reads, writes, derives, batches, scopes
  MountValidation.client.luau        trees, bindings, events, lists, destroy
  LintValidation.client.luau         the three modes, reports, teaching Kite
  ProfilerValidation.client.luau     counters, motion, inspector, help
  StudioChecklist.md                 the order to run them in
```

Each one prints `[Kite] <name> validation · N passed · M failed`, and errors
if anything failed, so a CI run or a tired human notices.

---

`--> ["what is covered"]`

Reactivity
- read and write through one call
- derives follow, and recompute only when they must
- a batch settles once, and no effect sees half a change
- an unchanged derive does not wake its effect
- untracked reads stay out of the graph
- a scope owns what it made, including nested effects
- records turn tables into sources

Mount
- properties, names, children, and ordering
- sources and derives bound straight to properties
- events connect and disconnect with the instance
- refs, attributes, and CollectionService tags
- keyed lists reuse rows, keep order, drop removed rows
- switch mounts and unmounts branches
- destroy takes the whole tree and leaves nothing behind

Lint
- strict: unknown properties, near misses, types, ranges, sugar, unkeyed lists
- creative: sugar accepted, types coerced, real breakage still caught
- performance: depth, cost, and correctness skipped
- reports render as text, json, and html
- `Kite.know` teaches the registry a class it has never met

Profiler and motion
- counters move when Kite works
- measure keeps the value and the timing
- four motions share one frame connection
- springs, tweens, damp, and clocks settle where they should
- UDim2 springs settle
- the inspector draws the tree, the graph, and graphviz
- help renders every topic, and suggests the right one

---

`--> ["headless"]`

The same ground is covered without Studio:

```bash
python3 build.py --luau
luau Tests/run.luau
```

95 assertions, no Roblox required. See `Tests/README.md`.
