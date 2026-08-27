import type { APIRoute } from 'astro';
import { loadCatalog } from '../lib/catalog.ts';

export const GET = (async () => {
  const catalog = await loadCatalog();
  return Response.json(catalog.stacks.map(({ id }) => id));
}) satisfies APIRoute;
