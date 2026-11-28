# battletech_combat_helper_v2

Major upgrade from the first helper app I made (https://github.com/JCs-Personal-Projects/battletech_combat_roller).
The benefits of the first app is its simplicity, but it only saves so much time. Turns out though that in order to
save even more you basically need to make something that can track the full game state. The goal of this app
is to do just that. Has Lance building, saving, and loading as well as a gameplay manager.

In contrast to other apps that I've tried to use, this one does not try to maintain any common look-feel with the
traditional data sheets. It is being designed to run on a laptop so that there is sufficient screen real-estate, with
a custom reactive UI designed for space efficiency.

During play the laptop acts as a game server. It shows the high-level game state and turn information, and switches to
hotspot mode so players can connect their phones. Each player uses a Flutter Web client served by the laptop for their own inputs
and detailed lance information. Clients don't load, save, or edit game data; that all stays on the laptop.

To support this, the game logic (models, serialization, and rules) is being split from the UI into its own pure Dart package that both
the server app and the web client can use.

Each widget and screen is being iteratively designed with user feedback along the way from hand sketches, to concept mockups, through implementation.
Workflows are being outlined based both on the basic "this is what the rules say" as well as taking notes about what players have actually
been doing and saying when we get together to fine tune things like what information is important to see when, and what is just noise.

"Out of the box", this app will have support for the ~240+ mechs that are in the Wave One and Wave Two PDFs the Catalyst Games provides for free on
their website.

## Current Status

Lance Builder, Map Builder, and skirmish setup are in place. Next up is splitting the game logic into a pure Dart package
in preparation for the server and phone client design.

## Getting Started

This project is a Flutter application that is configured for building in Linux, though it can certainly be modified for other platforms
using the Flutter CLI.

To build on Linux, follow Flutter's [Linux desktop setup](https://docs.flutter.dev/platform-integration/linux/setup), then also install
the LLVM linker that matches your clang version (for clang 18 on Ubuntu, `sudo apt install lld-18`). Some dependencies have native build
hooks, and without the linker the build fails with `Failed to find any of [ld.lld, ld]`. The linker is only needed to build the app,
not to run a build.

Saved lances are JSON files in `~/.local/share/io.github.jcs_personal_projects.battletech_combat_helper/lances/`, one file per lance.
The folder name comes from `APPLICATION_ID` in `linux/CMakeLists.txt`, so changing that ID moves where the app looks for saved lances.

### Hosting a game (phone client)

The repository holds three Dart projects:

- The root app: the desktop game server.
- `client/`: the Flutter Web app the players open on their phones.
- `packages/battletech_logic/`: pure Dart code shared by both.

Build the phone client before you start a game with `scripts/build_client.sh`. The script writes the build to
`client/build/web`, and the desktop app serves it from there. Rebuild it after any change in `client/` or the shared package.
The build uses `--no-web-resources-cdn` because phones on the hotspot have no internet access.

Starting a game turns on the NetworkManager hotspot profile `BattleTech-Hotspot`. The client is served on port 8080, so that
port must be open in the firewall (`sudo ufw allow 8080/tcp`).

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supporting tools and scripts

I wasn't able to find any digital datasets that had all of the mech data for use in a program, and the MUL database is centered around Alpha Strike.
Since the Wave One and Wave Two data sheets have no copyable text in them, I developed an OCR program along with what ended up being a series of helper
scripts to help with the iterative cleanup of the OCR errors. For all of the "why don't you just have AI pull out the data" people, that was my first
try just to see what it would do. It was...not great. Although well structured, the positions of things on the pages are kind of all over the place
if you view it as a standard document. I ended up using fairly tightly aimed ROI bounding boxes to target pieces of data while trying to avoid
as much random non-character bits as possible. I've done this before on a number of other things and it tends to work rather well.

What you'll see though in extract_mech_data.py is something even more complicated because Wave One and Wave Two are formatted slightly differently. And
it's not just a cropping or scaling difference. Well, it is but only for parts of the page. There's enough structure in there now to support other data sheet
variations without as much annoying setup.

If you try to use these yourself, you'll want to also use a PDF splitter and JUST feed in the mech pages. Also, expect at least one OCR error per mech. So you'll
want to be patient. And no, "AI" doesn't "just know" all of the mech specs to clean it up for you.

There is also a script for pulling data from a saved MUL page for a mech of interest, which I used for some data validation cross referencing as well as
getting the era and faction availability data. That wasn't part of my initial design, but one of my friends who has played a bunch flagged that data as being
something he and his play group would expect in the Lance builder.