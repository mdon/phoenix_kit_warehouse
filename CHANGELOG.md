# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 - 2026-07-13

Wave 1: multi-warehouse, transfers, deficit control, turnover.

### Added

- **Multi-warehouse stock scope**: per-location stock balances
  (`StockLedger.stock_map_for_location/1`, `get_quantity/2`), a warehouse
  selector on goods receipt/issue/inventory drafts, and a "per warehouse /
  all warehouses" scope toggle on the Stock page (persisted per user).
- **Transfers**: new document type with a draft → in_transit → done
  lifecycle, atomic ship/receive stock postings, and cancellation (draft:
  void; in_transit: reverses the ship posting back to the source
  warehouse).
- **Deficit control**: per-item minimum stock, an available-quantity
  calculation (on-hand minus posted reserves — draft documents don't
  reserve), zero-stock deficits surfaced even with no `Stock` row, and a
  "create supplier order" action from a deficit row.
- **Turnover report**: aggregated in/out/balance per item over a date
  range, optionally scoped to one warehouse; `balance` is documented as
  current on-hand, not a historical balance as of the end date.
- **Related documents**: a shared upstream/downstream linked-documents
  list component on Internal Order / Supplier Order cards.
- `Transfer`/`MinStock` tables now ship in core `phoenix_kit`'s migration
  V143+ instead of this package's own migrator (which is retired); this
  package defines schemas only and owns no DDL.

### Fixed

- `StockLedger.stock_map/0`, `Deficits`, `Inventories`, `GoodsReceipts`,
  `GoodsIssues` previous-quantity audit snapshots, and the `SourceKinds`
  link picker in the goods receipt/issue forms were all made
  warehouse-aware or corrected for multi-location stock (see
  [`dev_docs/pull_requests/2026/3-wave-1-multi-warehouse/CLAUDE_REVIEW.md`](dev_docs/pull_requests/2026/3-wave-1-multi-warehouse/CLAUDE_REVIEW.md)
  for the full list, plus this release's own post-merge fixes below).
- Post-merge review fixes: `SupplierOrders.generate_from_internal_order/2`
  and `import_from_internal_orders/3` now read on-hand stock from the
  internal order's own warehouse instead of an arbitrary one;
  `TransferFormLive`'s quantity input is now clamped non-negative
  (a negative value could otherwise inflate source-warehouse stock and
  permanently stall the transfer); `TurnoverReportLive` no longer queries
  the database in `mount/3` (was doubling the report query on every page
  load); `Transfer`/`MinStock` schemas now use `PhoenixKit.SchemaPrefix`,
  matching every other table-backed schema in this package.

### Requires

- `phoenix_kit >= 1.7.189` — `Transfer`/`MinStock` tables ship in core
  migration V143 (subsequently renumbered upstream; any published core
  release ≥ 1.7.189 satisfies this pin).

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
