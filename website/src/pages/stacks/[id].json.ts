import type { APIRoute } from 'astro';
import { loadCatalog } from '../../lib/catalog.ts';
import type { Stack } from '../../types.ts';

export async function getStaticPaths() {
  const catalog = await loadCatalog();
  return catalog.stacks.map((stack) => ({
    params: { id: stack.id },
    props: { stack },
  }));
}

export const GET = (({ props }) =>
  Response.json((props as { stack: Stack }).stack)) satisfies APIRoute;
