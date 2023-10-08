defmodule LfgBot.LfgSystem.Session do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  alias LfgBot.LfgSystem.Session.Utils

  postgres do
    table("sessions")
    repo(LfgBot.Repo)
  end

  attributes do
    # there's also an implicit :state attribute, added by ash_state_machine
    uuid_primary_key(:id)
    attribute(:error, :string)
    attribute(:error_state, :string)

    attribute :player_reserve, {:array, :map} do
      default([])
    end

    attribute :teams, {:array, :map} do
      default([%{"players" => []}, %{"players" => []}])
    end
  end

  state_machine do
    initial_states([:waiting])
    default_initial_state(:waiting)

    transitions do
      transition(:start_game, from: :waiting, to: :playing)
      transition(:end_game, from: :playing, to: :waiting)
      transition(:terminate_session, from: [:waiting, :playing], to: :ended)
      transition(:error, from: [:waiting, :playing, :ended], to: :error)
    end
  end

  actions do
    defaults([:create, :read])

    update :start_game do
      change(transition_state(:playing))
    end

    update :end_game do
      change(transition_state(:waiting))
    end

    update :terminate_session do
      change(transition_state(:ended))
    end

    update :error do
      accept([:error_state, :error])
      change(transition_state(:error))
    end

    update :player_join do
      argument :new_player, :map do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        new_player = Ash.Changeset.get_argument(changeset, :new_player)
        Utils.add_player(changeset, new_player)
      end)
    end

    update :player_leave do
      argument :id, :string do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        id = Ash.Changeset.get_argument(changeset, :id)
        Utils.remove_player(changeset, id)
      end)

      # TODO: remove player from reserve if they're in there
      # TODO: remove player from teams if they're in there
    end

    update :shuffle_teams do
      change(fn changeset, _ ->
        Utils.shuffle_teams(changeset)
      end)
    end
  end
end

defmodule LfgBot.LfgSystem.Session.Utils do
  def add_player(changeset, new_player) do
    state = Ash.Changeset.get_attribute(changeset, :state)
    player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
    teams = Ash.Changeset.get_attribute(changeset, :teams)

    player_from_reserve = Enum.find(player_reserve, nil, &(&1.id == new_player.id))

    player_from_team =
      Enum.find_value(teams, nil, fn
        [] ->
          nil

        %{"players" => players} ->
          Enum.find(players, nil, &(&1.id == new_player.id))
      end)

    cond do
      player_from_reserve != nil ->
        Ash.Changeset.add_error(changeset, "player is already in the reserve list")

      player_from_team != nil ->
        Ash.Changeset.add_error(changeset, "player is already in a team")

      true ->
        case state do
          :playing ->
            # a game is in progress, add the new player to the reserve list
            new_player_reserve = [new_player | player_reserve]

            changeset =
              Ash.Changeset.change_attribute(changeset, :player_reserve, new_player_reserve)

            changeset

          :waiting ->
            # add new player to whichever team has fewer players, or the first team by default
            # NOTE: assume two teams for now
            [team_one, team_two] = teams

            %{"players" => players_one} = team_one
            %{"players" => players_two} = team_two

            if length(players_one) > length(players_two) do
              # second list is shorter; add to that
              new_team_two =
                Map.put(team_two, "players", Enum.reverse([new_player | players_two]))

              Ash.Changeset.change_attribute(changeset, :teams, [team_one, new_team_two])
            else
              # add to the first list
              new_team_one =
                Map.put(team_one, "players", Enum.reverse([new_player | players_one]))

              Ash.Changeset.change_attribute(changeset, :teams, [new_team_one, team_two])
            end

          _ ->
            changeset
        end
    end
  end

  def remove_player(changeset, player_id) do
    [team_one, team_two] = Ash.Changeset.get_attribute(changeset, :teams)

    %{"players" => players_one} = team_one
    %{"players" => players_two} = team_two

    players_one = Enum.reject(players_one, &(&1.id == player_id))
    players_two = Enum.reject(players_two, &(&1.id == player_id))
    team_one = Map.put(team_one, "players", players_one)
    team_two = Map.put(team_two, "players", players_two)

    player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
    player_reserve = Enum.reject(player_reserve, &(&1.id == player_id))

    changeset
    |> Ash.Changeset.change_attribute(:teams, [team_one, team_two])
    |> Ash.Changeset.change_attribute(:player_reserve, player_reserve)
  end

  def shuffle_teams(changeset) do
    player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
    [team_one, team_two] = Ash.Changeset.get_attribute(changeset, :teams)

    %{"players" => players_one} = team_one
    %{"players" => players_two} = team_two

    all_players = Enum.concat([player_reserve, players_one, players_two])

    {players_two, players_one} =
      all_players
      |> Enum.shuffle()
      |> Enum.split(Kernel.trunc(length(all_players) / 2))

    team_one = Map.put(team_one, "players", players_one)
    team_two = Map.put(team_two, "players", players_two)

    changeset
    |> Ash.Changeset.change_attribute(:teams, [team_one, team_two])
    |> Ash.Changeset.change_attribute(:player_reserve, [])
  end
end
