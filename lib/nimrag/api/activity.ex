defmodule Nimrag.Api.Activity do
  use Nimrag.Api.Data
  alias Nimrag.Api.ActivityType

  defmodule Summary do
    @type t() :: %__MODULE__{
            distance: float(),
            duration: float(),
            average_hr: nil | float(),
            max_hr: nil | float(),
            elevation_gain: nil | float(),
            elevation_loss: nil | float(),
            start_local_at: NaiveDateTime.t(),
            start_at: DateTime.t()
          }

    defstruct ~w(distance duration average_hr max_hr elevation_gain elevation_loss start_local_at start_at)a

    def schematic() do
      schema(__MODULE__, %{
        field(:distance) => float(),
        field(:duration) => float(),
        {"maxHR", :max_hr} => nullable(float()),
        {"averageHR", :average_hr} => nullable(float()),
        field(:elevation_gain) => nullable(float()),
        field(:elevation_loss) => nullable(float()),
        {"startTimeLocal", :start_local_at} => naive_datetime(),
        {"startTimeGMT", :start_at} => gmt_datetime_as_datetime()
      })
    end
  end

  @type t() :: %__MODULE__{
          activity_id: integer(),
          activity_name: String.t(),
          activity_type: ActivityType.t(),
          description: nil | String.t(),
          summary: __MODULE__.Summary.t()
        }

  defstruct ~w(
    activity_id activity_name activity_type summary description
  )a

  def schematic() do
    schema(__MODULE__, %{
      field(:activity_id) => int(),
      field(:activity_name) => str(),
      field(:description) => nullable(str()),
      {"activityTypeDTO", :activity_type} => ActivityType.schematic(),
      {"summaryDTO", :summary} => __MODULE__.Summary.schematic()
    })
  end
end
