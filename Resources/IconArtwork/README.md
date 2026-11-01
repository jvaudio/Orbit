# Orbit icon

The orbital loop represents the app as a shared home; its three rounded-square modules represent independently enabled tools. It deliberately has no pointer, mouse, or magnifier, so the identity fits future utilities.

## Production files

- `../Orbit.icon/icon.json`: editable native Icon Composer document, based on a document created and saved in Apple's app.
- `../Orbit.icon/Assets/OrbitRing.svg` and `OrbitTools.svg`: clean vector foreground layers. Foreground tool modules sit above the ring; Apple's material settings add glass and depth.
- `OrbitRing.svg` and `OrbitTools.svg`: standalone source artwork.
- `Orbit-Preview.png` and `Orbit-Dark-Preview.png`: default/dark macOS renders exported with design generation 27.

The blue base uses Icon Composer's automatic gradient. The asset compiler emits the layered asset catalog and a compatibility `.icns`; the preview PNGs are documentation, not the app's runtime icon source.

## Concept process

Two drafts were generated with the built-in image-generation tool. They established the ring-and-modules direction, but their alpha edges were unsuitable for a production icon. The final layers were newly authored as clean SVG geometry; the generated bitmaps are not shipped in Orbit.

Initial prompt:

> Use case: logo-brand. Asset type: transparent foreground artwork for a native layered macOS 27 app icon, not a finished app-icon tile. Create the distinctive mark for Orbit, a collection of independent Mac productivity utilities. A bold, simple circular orbital loop forming an O, with three rounded-square tool modules integrated along the loop at balanced positions, suggesting useful tools gathered into one coherent system. Use a clean geometric silhouette with generous negative space, recognizable at 32px. Front-on orthographic view. The mark occupies roughly the central 65% of a square 1024 by 1024 canvas. Pure white and very pale icy blue solid shapes; subtly differentiated modules; crisp antialiased edges. Mostly flat artwork, because Apple's native icon renderer will add glass, lighting, and depth later. Transparent background across the entire canvas outside the mark and inside its open spaces. No app-tile background, no rounded-square enclosing tile, no text, no letters, no mouse, no cursor, no magnifier, no wrench, no gear, no stars, no sparkles, no shadows or glows baked into the transparent canvas. One polished, original mark, not a sheet of alternatives.

Refinement prompt:

> Refine this transparent icon foreground for production. Keep exactly the same circular orbital loop and three rounded-square modules, their placement, scale, and negative space. Change only the edge quality and flatness of the artwork: perfectly smooth vector-like contours, crisp antialiasing, absolutely no irregular bumps, speckles, halos, isolated pixels, rough texture, or shadows. Use a pure white solid silhouette for all connected shapes, without internal gradients or lighting. Preserve genuinely transparent background outside the mark and inside its open center. Do not add a background tile, text, other shapes, depth, highlights, or perspective. This is a clean alpha-mask foreground for Apple's Icon Composer to materialize as glass.
