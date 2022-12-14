defmodule Tiki.Seller do
  @moduledoc """
  API to get seller information
  """
  alias Tiki.Client
  alias Tiki.Support.Helpers
  alias Tiki.Enums.WarehouseType
  alias Tiki.Enums.WarehouseStatus

  @doc """
  Get seller info
  Ref: https://open.tiki.vn/docs/docs/current/api-references/seller-api/#get-seller
  """
  def me(opts \\ []) do
    with {:ok, client} <- Client.new(opts) do
      Client.get(client, "/sellers/me")
    end
  end

  @doc """
  Return list of seller warehouses

  Ref: https://open.tiki.vn/docs/docs/current/api-references/seller-api/#get-seller-warehouse
  """
  @get_seller_warehouse_schema %{
    status: [type: :integer, in: WarehouseStatus.enum()],
    type: [type: :integer, in: WarehouseType.enum()],
    limit: :integer,
    page: :integer
  }
  def get_seller_warehouse(params, opts \\ []) do
    with {:ok, data} <- Tarams.cast(params, @get_seller_warehouse_schema),
         data <- Helpers.clean_nil(data),
         {:ok, client} <- Client.new(opts) do
      Client.get(client, "/sellers/me/warehouses", query: data)
    end
  end
end
