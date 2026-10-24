import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import astro from 'eslint-plugin-astro';
import globals from 'globals';

// Solo atrapar bugs obvios: configs `recommended`, sin reglas de estilo ni formato.
export default tseslint.config(
  {
    // Solo se lintea src/, scripts/, tests/ y mcp/src/.
    ignores: ['**/*', '!src/**', '!scripts/**', '!tests/**', '!mcp/', '!mcp/src/**', '**/node_modules/**', '**/dist/**', '**/.astro/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...astro.configs.recommended,
  {
    languageOptions: { globals: { ...globals.node, ...globals.browser } },
  },
);
