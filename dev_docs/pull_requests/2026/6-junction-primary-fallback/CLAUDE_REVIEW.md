# Review: PR #6 — Junction is_primary fallback: restore a working default-supplier path

- **Author**: timujinne (Tymofii Shapovalov)
- **Merged**: f7c4441 into main via cc2fc51, 2026-07-16
- **Files touched**: `lib/phoenix_kit_warehouse/supplier_orders.ex`, `mix.lock`

## Context

Follow-up to PR #5 (see `dev_docs/pull_requests/2026/5-parties-resolver-unit-value/CLAUDE_REVIEW.md`),
whose review found that `resolve_suppliers/1`'s original rewrite silently
dropped `item.primary_supplier_uuid` resolution and reverted it to check the
scalar first. This PR adds a *second* clause between the scalar check and the
manufacturer fallback: a guarded call to
`PhoenixKitCatalogue.Catalogue.Suppliers.primary_for_item/1` (the V151 junction
`is_primary` row), justified by a comment stating the scalar was "removed in
catalogue PR #44" and that the junction is now "the working default-supplier
mechanism."

## Verification

Checked against the actual dependency, not just the PR's comments — same
discipline PR #5's review applied:

- `deps/phoenix_kit_catalogue` is still Hex-pinned to **0.10.0** (unchanged by
  this PR; `mix.lock`'s `phoenix_kit_catalogue` entry is untouched — only
  `hackney` moved). Confirmed live against the Hex API
  (`https://hex.pm/api/packages/phoenix_kit_catalogue`): **0.10.0 is still the
  latest published release** as of 2026-07-16.
- `PhoenixKitCatalogue.Catalogue.Suppliers.primary_for_item/1` does **not**
  exist in that version — confirmed by reading
  `deps/phoenix_kit_catalogue/lib/phoenix_kit_catalogue/catalogue/suppliers.ex`
  in full. `function_exported?(Suppliers, :primary_for_item, 1)` is `false` in
  production today, so the new clause's guard always fails and falls through
  to `resolve_via_manufacturer/1` — **this part is correctly, safely written**
  (the `with`/`else` short-circuits before `apply/3` ever runs, so there's no
  crash risk).
- The PR's claim that `primary_supplier_uuid` was "removed in catalogue PR
  #44" is accurate *as catalogue git history reads* — but checking the local
  `../phoenix_kit_catalogue` checkout's dates shows the full picture: the
  scalar was added in catalogue commit `2e47cdf` (2026-07-06) and removed by
  PR #44's merge `1ccde09` (2026-07-15) — **both after** catalogue's last Hex
  release (`0.10.0`, tagged 2026-07-03). The published 0.10.0 package **never
  had `primary_supplier_uuid` at all**. This means PR #5's review conclusion
  that "the field is still live on the catalogue Item schema in the pinned
  0.10.0 dependency" was itself incorrect — most likely checked against a
  `PHOENIX_KIT_CATALOGUE_PATH`-overridden local checkout rather than the real
  pinned package (confirmed here with no such env var set:
  `deps/phoenix_kit_catalogue` is a real fetched directory, not a symlink, and
  `schemas/item.ex` has no `primary_supplier_uuid` field, no `belongs_to`, no
  cast entry).
- Net effect: **both** non-manufacturer clauses in `resolve_suppliers/1` are
  currently unreachable against the real, pinned dependency.
  `resolve_suppliers/1` behaves identically to `resolve_via_manufacturer/1`
  alone — a generic/unbranded item with no `manufacturer_uuid` still resolves
  to zero suppliers, and a manufacturer with more than one linked supplier
  still can't have a primary break the tie. This is **not a new regression
  from this PR** (that baseline was already the case after PR #5's "fix," for
  the same underlying reason), but the PR title/commit message ("restore a
  working default-supplier path") and code comments ("the working
  default-supplier mechanism is…") assert the opposite of what's actually
  live today.
- The two tests added by PR #5 under "resolve_suppliers — primary_supplier_uuid
  scalar" (`test/phoenix_kit_warehouse/supplier_orders_test.exs`) both pass
  `primary_supplier_uuid` as a create-item attribute expecting it to set the
  default supplier. Since the field doesn't exist on the real `Item` schema,
  `Ecto.Changeset.cast/4` silently drops it — the resulting items are actually
  plain "no manufacturer" / "manufacturer with 2 linked suppliers, no
  tie-break" cases, which resolve to **zero** or **ambiguous** suppliers and
  land unassigned. Both tests assert `length(orders) == 1`, so **both would
  fail against the real dependency** (integration-tagged, DB-gated — could not
  execute here per the project's testing stance; confirmed by static trace of
  `resolve_suppliers/1` → `generate_from_internal_order/2`'s
  `[supplier] -> assign / _ -> unassigned` branch).

## Finding

**IMPROVEMENT - HIGH — the PR's premise ("restore a working default-supplier
path") doesn't hold against the dependency actually pinned in `mix.lock`; two
pre-existing tests assert behavior that can't occur against that dependency
and would fail if ever run against Postgres.**

Fixed as part of this review:
- Rewrote the comments on both `resolve_suppliers/1` clauses in
  `lib/phoenix_kit_warehouse/supplier_orders.ex` to state plainly, with the
  verified evidence, that neither the scalar nor the junction path is reachable
  against the pinned `phoenix_kit_catalogue` 0.10.0 today, and that the
  junction clause activates automatically (no code change needed) once
  catalogue publishes the release carrying `primary_for_item/1` and this
  repo's `mix.lock` picks it up.
- Replaced the two broken "primary_supplier_uuid scalar" tests with three
  tests that lock in the real, currently-reachable behavior: a no-manufacturer
  item lands unassigned, an ambiguous (>1 linked supplier) manufacturer lands
  unassigned, and — the actual regression-relevant coverage this PR should
  have shipped — a single-linked-supplier manufacturer still resolves and
  assigns correctly through the new guarded clause (proving the junction guard
  doesn't break the existing manufacturer fallback path).
- Not fixed (deliberately, no code change): the underlying capability gap
  (no way to set a default/primary supplier today) is a real product gap, not
  a bug introduced by this PR, and depends entirely on an external package
  release. Left as-is.

## Verification of the fix

- `mix format`, `mix compile --force --warnings-as-errors`, `mix deps.unlock
  --check-unused`, `mix hex.audit` all clean.
- `mix credo --strict`: exits non-zero, but diffed line-for-line against the
  pre-PR baseline (`git stash` + rerun) — identical finding count (2
  refactoring, 41 readability, 248 design) and zero new findings in either
  file this review touched. Pre-existing repo-wide baseline, unrelated to this
  change (same pattern noted in phoenix_kit_catalogue's own CHANGELOG for its
  sibling modules).
- `mix dialyzer`: exits non-zero (11 findings), but diffed against the pre-PR
  baseline the same way as credo (`git stash` + rerun with the PLT already
  built) — byte-identical 11 findings at the same file:line locations in both
  runs, none in the lines this review touched (the one `supplier_orders.ex`
  hit, line 639, is `lock_status_step/3`, unrelated to `resolve_suppliers/1`).
  Pre-existing baseline, unrelated to this change.
- `mix test`: DB-gated (`:integration` tag), no PostgreSQL available in this
  environment — the new/rewritten tests could not be executed. They were
  checked by static trace against `resolve_suppliers/1` and
  `generate_from_internal_order/2`'s exact branch logic
  (`[supplier] -> assign`, `_ -> unassigned`) rather than run.

## Note for a future PR

Once `phoenix_kit_catalogue` actually publishes the `primary_for_item/1` /
junction-table release and this repo's `mix.lock` is bumped to it: the guard
in `resolve_suppliers/1`'s second clause activates with no code change, but
the three tests added here (`resolve_suppliers — no primary-supplier support
(current dependency)`) will need new tests added alongside them for the
now-live junction-primary and CRM-unresolvable-supplier-warning paths — the
guard's `else` branch and the `Logger.warning` branch currently have zero
coverage precisely because they're unreachable today.
