# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0 - 2026-07-10

Initial release.

### Added

- **Inventory & stock**: `Stock` balances per item/location, `StockLedger`
  context (upsert/receive/issue with an atomic, non-negative-guarded
  conditional decrement), and stocktakes (`InventoryDocument`) that count
  and post adjustments.
- **Goods receipts & goods issues**: transactional posting (`Ecto.Multi` +
  `FOR UPDATE` compare-and-swap on status) that additively increases
  (receipts) or conditionally decreases (issues) warehouse stock, with a
  per-line `previous_quantity` audit trail.
- **Supplier orders & internal orders**: draft → posted document lifecycle,
  many-to-many traceability via a generic `source_refs` / `SourceKinds`
  registry (host apps can register their own linkable "order" kinds),
  committed-quantity netting to avoid re-ordering already-requested stock.
- **Admin UI**: index + form LiveViews for every document type, a shared
  `ColumnConfig` engine (sortable/filterable/configurable columns, per-user
  view persistence), file attachments via `StorageFolders`, and comments
  via `PhoenixKitComments` (optional — degrades gracefully when absent).
- Activity logging, i18n (en/et/ru), and the `PhoenixKit.Module` admin-tab
  integration (`module_key: "warehouse"`).
- Project scaffold: `mix.exs` (with the `pk_dep/3` helper, `quality` /
  `quality.ci` / `precommit` aliases, and dialyzer config), `config/`,
  `.formatter.exs`, `.credo.exs`, `.gitignore`, `LICENSE`, and `AGENTS.md`.

### Requires

- `phoenix_kit >= 1.7.182` — the warehouse DB tables ship in core migration
  V140, first published in that core release.

### Known issues

See [`dev_docs/pull_requests/2026/1-warehouse-module/CLAUDE_REVIEW.md`](dev_docs/pull_requests/2026/1-warehouse-module/CLAUDE_REVIEW.md)
for the full review. Notably: stocktake posting can clobber stock movements
that happened between opening the count and posting it (absolute-SET
semantics), and "Generate supplier orders" doesn't record `source_refs`, so
re-importing the same internal order into a second supplier order can
double the ordered quantity. Both need a maintainer decision on intended
semantics before being fixed.
