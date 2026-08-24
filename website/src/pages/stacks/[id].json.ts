import type { APIRoute } from 'astro';
import { loadStack } from '../../lib/catalog.ts';

export const GET = (async ({ params }) => {
  const stack = await loadStack(params.id ?? '');
  return stack
    ? Response.json(stack)
    : Response.json({ error: 'stack not found' }, { status: 404 });
}) satisfies APIRoute;
