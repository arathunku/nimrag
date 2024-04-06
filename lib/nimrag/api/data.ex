defmodule Nimrag.Api.Data do
  @moduledoc """
  Behaviour for transforming direct responses from API into structs with known fields.
  """

  @callback from_api_response(body :: map | list(map)) :: {:ok, any} | {:error, atom}
end
