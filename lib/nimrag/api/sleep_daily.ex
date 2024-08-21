defmodule Nimrag.Api.SleepDaily do
  use Nimrag.Api.Data

  defmodule Sleep do
    use Nimrag.Api.Data

    @type t() :: %__MODULE__{
            id: integer(),
            calendar_date: Date.t(),
            sleep_time_seconds: integer(),
            nap_time_seconds: integer(),
            sleep_start_local_at: NaiveDateTime.t(),
            sleep_end_local_at: NaiveDateTime.t()
          }
    defstruct ~w(id calendar_date sleep_time_seconds nap_time_seconds sleep_start_local_at sleep_end_local_at)a

    def schematic() do
      schema(__MODULE__, %{
        field(:id) => int(),
        field(:calendar_date) => date(),
        field(:sleep_time_seconds) => int(),
        field(:nap_time_seconds) => int(),
        {"sleepStartTimestampLocal", :sleep_start_local_at} => timestamp_as_naive_datetime()
        # {"sleepEndTimestampLocal", :sleep_end_local_at} => timestamp_as_naive_datetime()
      })
    end
  end

  defmodule SleepMovement do
    use Nimrag.Api.Data

    @type t() :: %__MODULE__{
            start_at: DateTime.t(),
            end_at: DateTime.t(),
            activity_level: float()
          }
    defstruct ~w(start_at end_at activity_level)a

    def schematic() do
      schema(__MODULE__, %{
        {"startGMT", :start_at} => gmt_datetime_as_datetime(),
        {"endGMT", :end_at} => gmt_datetime_as_datetime(),
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
