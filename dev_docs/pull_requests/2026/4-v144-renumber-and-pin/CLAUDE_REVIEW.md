# Review: PR #4 — Renumber V143 -> V144 references; require phoenix_kit >= 1.7.190

- **Author**: timujinne (Tymofii Shapovalov)
- **Merged**: 208912a into main via 7c09202, 2026-07-14
- **Files touched**: `AGENTS.md`, `lib/phoenix_kit_warehouse/min_stock_settings.ex`, `mix.exs`

## Context

Follow-up to PR #3. When core's consolidation PR (`BeamLabEU/phoenix_kit#632`) merged,
the migration that creates `phoenix_kit_warehouse_transfers` and
`phoenix_kit_warehouse_min_stock` was renumbered **V143 → V144**, because core's own
V143 slot had already been claimed by the new-login-security-alerts migration
(`phoenix_kit_user_known_devices`). V144 first ships in Hex `phoenix_kit` 1.7.190 —
1.7.189 tops out at V142. This PR re-pointed every V143 reference in this repo to
V144 and tightened the dependency pin from `~> 1.7 and >= 1.7.189` to `~> 1.7.190`.

## Verification

Checked the PR's factual claims against the actual core package (present in this
repo's `deps/phoenix_kit`, locked to 1.7.191):

- `deps/phoenix_kit/lib/phoenix_kit/migrations/postgres/v144.ex` moduledoc confirms
  V144 creates `phoenix_kit_warehouse_transfers` (+ its `number` sequence) and
  `phoenix_kit_warehouse_min_stock`, alongside the manufacturing tables — matches
  the PR's description exactly.
- `deps/phoenix_kit/CHANGELOG.md` confirms the 1.7.190 entry: "New migration V143
  adds `phoenix_kit_user_known_devices`" (login alerts) and "into core's single
  numbered chain (V144)" for the manufacturing/warehouse tables. So V143 really was
  reassigned upstream before publish, and 1.7.190 really is the first release
  containing V144. The PR's core claims check out.
- `~> 1.7.190` (vs. the old two-clause `~> 1.7 and >= 1.7.189`) does narrow the
  acceptable range from `< 2.0.0` to `< 1.8.0`. This looked at first like an
  unintended side effect of collapsing two clauses into one, but a sibling module
  (`phoenix_kit_locations`, `pk_dep(:phoenix_kit, "~> 1.7.189")`) uses the identical
  `~> 1.7.<patch>` pattern, so it's consistent with existing ecosystem precedent —
  not a regression introduced here.

## Finding

**IMPROVEMENT - MEDIUM — `CHANGELOG.md`'s published 0.2.0 entry still asserted the
stale V143/`>= 1.7.189` claim after this PR landed.**

The PR renumbered every V143 reference in `AGENTS.md`, `mix.exs`, and
`min_stock_settings.ex`, but missed `CHANGELOG.md`'s "Added" bullet and "Requires"
section for the already-published 0.2.0 release, which still read:

- "`Transfer`/`MinStock` tables now ship in core `phoenix_kit`'s migration V143+"
- "`phoenix_kit >= 1.7.189` — ... any published core release ≥ 1.7.189 satisfies
  this pin"

Per the same repo's own corrected docs, that's now factually wrong: 1.7.189 tops
out at V142 and does not carry the tables. A reader consulting the changelog to
figure out their minimum `phoenix_kit` version would be told a version that
doesn't actually work — exactly the class of bug this PR was fixing everywhere
else. Fixed as part of this review: both lines updated to V144 / `>= 1.7.190`, with
a note that this was corrected post-release (see `CHANGELOG.md`, 0.2.0 entry).

No other stale `V143` or `1.7.189` references remain (repo-wide grep, excluding
`deps/` and the archival PR #3 review doc, which correctly reflects what was true
at the time it was written and is left as-is).

## Gate

`mix precommit` run clean after the fix (see command output in the session; not
duplicated here).
