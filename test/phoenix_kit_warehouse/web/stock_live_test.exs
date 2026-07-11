defmodule PhoenixKitWarehouse.Web.StockLiveTest do
  use PhoenixKitWarehouse.LiveCase, async: false
  import Phoenix.LiveViewTest

  alias PhoenixKitCatalogue.Catalogue
  alias PhoenixKitLocations.Locations
  alias PhoenixKitWarehouse.StockLedger

  defp email, do: "wh-#{System.unique_integer([:positive])}@example.com"

  defp admin do
    {:ok, u} =
      PhoenixKit.Users.Auth.register_user(%{
        "email" => email(),
        "password" => "password123456789",
        "first_name" => "W",
        "last_name" => "A"
      })

    {:ok, u} = PhoenixKit.Users.Auth.admin_confirm_user(u)
    {:ok, _} = PhoenixKit.Users.Roles.promote_to_admin(u)
    PhoenixKit.Users.Auth.get_user!(u.uuid)
  end

  defp login(conn, u) do
    t = PhoenixKit.Users.Auth.generate_user_session_token(u)
    conn |> Plug.Test.init_test_session(%{}) |> Plug.Conn.put_session(:user_token, t)
  end

  defp path, do: PhoenixKit.Utils.Routes.path("/admin/warehouse")

  defp create_catalogue! do
    {:ok, cat} =
      Catalogue.create_catalogue(%{
        name: "Stock Scope Test #{System.unique_integer([:positive])}"
      })

    cat
  end

  defp create_item!(cat, name) do
    {:ok, item} =
      Catalogue.create_item(%{
        name: name,
        catalogue_uuid: cat.uuid,
        base_price: "10.00",
        status: "active",
        sku: "SK-#{System.unique_integer([:positive])}"
      })

    item
  end

  # Creates real Location records tagged with a fresh warehouse LocationType and
  # marks that type as the warehouse type. The per-test sandbox rolls both the
  # rows and the setting back, so no manual cleanup is needed.
  defp setup_warehouses!(names) do
    {:ok, type} =
      Locations.create_location_type(%{
        name: "Stock WH Type #{System.unique_integer([:positive])}"
      })

    locations =
      Enum.map(names, fn name ->
        {:ok, loc} = Locations.create_location(%{name: name, status: "active"})
        Locations.sync_location_types(loc.uuid, [type.uuid])
        loc
      end)

    StockLedger.set_warehouse_location_type_uuid(type.uuid)
    locations
  end

  test "default view is grouped — no parity toolbar", %{conn: conn} do
    {:ok, _lv, html} = live(login(conn, admin()), path())
    refute html =~ ~s(phx-click="show_column_modal")
  end

  test "switching to flat reveals the parity toolbar and persists the choice", %{conn: conn} do
    a = admin()
    {:ok, lv, _} = live(login(conn, a), path())
    html = render_click(element(lv, ~s([phx-click="set_stock_view"][phx-value-view="flat"])))
    assert html =~ ~s(phx-change="search")
    assert html =~ ~s(phx-click="show_column_modal")

    cfg = PhoenixKitWarehouse.ViewConfigs.get_view_config(a.uuid, "warehouse_stock")
    assert Map.get(cfg, "stock_view") == "flat"

    # persisted: a fresh mount opens directly in flat
    {:ok, _lv2, html2} = live(login(conn, a), path())
    assert html2 =~ ~s(phx-click="show_column_modal")
  end

  test "column modal save persists columns under warehouse_stock", %{conn: conn} do
    a = admin()
    {:ok, lv, _} = live(login(conn, a), path())
    render_click(element(lv, ~s([phx-click="set_stock_view"][phx-value-view="flat"])))
    render_click(lv, "add_column", %{"column_id" => "sku"})

    render_click(lv, "update_table_columns", %{
      "column_order" => "item,catalogue,quantity,total_value,sku"
    })

    cfg = PhoenixKitWarehouse.ViewConfigs.get_view_config(a.uuid, "warehouse_stock")
    assert "sku" in Map.get(cfg, "columns", [])
  end

  describe "warehouse scope selector" do
    test "no warehouse select when no warehouse location type is configured", %{conn: conn} do
      StockLedger.set_warehouse_location_type_uuid(nil)
      {:ok, _lv, html} = live(login(conn, admin()), path())
      refute html =~ ~s(phx-change="set_warehouse_scope")
    end

    test "renders a select with an All warehouses option plus configured warehouses", %{
      conn: conn
    } do
      [loc_a, loc_b] = setup_warehouses!(["Stock Scope A", "Stock Scope B"])

      {:ok, _lv, html} = live(login(conn, admin()), path())

      assert html =~ ~s(phx-change="set_warehouse_scope")
      assert html =~ "All warehouses"
      assert html =~ loc_a.name
      assert html =~ loc_b.name
    end

    test "selecting a warehouse scopes the Grouped view to that location's items only", %{
      conn: conn
    } do
      a = admin()
      [loc_a, loc_b] = setup_warehouses!(["Stock Scope A", "Stock Scope B"])
      cat = create_catalogue!()
      item_a = create_item!(cat, "Alpha Widget")
      item_b = create_item!(cat, "Beta Widget")

      {:ok, _} = StockLedger.upsert_quantity(item_a.uuid, "4", location_uuid: loc_a.uuid)
      {:ok, _} = StockLedger.upsert_quantity(item_b.uuid, "6", location_uuid: loc_b.uuid)

      {:ok, lv, html} = live(login(conn, a), path())
      assert html =~ "Alpha Widget"
      assert html =~ "Beta Widget"

      html =
        lv
        |> element("form[phx-change='set_warehouse_scope']")
        |> render_change(%{"location_uuid" => loc_a.uuid})

      assert html =~ "Alpha Widget"
      refute html =~ "Beta Widget"

      cfg = PhoenixKitWarehouse.ViewConfigs.get_view_config(a.uuid, "warehouse_stock")
      assert Map.get(cfg, "warehouse_scope") == loc_a.uuid

      # persisted: a fresh mount opens already scoped to loc_a
      {:ok, _lv2, html2} = live(login(conn, a), path())
      assert html2 =~ "Alpha Widget"
      refute html2 =~ "Beta Widget"
    end

    test "the flat view reflects the same warehouse scope as the grouped view", %{conn: conn} do
      a = admin()
      [loc_a, loc_b] = setup_warehouses!(["Stock Scope A", "Stock Scope B"])
      cat = create_catalogue!()
      item_a = create_item!(cat, "Alpha Widget")
      item_b = create_item!(cat, "Beta Widget")

      {:ok, _} = StockLedger.upsert_quantity(item_a.uuid, "4", location_uuid: loc_a.uuid)
      {:ok, _} = StockLedger.upsert_quantity(item_b.uuid, "6", location_uuid: loc_b.uuid)

      {:ok, lv, _html} = live(login(conn, a), path())

      lv
      |> element("form[phx-change='set_warehouse_scope']")
      |> render_change(%{"location_uuid" => loc_b.uuid})

      html = render_click(element(lv, ~s([phx-click="set_stock_view"][phx-value-view="flat"])))

      assert html =~ "Beta Widget"
      refute html =~ "Alpha Widget"
    end

    test "choosing All warehouses again clears the scope and restores every item", %{conn: conn} do
      a = admin()
      [loc_a, loc_b] = setup_warehouses!(["Stock Scope A", "Stock Scope B"])
      cat = create_catalogue!()
      item_a = create_item!(cat, "Alpha Widget")
      item_b = create_item!(cat, "Beta Widget")

      {:ok, _} = StockLedger.upsert_quantity(item_a.uuid, "4", location_uuid: loc_a.uuid)
      {:ok, _} = StockLedger.upsert_quantity(item_b.uuid, "6", location_uuid: loc_b.uuid)

      {:ok, lv, _html} = live(login(conn, a), path())

      lv
      |> element("form[phx-change='set_warehouse_scope']")
      |> render_change(%{"location_uuid" => loc_a.uuid})

      html =
        lv
        |> element("form[phx-change='set_warehouse_scope']")
        |> render_change(%{"location_uuid" => ""})

      assert html =~ "Alpha Widget"
      assert html =~ "Beta Widget"

      cfg = PhoenixKitWarehouse.ViewConfigs.get_view_config(a.uuid, "warehouse_stock")
      assert Map.get(cfg, "warehouse_scope") == ""
    end
  end
end
