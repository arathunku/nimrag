defmodule Nimrag.Api.StepsDaily do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          calendar_date: String.t(),
          step_goal: integer(),
          total_distance: integer(),
          total_steps: integer()
        }

  defstruct calendar_date: nil, step_goal: 0, total_distance: 0, total_steps: 0

  def schematic() do
    schema(__MODULE__, %{
      field(:calendar_date) => date(),
      field(:step_goal) => int(),
      field(:total_distance) => int(),
      field(:total_steps) => int()
    })
  end
end
