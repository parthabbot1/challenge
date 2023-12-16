defmodule Challenge.UserSupervisor do
  @moduledoc """
  This supervisor is responsible to create wallet for the users.
  """
  use DynamicSupervisor

  alias Challenge.Models.Bet
  alias Challenge.Models.User
  alias Challenge.Models.Win
  alias Challenge.UserWorker

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 3, max_seconds: 5)
  end

  @spec start_children(server :: GenServer.server(), users :: [String.t()]) :: :ok
  def start_children(server, users) do
    Enum.each(users, fn user ->
      child_spec = {UserWorker, [User.new(%{id: user}), server]}

      DynamicSupervisor.start_child(server, child_spec)
    end)
  end

  @spec bet(server :: GenServer.server(), body :: map, registry :: atom()) :: map
  def bet(server, body, registry) do
    with %Bet{user: user} = bet <- Bet.new(body),
         {:ok, pid} <- check_user_exists(registry, "#{user}_#{inspect(server)}"),
         {:ok, res} <- GenServer.call(pid, {:bet, bet}) do
      res
    else
      {:error, :invalid_bet} ->
        %{status: "RS_ERROR_WRONG_SYNTAX"}

      {:error, :wrong_type} ->
        %{status: "RS_ERROR_WRONG_TYPES"}

      _ ->
        %{status: "RS_ERROR_UNKNOWN"}
    end
  end

  @spec win(server :: GenServer.server(), body :: map, registry :: atom()) :: map
  def win(server, body, registry) do
    with %Win{user: user} = win <- Win.new(body),
         {:ok, pid} <- check_user_exists(registry, "#{user}_#{inspect(server)}"),
         {:ok, res} <- GenServer.call(pid, {:win, win}) do
      res
    else
      {:error, :invalid_win} ->
        %{status: "RS_ERROR_WRONG_SYNTAX"}

      {:error, :wrong_type} ->
        %{status: "RS_ERROR_WRONG_TYPES"}

      _ ->
        %{status: "RS_ERROR_UNKNOWN"}
    end
  end

  defp check_user_exists(registry, name) do
    case Registry.lookup(registry, name) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        []
    end
  end
end
