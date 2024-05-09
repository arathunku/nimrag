defmodule Nimrag.Api.Activity do
  use Nimrag.Api.Data
  alias Nimrag.Api.ActivityType

  defmodule Summary do
    @type t() :: %__MODULE__{
            distance: float(),
            duration: float(),
            average_hr: float(),
            max_hr: float(),
            elevation_gain: float(),
            elevation_loss: float()
          }

    defstruct ~w(
    id distance duration average_hr max_hr elevation_gain elevation_loss
  )a

    def schematic() do
      schema(__MODULE__, %{
        field(:distance) => float(),
        field(:duration) => float(),
        {"maxHR", :max_hr} => float(),
        {"averageHR", :average_hr} => float(),
        field(:elevation_gain) => float(),
        field(:elevation_loss) => float()
      })
    end
  end

  @type t() :: %__MODULE__{
          id: integer(),
          activity_name: String.t(),
          activity_type: ActivityType.t(),
          summary: __MODULE__.Summary.t()
        }

  defstruct ~w(
    id activity_name activity_type summary
  )a

  def schematic() do
    schema(__MODULE__, %{
      {"activityId", :id} => int(),
      field(:activity_name) => str(),
      {"activityTypeDTO", :activity_type} => ActivityType.schematic(),
      {"summaryDTO", :summary} => __MODULE__.Summary.schematic()
    })
  end
end
