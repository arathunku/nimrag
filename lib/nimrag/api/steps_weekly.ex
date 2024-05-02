defmodule Nimrag.Api.StepsWeekly do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          calendar_date: String.t(),
          values: %{
            total_steps: float(),
            average_steps: float(),
            average_distance: float(),
            total_distance: float(),
            wellness_data_days_count: integer()
          }
        }

  defstruct ~w(calendar_date values)a

  def schematic() do
    schema(__MODULE__, %{
      field(:calendar_date) => date(),
      field(:values) =>
        map(%{
          field(:total_steps) => float(),
          field(:average_steps) => float(),
          field(:average_distance) => float(),
          field(:total_distance) => float(),
          field(:wellness_data_days_count) => int()
        })
    })
  end
end
