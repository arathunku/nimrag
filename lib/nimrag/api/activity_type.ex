defmodule Nimrag.Api.ActivityType do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          is_hidden: boolean(),
          parent_type_id: integer(),
          restricted: boolean(),
          trimmable: boolean(),
          type_id: integer(),
          type_key: String.t()
        }

  defstruct ~w(is_hidden parent_type_id restricted trimmable type_id type_key)a

  def schematic() do
    schema(__MODULE__, %{
      field(:is_hidden) => bool(),
      field(:parent_type_id) => int(),
      field(:restricted) => bool(),
      field(:trimmable) => bool(),
      field(:type_id) => int(),
      field(:type_key) => str()
    })
  end
end
