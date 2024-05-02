defmodule Nimrag.Api.HydrationContainer do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{name: String.t(), volume: integer(), unit: String.t()}

  defstruct ~w(name volume unit)a

  def schematic() do
    schema(__MODULE__, %{
      field(:name) => str(),
      field(:volume) => int(),
      field(:unit) => str()
    })
  end
end
