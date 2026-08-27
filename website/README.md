# Website

This is the static TypeScript Astro catalog for the patch stacks. The
build reads `../stacks/` and generates the HTML and JSON routes in
`dist/`. Pages and JSON endpoints share `src/lib/catalog.ts`.

Run it locally with:

```sh
npm ci
npm run dev
```

Build and preview the production site with:

```sh
npm run build
npm run preview
```

The build requires Node.js 26.7.0. `PATCHES_STACKS` can point to an
alternate stack directory. GitHub Actions validates the generated site
and publishes it to GitHub Pages.
