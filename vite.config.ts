import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default ({ command, mode }) => {
  let minifySetting

  if (mode === "development") {
    minifySetting = false
  } else {
    minifySetting = "esbuild" 
  }

  return {
    build: {
      minify: minifySetting
    },
    plugins: [
      RubyPlugin(),
    ],
  }
}
