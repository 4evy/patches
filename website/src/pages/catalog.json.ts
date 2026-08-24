import type { APIRoute } from 'astro';
import { loadCatalog } from '../lib/catalog.ts';

export const GET = (async () =>
  Response.json(await loadCatalog())) satisfies APIRoute;
