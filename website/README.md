# Website

This is the TypeScript Astro catalog for the patch stacks. It runs with
the Astro Node adapter and reads `../stacks/` at request time. Pages and
JSON endpoints share `src/lib/catalog.ts`; no catalog source or data
file is generated during the build.

Run it locally with:

```sh
npm ci
npm run dev
```

Build and run the production server with:

```sh
npm run build
npm start
```

The application requires Node.js 26.7.0. `PATCHES_STACKS` can point to
an alternate stack directory; `HOST` and `PORT` configure the server.
GitHub Actions checks the server bundle and runtime routes. Deployment
requires a Node host because runtime discovery is not compatible with a
static GitHub Pages artifact.
