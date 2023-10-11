defmodule LfgBot.SessionTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.Session

  test "distributes new players evenly into two teams when a game has not started (default waiting state)" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    assert %Session{} = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_one)

    %Session{teams: [%{"players" => [check_player_one]}, _]} = session
    assert check_player_one.id == user_one.id

    # ----------------

    {:ok, session} = Session.player_join(session, user_two)

    %Session{teams: [_, %{"players" => [check_player_two]}]} = session
    assert check_player_two.id == user_two.id

    # ----------------

    {:ok, session} = Session.player_join(session, user_three)
    %Session{teams: [%{"players" => [check_player_one, check_player_three]}, _]} = session
    assert check_player_three.id == user_three.id
  end

  test "adds players to the reserve when the session is in a game" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    assert %Session{} = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_one)
    {:ok, session} = Session.player_join(session, user_two)

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: []
           } = session

    # ----------------

    {:ok, session} = Session.start_game(session, "leader_user_id")

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_three)

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [check_player_three],
             state: :playing
           } = session

    assert check_player_three.id == user_three.id
  end

  test "removes players that are in the reserve" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    assert %Session{} = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_one)
    {:ok, session} = Session.player_join(session, user_two)

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: []
           } = session

    # ----------------

    {:ok, session} = Session.start_game(session, "leader_user_id")

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_three)

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [check_player_three],
             state: :playing
           } = session

    assert check_player_three.id == user_three.id

    # ----------------

    {:ok, session} = Session.player_leave(session, user_three.id)

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session
  end

  test "removes players that are on a team" do
    [user_one, user_two] = Enum.take(mock_users(), 2)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    assert %Session{} = session

    # ----------------

    {:ok, session} = Session.player_join(session, user_one)
    {:ok, session} = Session.player_join(session, user_two)

    # start the game. currently, removing players while a game is in progress is allowed, but this could change (update this test if it doe change).
    {:ok, session} = Session.start_game(session, "leader_user_id")

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} = Session.player_leave(session, user_one.id)

    assert %Session{
             teams: [%{"players" => []}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session
  end

  test "shuffles teams and drains player reserve" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    {:ok, session} = Session.player_join(session, user_one)
    {:ok, session} = Session.player_join(session, user_two)
    {:ok, session} = Session.start_game(session, "leader_user_id")

    {:ok, session} = Session.player_join(session, user_three)

    assert %Session{
             teams: [%{"players" => players_one}, %{"players" => players_two}],
             player_reserve: players_three,
             state: :playing
           } = session

    all_players_cache = Enum.concat([players_one, players_two, players_three])
    assert length(all_players_cache) == 3

    {:ok, session} = Session.shuffle_teams(session, "leader_user_id")

    assert %Session{
             teams: [%{"players" => players_one}, %{"players" => players_two}],
             player_reserve: [],
             state: :playing
           } = session

    shuffled_all_players = Enum.concat([players_one, players_two])
    assert length(all_players_cache) == 3
    # TODO:
    # TODO:
    # TODO: this test can fail randomly since the new result can end up the same as the original
    # TODO: how can we properly test that this is attempting to shuffle?
    # TODO:
    # TODO:
    # assert shuffled_all_players != all_players_cache
  end

  test "prevents one user from joining more than once" do
    [user_one, user_two] = Enum.take(mock_users(), 2)

    # ----------------
    # test adding a duplicate user BEFORE the game has been started (state is :waiting)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    {:ok, session} = Session.player_join(session, user_one)

    {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{message: message}]}} =
      Session.player_join(session, user_one)

    assert message =~ "already in"
    assert message =~ "team"

    # ----------------
    # test adding a duplicate user BEFORE the game has been started (state is :playing)

    {:ok, session} = Session.start_game(session, "leader_user_id")
    {:ok, session} = Session.player_join(session, user_two)

    {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{message: message}]}} =
      Session.player_join(session, user_two)

    assert message =~ "already in"
    assert message =~ "reserve"
  end

  test "prevents non-leader user from shuffling teams" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Session.new(%{
        message_id: "fake_message_id",
        channel_id: "fake_channel_id",
        guild_id: "guild_id",
        leader_user_id: "leader_user_id",
        leader_user_name: "leader_user_name"
      })

    {:ok, session} = Session.player_join(session, user_one)
    {:ok, session} = Session.player_join(session, user_two)
    {:ok, session} = Session.player_join(session, user_three)
    {:error, %Ash.Error.Invalid{errors: errors}} = Session.shuffle_teams(session, user_two.id)
    %Ash.Error.Changes.InvalidChanges{message: message} = Enum.at(errors, 0)
    assert message =~ "perform this action"
  end

  def mock_users do
    [
      mock_player("user_one"),
      mock_player("user_two"),
      mock_player("user_three"),
      mock_player("user_four"),
      mock_player("user_five"),
      mock_player("user_six"),
      mock_player("user_seven"),
      mock_player("user_eight"),
      mock_player("user_nine"),
      mock_player("user_ten")
    ]
  end

  def mock_player(username) do
    %{
      id: gen_id(),
      username: username,
      bot: false
    }
  end

  def gen_id do
    Ecto.UUID.generate()
  end
end
