# Channel Registration Sequence

> [!NOTE]
> This diagram illustrates how we register a Discord channel with the bot.
> 
> The registration process creates a 'control message' in the channel - a persistent message containing usage instructions and a button to create a new group.
> 
> All registration message IDs are stored alongside their guild ID in the database, so if we ever need to change the usage instructions or 'create group' button's functionality, it's possible to send discord `edit message` commands to update them no matter what server or channel they're in.
> 
> We take precautions to only register a channel once, so we don't end up with more than one control message, even if the registration command is run again.


```mermaid
sequenceDiagram
autonumber

actor USER
participant DISCORD
participant CONSUMER
participant HANDLERS
participant DATABASE

USER--)CONSUMER: Run CMD /lfginit
CONSUMER->>HANDLERS: InteractionHandlers<br/>.register_channel()
Note over HANDLERS: {guild_id, channel_id}
HANDLERS->>DATABASE: find existing OR create<br /> RegisteredGuildChannel
DATABASE-->>HANDLERS: ok
Note right of HANDLERS: %RegisteredGuildChannel{id: reg_id}
Note left of DISCORD: User waits while the bot is<br />creating a control message <br />and storing its ID.
HANDLERS->>DISCORD: Send new registration msg<br/>(interaction response)
activate DISCORD
Note left of DISCORD: We need the ID of this registration msg,<br/>but Api.create_interaction_response()<br/>doesn't return us a msg ID.
Note left of DISCORD: Instead our response sends<br />an ID string:
Note over DISCORD: id_string = "LFGREG:" <> reg_id
Note left of DISCORD: then we match <br/>on it in a msg handler,<br/>store that msg ID, and finally, <br/>edit the msg to show instructions.
DISCORD--)CONSUMER: Recv new registration msg
Note over CONSUMER: {"LFGREG:" <> reg_id, message_id} = msg
CONSUMER->>HANDLERS: MessageHandlers<br/>.registration_message()
Note over HANDLERS: {reg_id, channel_id, message_id}
HANDLERS->>DATABASE: update RegisteredGuildChannel<br />(store message_id)
DATABASE-->>HANDLERS: ok
HANDLERS->>DISCORD: Edit registration message (message_id)
Note over DISCORD: Instructions &<br/>Control Buttons ✅
deactivate DISCORD
Note left of DISCORD: The channel is registered.
Note left of DISCORD: The user can now<br />start a game session.
```
