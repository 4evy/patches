import type { APIRoute } from 'astro';

export const GET = (() =>
  Response.json({ status: 'ok' })) satisfies APIRoute;
