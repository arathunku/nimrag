defmodule Nimrag.Api.ActivityDetails do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          activity_id: integer(),
          metric_descriptors: list(),
          activity_detail_metrics: list(map()),
          measurement_count: integer(),
          activity_detail_metrics: list(map())
        }

  defstruct ~w(
    activity_id metric_descriptors measurement_count activity_detail_metrics
  )a

  def schematic() do
    schema(__MODULE__, %{
      field(:activity_id) => int(),
      field(:metric_descriptors) =>
        list(
          map(%{
            field(:key) => str(),
            field(:metrics_index) => int(),
            field(:unit) =>
              map(%{
                field(:factor) => float(),
                field(:id) => int(),
                field(:key) => str()
              })
          })
        ),
      field(:measurement_count) => int(),
      field(:activity_detail_metrics) => list(map(%{field(:metrics) => list(nullable(float()))}))
    })
  end
end
