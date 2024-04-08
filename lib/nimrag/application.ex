defmodule Nimrag.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    hammer_opts =
      Application.get_env(:nimrag, :hammer,
        nimrag:
          {Hammer.Backend.ETS,
           [
             expiry_ms: 60_000 * 60 * 2,
             cleanup_interval_ms: 60_000 * 2
           ]}
      )

    hammer =
      if Application.get_env(:hammer, :backend) in [[], nil] do
        Application.put_env(:hammer, :backend, hammer_opts)

        [
          %{
            id: Hammer.Supervisor,
            start: {Hammer.Supervisor, :start_link, [hammer_opts, [name: Hammer.Supervisor]]}
          }
        ]
      else
        []
      end

    children = [] ++ hammer

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
