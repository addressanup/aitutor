# drivers

Per-app action sets for the headless AX density protocol
(`shell/Scripts/ax-density-run.sh --drivers <dir>`). One directory per bundle
id; `NN-*.axd` files run in sorted order, each performing ONE canonical action
~3x via the `axdrive` DSL (`activate` / `menu Path>To>Item` / `key cmd+x` /
`type text` / `sleep ms`). A `# name: …` first line names the action in the
coverage table. An optional `setup.sh` seeds app state (open a scratch doc);
run it before the harness. Findings go to `docs/notes/`, never here.
