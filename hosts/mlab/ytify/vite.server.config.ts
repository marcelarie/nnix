import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    ssr: 'server.ts',
    outDir: 'dist-server',
  },
  ssr: { noExternal: true },
});
