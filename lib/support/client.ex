defmodule Tiki.Client do
  @moduledoc """
  Process and sign data before sending to Tiktok and process response from Tiki server
  Proxy could be config

      config :tiki, :config,
            proxy: "http://127.0.0.1:9090",
            client_id: "",
            client_secret: "",
            timeout: 10_000,
            response_handler: MyModule,
            middlewares: [] # custom middlewares

  Your custom reponse handler module must implement `handle_response/1`
  """

  @default_endpoint "https://open-api.tiktokglobalshop.com"
  @doc """
  Create a new client with given credential.
  Credential can be set using config.

      config :tiktok, :config
            client_id: "",
            client_secret: ""

  Or could be pass via `opts` argument

  **Options**
  - `credential [map]`: app credential for request.
    Credential map follow schema belows

    client_id: [type: :string, required: true],
    client_secret: [type: :string, required: true],
    access_token: :string,
    shop_id: :string


  - `endpoint [string]`: custom endpoint
  - `form_data [boolean]`: use form data, using json by default
  - `skip_signing [boolean]`: Skip signing the data before sending a request
  """

  def new(opts \\ []) do
    config = Tiki.Support.Helpers.get_config()

    proxy_adapter =
      if config.proxy do
        [proxy: config.proxy]
      else
        nil
      end

    credential = Map.merge(config.credential, opts[:credential] || %{})
    skip_signing = opts[:skip_signing] || false

    with {:ok, credential} <- validate_credential(credential, skip_signing) do
      options =
        [
          adapter: proxy_adapter,
          credential: credential
        ]
        |> Tiki.Support.Helpers.clean_nil()

      middlewares = [
        {Tesla.Middleware.BaseUrl, opts[:endpoint] || @default_endpoint},
        {Tesla.Middleware.Opts, options},
        # Tiki.Support.SignRequest,
        Tiki.Support.SaveRequestBody
      ]

      middlewares =
        if opts[:form_data] do
          middlewares ++ [Tesla.Middleware.FormUrlencoded, Tesla.Middleware.DecodeJson]
        else
          middlewares ++ [Tesla.Middleware.JSON]
        end

      # if config setting timeout, otherwise use default settings
      middlewares =
        if config.timeout do
          [{Tesla.Middleware.Timeout, timeout: config.timeout} | middlewares]
        else
          middlewares
        end

      {:ok, Tesla.client(middlewares ++ config.middlewares)}
    end
  end

  @credential_schema %{
    client_id: [type: :string, required: true],
    client_secret: [type: :string, required: true],
    access_token: :string,
    shop_id: :string
  }
  defp validate_credential(credential, false) do
    Contrak.validate(credential, @credential_schema)
  end

  defp validate_credential(_, _), do: {:ok, nil}

  @doc """
  Perform a GET request

      get("/users")
      get("/users", query: [scope: "admin"])
      get(client, "/users")
      get(client, "/users", query: [scope: "admin"])
      get(client, "/users", body: %{name: "Jon"})
  """
  @spec get(Tesla.Client.t(), String.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def get(client, path, opts \\ []) do
    client
    |> Tesla.get(path, [{:opts, [api_name: path]} | opts])
    |> process()
  end

  @doc """
  Perform a POST request.

      post("/users", %{name: "Jon"})
      post("/users", %{name: "Jon"}, query: [scope: "admin"])
      post(client, "/users", %{name: "Jon"})
      post(client, "/users", %{name: "Jon"}, query: [scope: "admin"])
  """
  @spec post(Tesla.Client.t(), String.t(), map(), keyword()) :: {:ok, any()} | {:error, any()}
  def post(client, path, body, opts \\ []) do
    client
    |> Tesla.post(path, body, [{:opts, [api_name: path]} | opts])
    |> process()
  end

  @doc """
  Perform a POST request.

      post("/users", %{name: "Jon"})
      post("/users", %{name: "Jon"}, query: [scope: "admin"])
      post(client, "/users", %{name: "Jon"})
      post(client, "/users", %{name: "Jon"}, query: [scope: "admin"])
  """
  @spec put(Tesla.Client.t(), String.t(), map(), keyword()) :: {:ok, any()} | {:error, any()}
  def put(client, path, body, opts \\ []) do
    client
    |> Tesla.put(path, body, [{:opts, [api_name: path]} | opts])
    |> process()
  end

  @doc """
  Perform a DELETE request

      delete("/users")
      delete("/users", query: [scope: "admin"])
      delete(client, "/users")
      delete(client, "/users", query: [scope: "admin"])
      delete(client, "/users", body: %{name: "Jon"})
  """
  @spec delete(Tesla.Client.t(), String.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def delete(client, path, opts \\ []) do
    client
    |> Tesla.delete(path, [{:opts, [api_name: path]} | opts])
    |> process()
  end

  defp process(response) do
    module =
      Application.get_env(:tiktok, :config, [])
      |> Keyword.get(:response_handler, __MODULE__)

    module.handle_response(response)
  end

  @doc """
  Default response handler for request, user can customize by pass custom module in config
  """
  def handle_response(response) do
    case response do
      {:ok, %{body: body}} ->
        if is_map(body) && body["error"] do
          {:error, body}
        else
          {:ok, body}
        end

      {_, _result} ->
        {:error, %{type: :system_error, response: response}}
    end
  end
end
