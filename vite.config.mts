import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';

export default ({ command, mode }) => {
  const isDevelopment = mode === 'development';

  return defineConfig({
    build: {
      minify: isDevelopment ? false : 'esbuild',
      skipCompatibilityCheck: true,
    },
    resolve: {
      alias: {
        vue: 'vue/dist/vue.esm-bundler',
      },
    },
    plugins: [
      RubyPlugin(),
      vue(),
    ],
  });
};
