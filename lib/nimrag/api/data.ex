defmodule Nimrag.Api.Data do
  import Schematic

  @moduledoc false

  # Helper module for transforming API responses into proper structs
  # Uses https://github.com/mhanberg/schematic and adds

  defmacro __using__(_) do
    quote do
      import Nimrag.Api.Data
      import Schematic

      def from_api_response(resp) do
        Nimrag.Api.Data.from_api_response(resp, __MODULE__)
      end
    end
  end

  def from_api_response(resp, module) do
    case unify(module.schematic(), resp) do
      {:error, err} -> {:error, {:invalid_response, err, resp}}
      {:ok, data} -> {:ok, data}
    end
  end

  def timestamp_datetime() do
    raw(
      fn
        i, :to -> is_number(i) and match?({:ok, _}, DateTime.from_unix(i, :millisecond))
        i, :from -> match?(%DateTime{}, i)
      end,
      transform: fn
        i, :to ->
          {:ok, dt} = DateTime.from_unix(i, :millisecond)
          dt

        i, :from ->
          DateTime.to_unix(i, :millisecond)
      end
    )
  end

  def naive_datetime() do
    raw(
      fn
        i, :to -> is_binary(i) and match?({:ok, _}, NaiveDateTime.from_iso8601(i))
        i, :from -> match?(%NaiveDateTime{}, i)
      end,
      transform: fn
        i, :to ->
          {:ok, dt} = NaiveDateTime.from_iso8601(i)
          dt

        i, :from ->
          NaiveDateTime.to_iso8601(i)
      end
    )
  end

  def date() do
    raw(
      fn
        i, :to -> is_binary(i) and match?({:ok, _}, Date.from_iso8601(i))
        i, :from -> match?(%Date{}, i)
      end,
      transform: fn
        i, :to ->
          {:ok, dt} = Date.from_iso8601(i)
          dt

        i, :from ->
          Date.to_iso8601(i)
      end
    )
  end

  def field(field) when is_atom(field),
    do: {
      field |> to_string() |> Recase.to_camel(),
      field
    }
end
