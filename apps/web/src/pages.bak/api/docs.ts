import type { NextApiRequest, NextApiResponse } from 'next';
import { apiResponse } from '@/lib/api/middleware';
import { openApiSpec } from '@/lib/api/openapi-spec';

export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const resp = apiResponse(openApiSpec);
  // apiResponse returns NextResponse in edge runtime; adapt by sending JSON here
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  if ((resp as any).json) {
    // Running in pages API, just send JSON
    res.status(200).json(openApiSpec);
  } else {
    res.status(200).json(openApiSpec);
  }
}
