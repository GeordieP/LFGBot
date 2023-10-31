# 🎮 LFG Bot 🤖

###### LFG = "Looking For Group" or "Looking For Game"

> A Discord bot for organizing in-house 5v5 matches of Counter-Strike, Valorant, Overwatch, etc

One user starts a group, and 9 other users click the "join" button to be placed on a team.

Teams are shown in the bot's message, and can be shuffled by the group leader.

## Screenshots

**Startup Message**

![the discord bot's startup message, with a button underneath labelled 'new group'](assets/init_msg.png)

**Empty Teams**

![a discord message showing a group with two empty teams, and buttons to leave/join or control the session underneath](assets/group_msg_empty.png)

**Full Teams**

![a discord message showing a group with 10 players split between two teams, and buttons to leave/join or control the session underneath](assets/group_msg_full.png)

## Dev & Contributing

Project is open for contributions!

The bot is written in [Elixir](https://elixir-lang.org) and uses the [Nostrum](https://github.com/Kraigie/nostrum) library to interact with Discord.

The core data layer is using the [Ash](https://github.com/ash-project/ash) framework and is backed by a [PostgreSQL](https://www.postgresql.org) database (definitely overkill, but the official Ash SQLite integration wasn't available yet!).

The production instance is deployed on [Fly.io](https://fly.io).

<details>
  <summary>
    Things you'll need in order to contribute
  </summary>

- Elixir
  - [https://elixir-lang.org](https://elixir-lang.org)
  - I'm using version 1.15 with Erlang/OTP 26
- A PostgreSQL database
  - [https://www.postgresql.org](https://www.postgresql.org)
  - If you have docker, there's a `docker-compose` file in this repository which will run a dev database for you. Find it at [lfg_bot_pgsql/docker-compose.yml](lfg_bot_pgsql/docker-compose.yml)
- A Discord developer app for testing your changes locally
  - Learn about app development [here](https://discord.com/developers/docs/getting-started)
  - Create an app [here](https://discord.com/developers/applications?new_application=true)
- An environment variable on your system called `LFG_NOSTRUM_TOKEN`
  - Once you've made an app in the Discord developer portal (see section above), you can get your token from the settings page in the "Bot" section, under the "Build-A-Bot" header.
  - Copy the token and set yourself an environment variable named `LFG_NOSTRUM_TOKEN`
  - Keep your token secret!
- A Discord server for testing your changes
  - It's recommended to use a personal server for this, just in case
  - Once you've made an app in the Discord developer portal (see section above), you can add that bot to your server by:
    - Getting your client ID from the `OAuth2` section
    - Substituting your client ID in this URL: `https://discord.com/api/oauth2/authorize?client_id=<YOUR_CLIENT_ID_HERE>&permissions=53687158848&scope=bot`
      - (Permissions code last updated Oct 26 2023 // [permissions calculator](https://discordapi.com/permissions.html#53687158848))
    - Opening that URL in your browser

Unless I've missed something, after all this, you should be able to run the elixir application and interact with the bot in your testing server.

</details>

---

#### Repo Points of Interest

- [lib/lfg_bot/discord/consumer.ex](lfg_bot/lib/lfg_bot/discord/consumer.ex)
  - The module that listens for Discord events and sends them over to domain-specific handler functions
- [lib/lfg_bot/discord/interaction_handlers.ex](lfg_bot/lib/lfg_bot/discord/interaction_handlers.ex)
  - Handlers for [Discord Interactions](https://discord.com/developers/docs/interactions/receiving-and-responding#interactions) (button clicks etc)
- [lib/lfg_bot/discord/message_handlers.ex](lfg_bot/lib/lfg_bot/discord/message_handlers.ex)
  - Handlers for Discord messages
  <!-- TODO: write a section on the weird channel registration flow driven by a message handler -->
- [lib/lfg_bot/lfg_system/resources/registered_guild_channel.ex](lfg_bot/lib/lfg_bot/lfg_system/resources/registered_guild_channel.ex)
  - `RegisteredGuildChannel` database model
  - Represents a Discord server & channel wherein the bot can be controlled
- [lib/lfg_bot/lfg_system/resources/session.ex](lfg_bot/lib/lfg_bot/lfg_system/resources/session.ex)
  - `Session` database model
  - Represents a group/session and stores the team player lists

---

#### Diagrams

[tldraw file](assets/tldraw_pages.tldr)

<details>
  <summary>
    Channel registration flow
  </summary>

![Channel registration flow](assets/channel_registration_flow.svg)
[Channel registration flow](assets/channel_registration_flow.svg)

</details>

<details>
  <summary>
    Group setup flow
  </summary>

![Group setup flow](assets/group_setup_flow.svg)
[Group setup flow](assets/group_setup_flow.svg)

</details>

<details>
  <summary>
    Player kick flow
  </summary>

![Player kick flow](assets/player_kick_flow.svg)
[Player kick flow](assets/player_kick_flow.svg)

</details>
