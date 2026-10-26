# battletech_combat_helper_v2

Major upgrade from the first helper app I made (https://github.com/JCs-Personal-Projects/battletech_combat_roller).
The benefits of the first app is its simplicity, but it only saves so much time. Turns out though that in order to
save even more you basically need to make something that can track the full game state. The goal of this app
is to do just that. Has Lance building, saving, and loading as well as a gameplay manager.

In contrast to other apps that I've tried to use, this one does not try to maintain any common look-feel with the
traditional data sheets. It is being designed to run on a laptop so that there is sufficient screen real-estate, with
a custom reactive UI designed for space efficiency.

Each widget and screen is being iteratively designed with user feedback along the way from hand sketches, to concept mockups, through implementation.
Workflows are being outlined based both on the basic "this is what the rules say" as well as taking notes about what players have actually
been doing and saying when we get together to fine tune things like what information is important to see when, and what is just noise.

"Out of the box", this app will have support for the ~240+ mechs that are in the Wave One and Wave Two PDFs the Catalyst Games provides for free on
their website.

## Current Status

Building out the data backend and the Lance Builder.

## Getting Started

This project is a Flutter application that is configured for building in Linux, though it can certainly be modified for other platforms
using the Flutter CLI.

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