import assert from 'node:assert/strict';
import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, before, describe, it } from 'node:test';
import {
  loadCatalog,
  loadPatch,
  loadStack,
} from '../src/lib/catalog.ts';
import type { StackManifest } from '../src/types.ts';

const previousStacksRoot = process.env.PATCHES_STACKS;
let root: string;

function manifestFor(id: string): StackManifest {
  return {
    $schema:
      'https://raw.githubusercontent.com/4evy/patches/master/schema/stack-v1.schema.json',
    manifestVersion: 1,
    id,
    source: {
      vcs: 'git',
      canonical: `https://example.com/${id}.git`,
      revision: '0123456789abcdef0123456789abcdef01234567',
      endpoints: [
        {
          url: `https://example.com/${id}.git`,
          role: 'primary',
          priority: 0,
        },
      ],
    },
  };
}

async function createStack(id: string, patches: string[]) {
  const directory = join(root, id);
  await mkdir(join(directory, 'patches'), { recursive: true });
  await Promise.all([
    writeFile(
      join(directory, 'stack.json'),
      `${JSON.stringify(manifestFor(id), null, 2)}\n`,
    ),
    writeFile(
      join(directory, 'patches', 'series'),
      `${patches.join('\n')}\n`,
    ),
    ...new Set(patches)
      .values()
      .map((patch) =>
        writeFile(
          join(directory, 'patches', patch),
          `patch: ${patch}\n`,
        ),
      ),
  ]);
}

describe('catalog loader', () => {
  before(async () => {
    root = await mkdtemp(join(tmpdir(), 'patches-catalog-'));
    process.env.PATCHES_STACKS = root;
    await Promise.all([
      createStack('beta', ['beta.patch']),
      createStack('alpha', ['alpha.patch']),
    ]);
  });

  after(async () => {
    if (previousStacksRoot === undefined) {
      delete process.env.PATCHES_STACKS;
    } else {
      process.env.PATCHES_STACKS = previousStacksRoot;
    }
    await rm(root, { force: true, recursive: true });
  });

  it('loads valid stacks in deterministic order', async () => {
    const catalog = await loadCatalog();

    assert.deepEqual(
      catalog.stacks.map(({ id }) => id),
      ['alpha', 'beta'],
    );
  });

  it('loads only patch files named by the series', async () => {
    const stack = await loadStack('alpha');
    assert.ok(stack);
    assert.equal(
      await loadPatch(stack, 'alpha.patch'),
      'patch: alpha.patch\n',
    );
    assert.equal(await loadPatch(stack, 'missing.patch'), undefined);
  });

  it('rejects duplicate patch paths', async () => {
    await createStack('duplicate', ['same.patch', 'same.patch']);
    try {
      await assert.rejects(
        loadStack('duplicate'),
        /Duplicate patch path/,
      );
    } finally {
      await rm(join(root, 'duplicate'), {
        force: true,
        recursive: true,
      });
    }
  });

  it('rejects invalid stack IDs before touching the filesystem', async () => {
    assert.equal(await loadStack('../alpha'), undefined);
  });
});
