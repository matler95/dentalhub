import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        name: "Hub",
        short_name: "Hub",
        description: "Pliki dla lekarza ze wszystkich gabinetów w jednym miejscu",
        lang: "pl",
        start_url: "/",
        display: "standalone",
        background_color: "#f4f6f6",
        theme_color: "#0e5c5c",
        icons: [{ src: "icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any maskable" }],
      },
      // Tylko powłoka aplikacji. Treści plików i odpowiedzi API NIE są cache'owane (plan 4.3, G3).
      workbox: { globPatterns: ["**/*.{js,css,html,svg}"], navigateFallback: "/index.html", runtimeCaching: [] },
    }),
  ],
});
