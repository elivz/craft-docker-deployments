import {defineConfig} from 'vite'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig(({command}) => ({
    base: command === 'serve' ? '' : '/assets/',
    build: {
        manifest: true,
        outDir: './public/assets/',
        publicDir: false,
        rollupOptions: {
            input: './src/main.js',
        }
    },
    plugins: [
        tailwindcss(),
    ],
}))
