// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';

import node from '@astrojs/node';

// https://astro.build/config
export default defineConfig({
  output: 'server',
  adapter: node({
    mode: 'standalone',
  }),
  vite: {
    plugins: [tailwindcss()],
    css: {
      transformer: 'lightningcss',
      lightningcss: {
        errorRecovery: true,
        targets: {
          chrome: 90 << 16,
          firefox: 90 << 16,
          safari: 14 << 16,
        }
      }
    },
    build: {
      cssMinify: 'esbuild'
    }
  }
});