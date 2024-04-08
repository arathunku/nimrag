defmodule Nimrag.Api.Activity do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          id: integer(),
          distance: float(),
          duration: float(),
          activity_name: String.t(),
          begin_at: DateTime.t(),
          start_local_at: NaiveDateTime.t()
        }

  defstruct ~w(id distance duration begin_at start_local_at activity_name)a

  def schematic() do
    schema(__MODULE__, %{
      {"beginTimestamp", :begin_at} => timestamp_datetime(),
      {"startTimeLocal", :start_local_at} => naive_datetime(),
      {"activityId", :id} => int(),
      field(:activity_name) => str(),
      distance: float(),
      duration: float()
    })
  end
end
