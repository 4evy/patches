import { readdir, readFile, realpath, stat } from 'node:fs/promises';
import { isAbsolute, relative, resolve, sep } from 'node:path';
import { z } from 'zod';
import {
  stackManifestSchema,
  type Catalog,
  type Stack,
} from '../types.ts';

const stackIdPattern = /^[a-z0-9][a-z0-9._-]*$/;

function isMissing(error: unknown): boolean {
  return (
    error instanceof Error && 'code' in error && error.code === 'ENOENT'
  );
}

function isBelow(root: string, candidate: string): boolean {
  const pathFromRoot = relative(root, candidate);
  return (
    pathFromRoot.length > 0 &&
    pathFromRoot !== '..' &&
    !pathFromRoot.startsWith(`..${sep}`) &&
    !isAbsolute(pathFromRoot)
  );
}

async function stacksRoot(): Promise<string> {
  const configured = process.env.PATCHES_STACKS;
  if (configured) return realpath(resolve(configured));

  for (const candidate of [
    resolve(process.cwd(), 'stacks'),
    resolve(process.cwd(), '../stacks'),
  ]) {
    try {
      return await realpath(candidate);
    } catch (error) {
      if (!isMissing(error)) throw error;
    }
  }

  throw new Error(
    'Could not find stacks/. Set PATCHES_STACKS to the catalog directory.',
  );
}

async function directoryBelow(
  root: string,
  requested: string,
): Promise<string | undefined> {
  let directory: string;
  try {
    directory = await realpath(requested);
  } catch (error) {
    if (isMissing(error)) return undefined;
    throw error;
  }

  if (
    !isBelow(root, directory) ||
    !(await stat(directory)).isDirectory()
  ) {
    return undefined;
  }
  return directory;
}

async function fileBelow(
  root: string,
  requested: string,
): Promise<string | undefined> {
  let file: string;
  try {
    file = await realpath(requested);
  } catch (error) {
    if (isMissing(error)) return undefined;
    throw error;
  }

  if (!isBelow(root, file) || !(await stat(file)).isFile()) {
    return undefined;
  }
  return file;
}

function parseManifest(value: unknown, id: string) {
  const result = stackManifestSchema.safeParse(value);
  if (!result.success) {
    throw new Error(
      `Invalid stack manifest for ${id}:\n${z.prettifyError(result.error)}`,
      { cause: result.error },
    );
  }

  if (result.data.id !== id) {
    throw new Error(`Stack manifest ID does not match directory ${id}`);
  }

  return result.data;
}

function parseSeries(series: string, id: string): string[] {
  const patches = series
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+#.*$/, '').trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'));
  const seen = new Set<string>();

  for (const patch of patches) {
    if (
      isAbsolute(patch) ||
      patch.includes('\\') ||
      patch.split('/').includes('..') ||
      !patch.endsWith('.patch')
    ) {
      throw new Error(`Unsafe patch path in ${id}: ${patch}`);
    }
    if (seen.has(patch)) {
      throw new Error(`Duplicate patch path in ${id}: ${patch}`);
    }
    seen.add(patch);
  }

  return patches;
}

async function loadStackFromRoot(
  root: string,
  id: string,
): Promise<Stack | undefined> {
  if (!stackIdPattern.test(id)) return undefined;

  const directory = await directoryBelow(root, resolve(root, id));
  if (!directory) return undefined;

  const patchRoot = await directoryBelow(
    directory,
    resolve(directory, 'patches'),
  );
  const manifestFile = await fileBelow(
    directory,
    resolve(directory, 'stack.json'),
  );
  if (!patchRoot || !manifestFile) return undefined;

  const seriesFile = await fileBelow(
    patchRoot,
    resolve(patchRoot, 'series'),
  );
  if (!seriesFile) return undefined;

  const [manifestText, series] = await Promise.all([
    readFile(manifestFile, 'utf8'),
    readFile(seriesFile, 'utf8'),
  ]);
  const manifest = parseManifest(JSON.parse(manifestText), id);
  return { id, manifest, series, patches: parseSeries(series, id) };
}

export async function loadStack(
  id: string,
): Promise<Stack | undefined> {
  const root = await stacksRoot();
  return loadStackFromRoot(root, id);
}

export async function loadCatalog(): Promise<Catalog> {
  const root = await stacksRoot();
  const entries = await readdir(root, { withFileTypes: true });
  const ids = entries
    .filter(
      (entry) => entry.isDirectory() && stackIdPattern.test(entry.name),
    )
    .map((entry) => entry.name)
    .sort();
  const stacks = await Promise.all(
    ids.map((id) => loadStackFromRoot(root, id)),
  );

  return { stacks: stacks.filter((stack) => stack !== undefined) };
}

export async function loadPatch(
  stack: Stack,
  patchPath: string,
): Promise<string | undefined> {
  if (!stack.patches.includes(patchPath)) return undefined;

  const root = await stacksRoot();
  const directory = await directoryBelow(root, resolve(root, stack.id));
  if (!directory) return undefined;

  const patchRoot = await directoryBelow(
    directory,
    resolve(directory, 'patches'),
  );
  if (!patchRoot) return undefined;

  const file = await fileBelow(
    patchRoot,
    resolve(patchRoot, patchPath),
  );
  if (!file) return undefined;

  return readFile(file, 'utf8');
}
