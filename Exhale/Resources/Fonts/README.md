# Fonts

Space Grotesk and Archivo ship from Google Fonts as **variable** fonts whose
named instances expose no usable PostScript names — `Font.custom("SpaceGrotesk-Bold")`
would silently fall back to the system face, which is the worst kind of failure
because it looks almost right.

So the static faces here are generated from the upstream variable fonts with
`fontTools.varLib.instancer`, pinned to single weights, with the name tables
rewritten so each face is independently addressable:

| file | wght | PostScript name |
|---|---|---|
| SpaceGrotesk-Regular.ttf | 400 | `SpaceGrotesk-Regular` |
| SpaceGrotesk-Medium.ttf | 500 | `SpaceGrotesk-Medium` |
| SpaceGrotesk-Bold.ttf | 700 | `SpaceGrotesk-Bold` |
| Archivo-Regular.ttf | 400 | `Archivo-Regular` |
| Archivo-Medium.ttf | 500 | `Archivo-Medium` |
| Archivo-SemiBold.ttf | 600 | `Archivo-SemiBold` |
| ArchivoBlack-Regular.ttf | — | `ArchivoBlack-Regular` (upstream static, unmodified) |

Each face uses the non-RIBBI convention (its own family name, subfamily
"Regular") so iOS addresses it directly rather than through style linking.

All are SIL Open Font License 1.1 — see OFL.txt. Neither family declares a
Reserved Font Name, so instancing and renaming is permitted; derived files
remain under OFL.

`FontTests.testEveryCustomFontResolves` fails the build if a name stops
matching.
