defmodule Nimrag.Api.SleepDaily do
  use Nimrag.Api.Data

  defmodule Sleep do
    use Nimrag.Api.Data

    @type t() :: %__MODULE__{
            id: integer(),
            calendar_date: Date.t(),
            sleep_time_seconds: integer(),
            nap_time_seconds: integer(),
            sleep_start_timestamp_local: DateTime.t(),
            sleep_end_timestamp_local: DateTime.t()
          }
    defstruct ~w(id calendar_date sleep_time_seconds nap_time_seconds sleep_start_timestamp_local sleep_end_timestamp_local)a

    def schematic() do
      schema(__MODULE__, %{
        field(:id) => int(),
        field(:calendar_date) => date(),
        field(:sleep_time_seconds) => int(),
        field(:nap_time_seconds) => int(),
        field(:sleep_start_timestamp_local) => timestamp_datetime(),
        field(:sleep_end_timestamp_local) => timestamp_datetime()
      })
    end
  end

  defmodule SleepMovement do
    use Nimrag.Api.Data

    @type t() :: %__MODULE__{
            start_gmt: DateTime.t(),
            end_gmt: DateTime.t(),
            activity_level: float()
          }
    defstruct ~w(start_gmt end_gmt activity_level)a

    def schematic() do
      schema(__MODULE__, %{
        {"startGMT", :start_gmt} => naive_datetime(),
        {"endGMT", :end_gmt} => naive_datetime(),
        field(:activity_level) => float()
      })
    end
  end

  alias __MODULE__.{Sleep, SleepMovement}

  @type t() :: %__MODULE__{
          sleep: nil | Sleep.t(),
          sleep_movement: nil | SleepMovement.t(),
          avg_overnight_hrv: nil | float(),
          resting_heart_rate: nil | integer()
        }

  defstruct ~w(sleep sleep_movement avg_overnight_hrv resting_heart_rate)a

  def schematic() do
    schema(__MODULE__, %{
      {"dailySleepDTO", :sleep} => nullable(Sleep.schematic()),
      field(:avg_overnight_hrv) => nullable(float()),
      field(:sleep_movement) => nullable(list(SleepMovement.schematic())),
      field(:resting_heart_rate) => nullable(int())
    })
  end
end
