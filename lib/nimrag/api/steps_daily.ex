defmodule Nimrag.Api.StepsDaily do
  @behaviour Nimrag.Api.Data
  defstruct calendar_date: nil, step_goal: nil, total_distance: nil, total_steps: nil

  @impl Nimrag.Api.Data
  def from_api_response(%{"calendarDate" => calendar_date, "stepGoal" => step_goal, "totalDistance" => total_distance, "totalSteps" => total_steps}) do
    {:ok, %__MODULE__{
      calendar_date: calendar_date,
      step_goal: step_goal,
      total_distance: total_distance,
      total_steps: total_steps
    }}
  end

  def from_api_response(_), do: {:error, :invalid_response}
end
