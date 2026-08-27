import { z } from 'zod';

const schemaUrl =
  'https://raw.githubusercontent.com/4evy/patches/master/schema/stack-v1.schema.json';
const revisionPattern = /^(?:[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})$/;

const endpointSchema = z.strictObject({
  url: z.url(),
  role: z.enum(['primary', 'mirror']),
  priority: z.number().int().nonnegative(),
});

export const stackManifestSchema = z.strictObject({
  $schema: z.literal(schemaUrl),
  manifestVersion: z.literal(1),
  id: z.string().regex(/^[a-z0-9][a-z0-9._-]*$/),
  source: z.strictObject({
    vcs: z.literal('git'),
    canonical: z.url(),
    revision: z.string().regex(revisionPattern),
    trackingRef: z.string().startsWith('refs/').optional(),
    endpoints: z.array(endpointSchema).min(1),
    checkout: z
      .strictObject({
        submodules: z
          .union([z.literal(false), z.literal('recursive')])
          .optional(),
        lfs: z.boolean().optional(),
      })
      .optional(),
  }),
  result: z
    .strictObject({
      tree: z.strictObject({
        algorithm: z.enum(['sha1', 'sha256']),
        oid: z.string().regex(revisionPattern),
      }),
    })
    .optional(),
});

export type StackManifest = z.infer<typeof stackManifestSchema>;

export interface Stack {
  id: string;
  manifest: StackManifest;
  series: string;
  patches: string[];
}

export interface Catalog {
  stacks: Stack[];
}
