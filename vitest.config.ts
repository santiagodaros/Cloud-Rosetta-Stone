import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Los tests cargan todo el contenido y algunos leen `git log`: con la máquina ocupada, los 5 s por defecto no alcanzan.
  test: { include: ['tests/**/*.test.ts'], testTimeout: 30_000 },
});
