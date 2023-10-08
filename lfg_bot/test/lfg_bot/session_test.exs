defmodule LfgBot.SessionTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.Session

  describe "session behavior" do
    test "distributes new players evenly into two teams when a game has not started (default waiting state)" do
      [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

      {:ok, session} =
        Ash.Changeset.new(Session)
        |> Ash.Changeset.for_create(:create)
        |> LfgSystem.create()

      assert %Session{} = session

      # ----------------

      {:ok, session} =
        Ash.Changeset.new(session)
        |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
        |> LfgSystem.update()

      %Session{teams: [%{"players" => [check_player_one]}, _]} = session
      assert check_player_one.id == user_one.id

      # ----------------

      {:ok, session} =
        Ash.Changeset.new(session)
        |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
        |> LfgSystem.update()

      %Session{teams: [_, %{"players" => [check_player_two]}]} = session
      assert check_player_two.id == user_two.id

      # ----------------

      {:ok, session} =
        Ash.Changeset.new(session)
        |> Ash.Changeset.for_update(:player_join, %{new_player: user_three})
        |> LfgSystem.update()

      %Session{teams: [%{"players" => [check_player_one, check_player_three]}, _]} = session
      assert check_player_three.id == user_three.id
    end
  end

  test "adds players to the reserve when the session is in a game" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Ash.Changeset.new(Session)
      |> Ash.Changeset.for_create(:create)
      |> LfgSystem.create()

    assert %Session{} = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: []
           } = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:start_game)
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_three})
      |> LfgSystem.update()

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
      Ash.Changeset.new(Session)
      |> Ash.Changeset.for_create(:create)
      |> LfgSystem.create()

    assert %Session{} = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: []
           } = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:start_game)
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_three})
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [check_player_three],
             state: :playing
           } = session

    assert check_player_three.id == user_three.id

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_leave, user_three)
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session
  end

  test "removes players that are on a team" do
    [user_one, user_two] = Enum.take(mock_users(), 2)

    {:ok, session} =
      Ash.Changeset.new(Session)
      |> Ash.Changeset.for_create(:create)
      |> LfgSystem.create()

    assert %Session{} = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    # start the game. currently, removing players while a game is in progress is allowed, but this could change (update this test if it doe change).
    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:start_game)
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => [check_player_one]}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_leave, user_one)
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => []}, %{"players" => [check_player_two]}],
             player_reserve: [],
             state: :playing
           } = session
  end

  test "shuffles teams and drains player reserve" do
    [user_one, user_two, user_three] = Enum.take(mock_users(), 3)

    {:ok, session} =
      Ash.Changeset.new(Session)
      |> Ash.Changeset.for_create(:create)
      |> LfgSystem.create()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:start_game)
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_three})
      |> LfgSystem.update()

    assert %Session{
             teams: [%{"players" => players_one}, %{"players" => players_two}],
             player_reserve: players_three,
             state: :playing
           } = session

    all_players_cache = Enum.concat([players_one, players_two, players_three])
    assert length(all_players_cache) == 3

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:shuffle_teams)
      |> LfgSystem.update()

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

    {:ok, session} =
      Ash.Changeset.new(Session)
      |> Ash.Changeset.for_create(:create)
      |> LfgSystem.create()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{message: message}]}} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_one})
      |> LfgSystem.update()

    assert message =~ "already in"
    assert message =~ "team"

    # ----------------

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:start_game)
      |> LfgSystem.update()

    {:ok, session} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{message: message}]}} =
      Ash.Changeset.new(session)
      |> Ash.Changeset.for_update(:player_join, %{new_player: user_two})
      |> LfgSystem.update()

    assert message =~ "already in"
    assert message =~ "reserve"
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
