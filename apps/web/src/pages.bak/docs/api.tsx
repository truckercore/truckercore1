'use client';

import SwaggerUI from 'swagger-ui-react';
import 'swagger-ui-react/swagger-ui.css';

export default function APIDocsPage() {
  return (
    <div className="api-docs-container">
      <div className="docs-header">
        <h1>Fleet Manager API Documentation</h1>
        <p>Complete API reference for driver dashboard functionality</p>
      </div>
      
      <SwaggerUI url="/api/docs" />

      <style jsx global>{`
        .api-docs-container {
          max-width: 1400px;
          margin: 0 auto;
          padding: 20px;
        }
        .docs-header {
          margin-bottom: 30px;
        }
        .docs-header h1 {
          font-size: 32px;
          font-weight: 700;
          margin-bottom: 8px;
        }
        .docs-header p {
          font-size: 16px;
          color: #666;
        }
      `}</style>
    </div>
  );
}
