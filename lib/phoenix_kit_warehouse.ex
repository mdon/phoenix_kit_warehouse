defmodule PhoenixKitWarehouse do
  @moduledoc """
  PhoenixKit module: stock, stocktakes, internal orders, supplier orders,
  goods receipt, and goods issue.

  Hard-depends on `phoenix_kit_catalogue` (warehouse only ever tracks
  catalogue items) and `phoenix_kit_locations` (every document carries a
  `location_uuid` resolved through it) — see `required_modules/0`.

  `PhoenixKitComments` stays optional (guarded via `Code.ensure_loaded?/1`
  in the document context modules — see Plan 3).

  Documents link to host-owned records (a sub-order, a top-level order, or
  anything else a consuming app wants to link) through the generic
  `PhoenixKitWarehouse.SourceKinds` registry rather than a direct dependency
  on any specific "order" concept — see that module's docs.
  """

  use PhoenixKit.Module

  alias PhoenixKit.Settings

  @version Mix.Project.config()[:version]

  # ===========================================================================
  # Required callbacks
  # ===========================================================================

  @impl PhoenixKit.Module
  def module_key, do: "warehouse"

  @impl PhoenixKit.Module
  def module_name, do: "Warehouse"

  @impl PhoenixKit.Module
  def enabled? do
    Settings.get_boolean_setting("warehouse_enabled", false)
  rescue
    _ -> false
  catch
    # Sandbox-owner-exited race: a non-DataCase test calls `enabled?/0`
    # right as a sibling test's owner pid has stopped. The pool checkout
    # exits before we even reach the `rescue` clause, so we have to
    # `catch :exit` separately. Returning `false` is correct — if we
    # can't read the setting, the module is effectively disabled.
    :exit, _ -> false
  end

  @impl PhoenixKit.Module
  def enable_system do
    result =
      Settings.update_boolean_setting_with_module("warehouse_enabled", true, module_key())

    PhoenixKit.Activity.log(%{
      action: "warehouse_module.enabled",
      mode: "manual",
      resource_type: "module",
      metadata: %{"module_key" => module_key()}
    })

    result
  end

  @impl PhoenixKit.Module
  def disable_system do
    result =
      Settings.update_boolean_setting_with_module("warehouse_enabled", false, module_key())

    PhoenixKit.Activity.log(%{
      action: "warehouse_module.disabled",
      mode: "manual",
      resource_type: "module",
      metadata: %{"module_key" => module_key()}
    })

    result
  end

  # ===========================================================================
  # Optional callbacks
  # ===========================================================================

  @impl PhoenixKit.Module
  def version, do: @version

  @impl PhoenixKit.Module
  def required_modules, do: ["catalogue", "locations"]

  @impl PhoenixKit.Module
  def css_sources, do: [:phoenix_kit_warehouse]

  @impl PhoenixKit.Module
  def children, do: [{Task.Supervisor, name: PhoenixKitWarehouse.TaskSupervisor}]

  # Populated in the phoenix_kit_warehouse-liveviews-and-admin-tabs plan —
  # this plan ships no LiveViews yet, so there is nothing to route to.
  @impl PhoenixKit.Module
  def admin_tabs, do: []

  @impl PhoenixKit.Module
  def settings_tabs, do: []
end
