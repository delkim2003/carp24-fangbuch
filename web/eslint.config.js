// carp24 ESLint flat config (BAUPLAN 0.13) — Astro + TS
import eslintPluginAstro from "eslint-plugin-astro";

export default [
  // JS-Dateien (lib, scripts)
  {
    ignores: ["dist/**", ".astro/**", "node_modules/**", "src/env.d.ts"],
  },
  ...eslintPluginAstro.configs["flat/recommended"],
];
