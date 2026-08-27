import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  stackManifestSchema,
  type StackManifest,
} from '../src/types.ts';

const manifest = {
  $schema:
    'https://raw.githubusercontent.com/4evy/patches/master/schema/stack-v1.schema.json',
  manifestVersion: 1,
  id: 'demo',
  source: {
    vcs: 'git',
    canonical: 'https://example.com/demo.git',
    revision: '0123456789abcdef0123456789abcdef01234567',
    trackingRef: 'refs/heads/main',
    endpoints: [
      {
        url: 'https://example.com/demo.git',
        role: 'primary',
        priority: 0,
      },
    ],
    checkout: {
      submodules: false,
      lfs: false,
    },
  },
} satisfies StackManifest;

describe('stackManifestSchema', () => {
  it('accepts a complete stack manifest', () => {
    assert.deepEqual(stackManifestSchema.parse(manifest), manifest);
  });

  it('accepts the optional result metadata', () => {
    const result = stackManifestSchema.safeParse({
      ...manifest,
      result: {
        tree: {
          algorithm: 'sha256',
          oid: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        },
      },
    });

    assert.equal(result.success, true);
  });

  it('rejects properties outside the versioned schema', () => {
    const result = stackManifestSchema.safeParse({
      ...manifest,
      unexpected: true,
    });

    assert.equal(result.success, false);
  });

  it('rejects invalid nested metadata', () => {
    const result = stackManifestSchema.safeParse({
      ...manifest,
      source: {
        ...manifest.source,
        endpoints: [{ role: 'backup', priority: -1, url: 'not a URL' }],
        checkout: { submodules: true },
      },
    });

    assert.equal(result.success, false);
  });
});
