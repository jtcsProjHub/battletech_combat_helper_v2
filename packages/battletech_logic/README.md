# battletech_logic

Pure Dart code shared by the desktop game server (the root app) and the phone
web client (`client/`). It must compile for both the Dart VM and the web: no
Flutter, `dart:io`, `dart:html`, or `dart:ui`.

For now it holds only the client/server protocol (`lib/net/client_protocol.dart`).
The game models and rules move here as the logic split continues.

Run the tests with `dart test`.
