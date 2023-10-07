defmodule LfgBot.LfgSystem.Session do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  postgres do
    table "sessions"
    repo LfgBot.Repo
  end

  state_machine do
    initial_states [:waiting]
    default_initial_state :waiting

    transitions do
      transition :start_game, from: :waiting, to: :playing
      transition :end_game, from: :playing, to: :waiting
      transition :terminate_session, from: [:waiting, :playing], to: :ended
      transition :error, from: [:waiting, :playing, :ended], to: :error
    end

    actions do
      defaults [:create, :read]

      update :start_game do
        change transition_state(:playing)
      end

      update :end_game do
        change transition_state(:waiting)
      end

      update :terminate_session do
        change transition_state(:ended)
      end

      update :error do
        accept [:error_state, :error]
        change transition_state(:error)
      end

      update :player_join do
        # TODO: add player to reserve
      end

      update :player_leave do
        # TODO: remove player from reserve if they're in there
        # TODO: remove player from teams if they're in there
      end

      update :shuffle_players do
        # TODO: NOOP unless state == :waiting
        # TODO: combine: [existing players on team A, existing players on team B, players in reserve] into one list
        # TODO: shuffle the composite list
        # TODO: split the composite list into new team A, new team B
        # TODO: save the new teams (and now-empty reserve list) in changeset
      end
    end

    attributes do
      # there's also an implicit :state attribute, added by ash_state_machine
      uuid_primary_key :id
      attribute :error, :string
      attribute :error_state, :string
      attribute :player_reserve, {:array, :map}
      attribute :teams, {:array, :map}
    end
  end
end
