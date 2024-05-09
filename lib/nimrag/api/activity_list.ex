defmodule Nimrag.Api.ActivityList do
  use Nimrag.Api.Data
  alias Nimrag.Api.ActivityType

  @type t() :: %__MODULE__{
          id: integer(),
          distance: float(),
          duration: float(),
          activity_name: String.t(),
          begin_at: DateTime.t(),
          start_local_at: NaiveDateTime.t(),
          average_hr: float(),
          max_hr: float(),
          elevation_gain: float(),
          elevation_loss: float(),
          description: nil | String.t(),
          activity_type: ActivityType.t()
        }

  defstruct ~w(
    id distance duration begin_at start_local_at activity_name
    average_hr max_hr elevation_gain elevation_loss description activity_type
  )a

  def schematic() do
    schema(__MODULE__, %{
      {"beginTimestamp", :begin_at} => timestamp_datetime(),
      {"startTimeLocal", :start_local_at} => naive_datetime(),
      {"activityId", :id} => int(),
      field(:activity_name) => str(),
      :distance => float(),
      :duration => float(),
      {"averageHR", :average_hr} => float(),
      {"maxHR", :max_hr} => float(),
      field(:elevationGain) => float(),
      field(:elevationLoss) => float(),
      field(:description) => nullable(str()),
      field(:activity_type) => ActivityType.schematic()
    })
  end
end
