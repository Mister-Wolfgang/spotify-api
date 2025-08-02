defmodule SpotifyApi.Cache.LogHook do
  @moduledoc """
  Hook pour logger les opérations de cache importantes.
  """

  require Logger

  def put(result, key, _value, _options) do
    case result do
      {:ok, true} ->
        Logger.debug("Cache PUT: #{key}")
      {:error, reason} ->
        Logger.warning("Cache PUT failed for #{key}: #{inspect(reason)}")
    end

    result
  end

  def del(result, key, _options) do
    case result do
      {:ok, count} when count > 0 ->
        Logger.debug("Cache DEL: #{key}")
      _ ->
        :ok
    end

    result
  end

  def expire(result, key, _options) do
    case result do
      {:ok, true} ->
        Logger.debug("Cache EXPIRE: #{key}")
      _ ->
        :ok
    end

    result
  end
end
