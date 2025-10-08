/** @type {import('next').NextConfig} */
const isElectronBuild = process.env.ELECTRON_BUILD === '1';

const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,

  // Expose selected env vars to the client (read at build time)
  env: {
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  },

  // Image optimization
  images: {
    domains: ['your-project.supabase.co', 'truckercore.com', 'basemaps.cartocdn.com'],
    formats: ['image/avif', 'image/webp'],
    unoptimized: isElectronBuild ? true : false,
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
        output: 'export',
        distDir: 'out',
        assetPrefix: process.env.NODE_ENV === 'production' ? './' : '',
      }
    : {
        output: 'standalone',
        productionBrowserSourceMaps: false,
      }),

  // Security headers
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        ],
      },
    ];
  },

  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...(config.resolve.fallback || {}),
        fs: false,
        net: false,
        tls: false,
      };
    }
    return config;
  },
};

module.exports = nextConfig;
