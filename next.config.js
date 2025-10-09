/** @type {import('next').NextConfig} */
const isElectronBuild = process.env.ELECTRON_BUILD === '1';

const nextConfig = {
  // React strict mode
  reactStrictMode: true,

  // SWC minification (faster builds)
  swcMinify: true,

  // Expose selected env vars to the client (read at build time)
  env: {
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  },

  // Image optimization
  images: {
    // Add your image domains here
    domains: [
      'your-project.supabase.co',
      'your-supabase-project.supabase.co',
      'truckercore.com',
      'basemaps.cartocdn.com',
    ],
    formats: ['image/avif', 'image/webp'],
    unoptimized: isElectronBuild ? true : false,
  },

  // Optimize package imports (important for heavy dependencies)
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      'recharts',
      '@supabase/supabase-js',
      'lodash.debounce',
      'lodash.throttle',
    ],
  },

  // Disable x-powered-by header
  poweredByHeader: false,

  // Enable compression
  compress: true,

  // Trailing slash behavior
  trailingSlash: isElectronBuild ? true : false,

  // Output standalone for Docker when not Electron build
  ...(isElectronBuild
    ? {
        // Electron: static export
        output: 'export',
        distDir: 'out',
        assetPrefix: process.env.NODE_ENV === 'production' ? './' : '',
      }
    : {
        // Vercel default (leave default output mode for serverless)
        output: 'standalone',
        productionBrowserSourceMaps: false,
      }),

  // Headers for security and performance
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-DNS-Prefetch-Control', value: 'on' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Referrer-Policy', value: 'origin-when-cross-origin' },
        ],
      },
    ];
  },

  // Webpack configuration for heavy packages
  webpack: (config, { isServer }) => {
    if (!isServer) {
      // Don't bundle Node core modules on the client side
      config.resolve.fallback = {
        ...(config.resolve.fallback || {}),
        fs: false,
        net: false,
        tls: false,
        crypto: false,
        path: false,
        os: false,
        stream: false,
      };
    }

    // Ignore specific warnings from heavy packages
    config.ignoreWarnings = [
      ...(config.ignoreWarnings || []),
      { module: /node_modules\/node-fetch\/lib\/index\.js/ },
      { module: /node_modules\/punycode\/punycode\.js/ },
    ];

    return config;
  },
};

// We keep PWA plugin optional to avoid introducing a new mandatory dependency.
// To enable PWA later, install `next-pwa` and wrap the export with it.
module.exports = nextConfig;
