defmodule Nimrag.Api.ActivityList do
  use Nimrag.Api.Data
  alias Nimrag.Api.ActivityType

  @type t() :: %__MODULE__{
          activity_id: integer(),
          distance: float(),
          duration: float(),
          activity_name: String.t(),
          begin_at: DateTime.t(),
          start_local_at: NaiveDateTime.t(),
          average_hr: nil | float(),
          max_hr: nil | float(),
          elevation_gain: nil | float(),
          elevation_loss: nil | float(),
          description: nil | String.t(),
          activity_type: ActivityType.t()
        }

  defstruct ~w(
    activity_id distance duration begin_at start_local_at activity_name description
    average_hr max_hr elevation_gain elevation_loss activity_type
  )a

  def schematic() do
    schema(__MODULE__, %{
      # TODO: check methods
      {"beginTimestamp", :begin_at} => timestamp_as_datetime(),
      {"startTimeLocal", :start_local_at} => naive_datetime(),
      field(:activity_id) => int(),
      field(:activity_name) => str(),
      field(:description) => nullable(str()),
      field(:distance) => float(),
      field(:duration) => float(),
      {"averageHR", :average_hr} => nullable(float()),
      {"maxHR", :max_hr} => nullable(float()),
      field(:elevationGain) => nullable(float()),
      field(:elevationLoss) => nullable(float()),
      field(:activity_type) => ActivityType.schematic()
    })
  end
end
