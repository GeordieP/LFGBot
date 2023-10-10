defmodule LfgBot.LfgSystem.Session do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine]

  alias LfgBot.LfgSystem
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

    # ID of the game control message
    attribute :message_id, :string do
      allow_nil?(false)
    end

    # ID of the channel the control message is in
    attribute :channel_id, :string do
      allow_nil?(false)
    end

    # ID of the guild the control channel is in
    attribute :guild_id, :string do
      allow_nil?(false)
    end

    # ID of the user who's controlling the group
    attribute :leader_user_id, :string do
      allow_nil?(false)
    end

    # name of the user who's controlling the group (used for displaying the message)
    attribute :leader_user_name, :string do
      allow_nil?(false)
    end

    # holds players that have joined while a game is in progress
    # players in the reserve will be mixed into the teams on the next shuffle
    attribute :player_reserve, {:array, :map} do
      default([])
    end

    # two teams of players. players are nostrum user structs
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

  code_interface do
    define_for(LfgSystem)
    define(:new, action: :create)
    define(:player_join, action: :player_join, args: [:new_player])
    define(:player_leave, action: :player_leave, args: [:player_id])

    define(:start_game, action: :start_game, args: [:invoker_user_id])
    define(:end_game, action: :end_game, args: [:invoker_user_id])
    define(:shuffle_teams, action: :shuffle_teams, args: [:invoker_user_id])
    define(:terminate_session, action: :terminate_session, args: [:invoker_user_id])
  end

  actions do
    defaults([:create, :read])

    update :start_game do
      argument :invoker_user_id, :string do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        invoker_user_id = Ash.Changeset.get_argument(changeset, :invoker_user_id)
        leader_user_id = Ash.Changeset.get_attribute(changeset, :leader_user_id)

        if invoker_user_id == leader_user_id do
          Ash.Changeset.change_attribute(changeset, :state, :playing)
        else
          Ash.Changeset.add_error(
            changeset,
            "only the session leader can perform this action"
          )
        end
      end)
    end

    update :end_game do
      argument :invoker_user_id, :string do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        invoker_user_id = Ash.Changeset.get_argument(changeset, :invoker_user_id)
        leader_user_id = Ash.Changeset.get_attribute(changeset, :leader_user_id)

        if invoker_user_id == leader_user_id do
          Ash.Changeset.change_attribute(changeset, :state, :waiting)
        else
          Ash.Changeset.add_error(changeset, "only the session leader can perform this action")
        end
      end)
    end

    update :terminate_session do
      argument :invoker_user_id, :string do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        invoker_user_id = Ash.Changeset.get_argument(changeset, :invoker_user_id)
        leader_user_id = Ash.Changeset.get_attribute(changeset, :leader_user_id)

        if invoker_user_id == leader_user_id do
          Ash.Changeset.change_attribute(changeset, :state, :ended)
        else
          Ash.Changeset.add_error(changeset, "only the session leader can perform this action")
        end
      end)
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
      argument :player_id, :string do
        allow_nil?(false)
      end

      change(fn changeset, _ ->
        player_id = Ash.Changeset.get_argument(changeset, :player_id)
        Utils.remove_player(changeset, player_id)
      end)
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

    if state in [:ended, :error] do
      changeset
    else
      player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
      teams = Ash.Changeset.get_attribute(changeset, :teams)

      player_from_reserve = Enum.find(player_reserve, nil, &(&1.id == new_player.id))

      player_from_team =
        Enum.find_value(teams, nil, fn
          [] ->
            nil

          %{"players" => players} ->
            Enum.find(players, nil, fn
              %{"id" => id} -> id
              %{id: id} -> id
            end)
        end)

      cond do
        player_from_reserve != nil ->
          Ash.Changeset.add_error(changeset, "player is already in the reserve list")

        player_from_team != nil ->
          Ash.Changeset.add_error(changeset, "player is already in a team")

        state == :playing ->
          # a game is in progress, add the new player to the reserve list
          new_player_reserve = [new_player | player_reserve]
          Ash.Changeset.change_attribute(changeset, :player_reserve, new_player_reserve)

        state == :waiting ->
          # add new player to whichever team has fewer players, or the first team by default
          # NOTE: assume two teams for now
          [team_one, team_two] = teams

          %{"players" => players_one} = team_one
          %{"players" => players_two} = team_two

          if length(players_one) > length(players_two) do
            new_team_two = Map.put(team_two, "players", Enum.reverse([new_player | players_two]))
            Ash.Changeset.change_attribute(changeset, :teams, [team_one, new_team_two])
          else
            new_team_one = Map.put(team_one, "players", Enum.reverse([new_player | players_one]))
            Ash.Changeset.change_attribute(changeset, :teams, [new_team_one, team_two])
          end

        true ->
          changeset
      end
    end
  end

  def remove_player(changeset, player_id) do
    state = Ash.Changeset.get_attribute(changeset, :state)

    if state in [:ended, :error] do
      changeset
    else
      [team_one, team_two] = Ash.Changeset.get_attribute(changeset, :teams)

      %{"players" => players_one} = team_one
      %{"players" => players_two} = team_two

      match_player = fn
        %{"id" => id} -> id == player_id
        %{id: id} -> id == player_id
      end

      players_one = Enum.reject(players_one, &match_player.(&1))
      players_two = Enum.reject(players_two, &match_player.(&1))

      team_one = Map.put(team_one, "players", players_one)
      team_two = Map.put(team_two, "players", players_two)

      player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
      player_reserve = Enum.reject(player_reserve, &match_player.(&1))

      changeset
      |> Ash.Changeset.change_attribute(:teams, [team_one, team_two])
      |> Ash.Changeset.change_attribute(:player_reserve, player_reserve)
    end
  end

  def shuffle_teams(changeset) do
    state = Ash.Changeset.get_attribute(changeset, :state)

    if state in [:ended, :error] do
      changeset
    else
      player_reserve = Ash.Changeset.get_attribute(changeset, :player_reserve)
      [team_one, team_two] = Ash.Changeset.get_attribute(changeset, :teams)

      %{"players" => players_one} = team_one
      %{"players" => players_two} = team_two

      all_players = Enum.concat([player_reserve, players_one, players_two])

      IO.puts("before")
      IO.inspect({players_one, players_two})

      {players_two, players_one} =
        all_players
        |> Enum.shuffle()
        |> Enum.split(Kernel.trunc(length(all_players) / 2))

      IO.puts("after")
      IO.inspect({players_one, players_two})

      team_one = Map.put(team_one, "players", players_one)
      team_two = Map.put(team_two, "players", players_two)

      changeset
      |> Ash.Changeset.change_attribute(:teams, [team_one, team_two])
      |> Ash.Changeset.change_attribute(:player_reserve, [])
    end
  end
end
