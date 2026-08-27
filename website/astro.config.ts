import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://4evy.github.io',
  base: '/patches/',
  output: 'static',
  outDir: process.env.PATCHES_DIST || './dist',
  vite: {
    plugins: [tailwindcss()],
  },
});
