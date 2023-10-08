defmodule LfgBot.SessionTest do
  use LfgBot.DataCase

  alias LfgBot.LfgSystem
  alias LfgBot.LfgSystem.Session

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

  describe "todo rename this test" do
    # TODO: create a session
    # TODO: add some players
    # TODO: shuffle players, check output is different every time
    # TODO: remove some players, check they're gone
    # TODO: shuffle players, check removed players are gone

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

  def mock_player(username) do
    %{
      id: gen_id(),
      username: username,
      bot: false
    }
  end

  #  def gen_name do
  #    timestamp = DateTime.now!() |> DateTime.to_unix()
  #    "user_#{timestamp}"
  #  end

  def gen_id do
    Ecto.UUID.generate()
  end
end
