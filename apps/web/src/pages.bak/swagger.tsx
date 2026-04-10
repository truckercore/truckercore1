'use client';

import SwaggerUI from 'swagger-ui-react';
import 'swagger-ui-react/swagger-ui.css';

export default function SwaggerPage() {
  return (
    <div className="api-docs-container">
      <div className="docs-header">
        <h1>API Swagger UI</h1>
        <p>OpenAPI documentation explorer</p>
      </div>

      <SwaggerUI url="/api/docs" />

      <style jsx global>{`
        .api-docs-container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        .docs-header { margin-bottom: 30px; }
        .docs-header h1 { font-size: 32px; font-weight: 700; margin-bottom: 8px; }
        .docs-header p { font-size: 16px; color: #666; }
      `}</style>
    </div>
  );
}
