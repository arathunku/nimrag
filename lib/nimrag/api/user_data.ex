defmodule Nimrag.Api.UserData do
  use Nimrag.Api.Data

  @type t() :: %__MODULE__{
          activity_level: nil | integer(),
          birth_date: Date.t(),
          dive_number: nil | integer(),
          external_bottom_time: nil | float(),
          first_day_of_week: any(),
          firstbeat_cycling_lt_timestamp: nil | integer(),
          firstbeat_max_stress_score: nil | float(),
          firstbeat_running_lt_timestamp: nil | integer(),
          ftp_auto_detected: nil | bool(),
          gender: String.t(),
          available_training_days: [String.t()],
          preferred_long_training_days: [String.t()],
          golf_distance_unit: String.t(),
          golf_elevation_unit: nil | String.t(),
          golf_speed_unit: nil | String.t(),
          handedness: String.t(),
          # PowerFormat
          heart_rate_format: any(),
          height: float(),
          hydration_auto_goal_enabled: bool(),
          hydration_containers: [Api.HydrationContainer.t()],
          hydration_measurement_unit: String.t(),
          intensity_minutes_calc_method: String.t(),
          lactate_threshold_heart_rate: nil | float(),
          lactate_threshold_speed: nil | float(),
          measurement_system: String.t(),
          moderate_intensity_minutes_hr_zone: integer(),
          # PowerFormat
          power_format: any(),
          threshold_heart_rate_auto_detected: bool(),
          time_format: String.t(),
          training_status_paused_date: nil | String.t(),
          vigorous_intensity_minutes_hr_zone: integer(),
          vo_2_max_cycling: nil | float(),
          vo_2_max_running: nil | float(),
          # | WeatherLocation.t()
          weather_location: any(),
          weight: nil | float()
        }

  defstruct ~w(
    activity_level
    available_training_days
    preferred_long_training_days
    birth_date
    dive_number
    external_bottom_time
    first_day_of_week
    firstbeat_cycling_lt_timestamp
    firstbeat_max_stress_score
    firstbeat_running_lt_timestamp
    ftp_auto_detected
    gender
    golf_distance_unit
    golf_elevation_unit
    golf_speed_unit
    handedness
    heart_rate_format
    height
    hydration_auto_goal_enabled
    hydration_containers
    hydration_measurement_unit
    intensity_minutes_calc_method
    lactate_threshold_heart_rate
    lactate_threshold_speed
    measurement_system
    moderate_intensity_minutes_hr_zone
    power_format # PowerFormat
    threshold_heart_rate_auto_detected
    time_format
    training_status_paused_date
    vigorous_intensity_minutes_hr_zone
    vo_2_max_cycling
    vo_2_max_running
    weather_location
    weight
  )a

  def schematic() do
    schema(__MODULE__, %{
      field(:activity_level) => nullable(int()),
      field(:birth_date) => date(),
      field(:dive_number) => nullable(int()),
      field(:available_training_days) =>
        list(oneof(["WEDNESDAY", "MONDAY", "SUNDAY", "TUESDAY", "FRIDAY", "THURSDAY", "SATURDAY"])),
      field(:preferred_long_training_days) =>
        list(oneof(["WEDNESDAY", "MONDAY", "SUNDAY", "TUESDAY", "FRIDAY", "THURSDAY", "SATURDAY"])),
      field(:external_bottom_time) => nullable(float()),
      # first_day_of_week: any(),
      field(:firstbeat_cycling_lt_timestamp) => nullable(int()),
      field(:firstbeat_max_stress_score) => nullable(float()),
      field(:firstbeat_running_lt_timestamp) => nullable(int()),
      field(:ftp_auto_detected) => nullable(bool()),
      field(:gender) => str(),
      field(:golf_distance_unit) => nullable(str()),
      field(:golf_elevation_unit) => nullable(str()),
      field(:golf_speed_unit) => nullable(str()),
      field(:handedness) => str(),
      # heart_rate_format: any(), # PowerFormat
      field(:height) => float(),
      field(:hydration_auto_goal_enabled) => bool(),
      field(:hydration_containers) => list(Api.HydrationContainer.schematic()),
      field(:hydration_measurement_unit) => str(),
      field(:intensity_minutes_calc_method) => str(),
      field(:lactate_threshold_heart_rate) => nullable(float()),
      field(:lactate_threshold_speed) => nullable(float()),
      field(:measurement_system) => str(),
      field(:moderate_intensity_minutes_hr_zone) => int(),
      # power_format: any(),
      field(:threshold_heart_rate_auto_detected) => bool(),
      field(:time_format) => str(),
      field(:training_status_paused_date) => nullable(str()),
      field(:vigorous_intensity_minutes_hr_zone) => int(),
      # field(:vo_2_max_cycling) => nullable(float()),
      # field(:vo_2_max_running) => nullable(float()),
      # weather_location: any()
      field(:weight) => nullable(float())
    })
  end
end
