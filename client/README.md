# battletech_client

The phone web client for Combat Helper. The desktop app serves this app over its hotspot at `/player/N`. Each page reads its
player number from the URL and opens a WebSocket back to the server (`/ws/player/N`). The client and server share the protocol
in `packages/battletech_logic`.

Build it with `../scripts/build_client.sh`. The desktop app serves the output in `build/web`.

To work on the UI with `flutter run -d chrome`, pass the player and a running server's address in the query:
`?player=1&server=10.42.0.1:8080`.

Roboto is bundled in `fonts/` because Flutter Web would otherwise download it, and phones on the hotspot have no internet.
