// TypeScript
import { Html, Head, Main, NextScript } from "next/document";

export default function Document() {
  return (
    <Html lang="en">
      <Head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="description" content="TruckerCore — Safety, compliance, and operations tools for trucking fleets." />
        <meta name="theme-color" content="#0F1216" />
        {/* Using manifest icons; favicon/apple-touch will be added later */}
        <link rel="manifest" href="/manifest.json" />
        <link rel="icon" type="image/png" sizes="192x192" href="/icon-192.png" />
      </Head>
      <body style={{ margin: 0, padding: 0 }}>
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
