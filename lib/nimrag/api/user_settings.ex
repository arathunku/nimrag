defmodule Nimrag.Api.UserSettings do
  use Nimrag.Api.Data
  alias Nimrag.Api.UserData

  @type t() :: %__MODULE__{
          id: integer(),
          user_data: UserData.t(),
          # user_sleep: UserSleep
          connect_date: nil | String.t(),
          source_type: nil | String.t()
        }

  defstruct ~w(id user_data connect_date source_type)a

  def schematic() do
    schema(__MODULE__, %{
      field(:id) => int(),
      field(:user_data) => UserData.schematic(),
      # user_sleep: UserSleep
      field(:connect_date) => nullable(str()),
      field(:source_type) => nullable(str())
    })
  end
end
