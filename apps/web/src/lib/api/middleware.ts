import { NextRequest, NextResponse } from 'next/server';
import type { NextApiRequest, NextApiResponse } from 'next';
import { ZodSchema } from 'zod';

export interface APIError {
  code: string;
  message: string;
  details?: any;
}

export class APIException extends Error {
  constructor(
    public statusCode: number,
    public code: string,
    message: string,
    public details?: any
  ) {
    super(message);
    this.name = 'APIException';
  }
}

// Internal helper to get header value from either NextRequest or NextApiRequest
function getHeader(request: NextRequest | NextApiRequest, name: string): string | null {
  // NextRequest
  if (typeof (request as any).headers?.get === 'function') {
    return (request as any).headers.get(name);
  }
  // NextApiRequest
  const headers = (request as NextApiRequest).headers;
  const val = headers?.[name as keyof typeof headers];
  if (Array.isArray(val)) return val[0] ?? null;
  return (val as string) ?? null;
}

/**
 * Error handler middleware
 */
export function handleAPIError(error: unknown): NextResponse {
  // eslint-disable-next-line no-console
  console.error('API Error:', error);

  if (error instanceof APIException) {
    return NextResponse.json(
      {
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
        },
      },
      { status: error.statusCode }
    );
  }

  if (error instanceof Error) {
    return NextResponse.json(
      {
        error: {
          code: 'INTERNAL_ERROR',
          message:
            process.env.NODE_ENV === 'development' ? error.message : 'An internal error occurred',
          ...(process.env.NODE_ENV === 'development' && {
            stack: error.stack,
          }),
        },
      },
      { status: 500 }
    );
  }

  return NextResponse.json(
    {
      error: {
        code: 'UNKNOWN_ERROR',
        message: 'An unknown error occurred',
      },
    },
    { status: 500 }
  );
}

/**
 * Validate request body with Zod schema
 * Works with Web (NextRequest) and Pages (NextApiRequest)
 */
export async function validateRequestBody<T>(
  request: NextRequest | NextApiRequest,
  schema: ZodSchema<T>
): Promise<T> {
  try {
    let body: any;
    if (typeof (request as any).json === 'function') {
      // NextRequest
      body = await (request as any).json();
    } else {
      // NextApiRequest
      body = (request as NextApiRequest).body;
    }
    return schema.parse(body);
  } catch (error: any) {
    throw new APIException(
      400,
      'VALIDATION_ERROR',
      'Invalid request body',
      error?.errors || error?.message
    );
  }
}

/**
 * Validate query parameters (pass URL object or NextApiRequest)
 */
export function validateQueryParams<T>(
  urlOrReq: URL | NextApiRequest,
  schema: ZodSchema<T>
): T {
  try {
    let params: Record<string, any>;
    if (urlOrReq instanceof URL) {
      params = Object.fromEntries(urlOrReq.searchParams as any);
    } else {
      params = urlOrReq.query as Record<string, any>;
    }
    return schema.parse(params);
  } catch (error: any) {
    throw new APIException(
      400,
      'VALIDATION_ERROR',
      'Invalid query parameters',
      error?.errors || error?.message
    );
  }
}

/**
 * Require authentication (mock JWT via base64 JSON)
 * Supports both NextRequest and NextApiRequest
 */
export async function requireAuth(request: NextRequest | NextApiRequest): Promise<{
  userId: string;
  role: string;
}> {
  const authHeader = getHeader(request, 'authorization');

  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
    throw new APIException(401, 'UNAUTHORIZED', 'Missing or invalid authorization header');
  }

  const token = authHeader.substring(7);
  try {
    const decoded = JSON.parse(Buffer.from(token, 'base64').toString());
    return {
      userId: decoded.userId,
      role: decoded.role,
    };
  } catch {
    throw new APIException(401, 'UNAUTHORIZED', 'Invalid authentication token');
  }
}

/**
 * Rate limiting (simple in-memory implementation)
 */
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();

export function rateLimit(
  identifier: string,
  maxRequests: number = 100,
  windowMs: number = 60_000
): void {
  const now = Date.now();
  const record = rateLimitStore.get(identifier);

  if (!record || record.resetAt < now) {
    rateLimitStore.set(identifier, {
      count: 1,
      resetAt: now + windowMs,
    });
    return;
  }

  if (record.count >= maxRequests) {
    throw new APIException(429, 'RATE_LIMIT_EXCEEDED', 'Too many requests, please try again later', {
      retryAfter: Math.ceil((record.resetAt - now) / 1000),
    });
  }

  record.count++;
}

/**
 * CORS headers
 */
export function corsHeaders(origin?: string): HeadersInit {
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  } as HeadersInit;
}

/**
 * Handle OPTIONS requests
 */
export function handleOptions(origin?: string): NextResponse {
  return new NextResponse(null, {
    status: 204,
    headers: corsHeaders(origin),
  });
}

/**
 * Pagination helper
 */
export interface PaginationParams {
  page: number;
  limit: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasMore: boolean;
  };
}

export function paginate<T>(items: T[], params: PaginationParams): PaginatedResponse<T> {
  const { page, limit } = params;
  const total = items.length;
  const totalPages = Math.max(1, Math.ceil(total / limit));
  const safePage = Math.min(Math.max(page, 1), totalPages);
  const startIndex = (safePage - 1) * limit;
  const endIndex = startIndex + limit;
  const data = items.slice(startIndex, endIndex);

  return {
    data,
    pagination: {
      page: safePage,
      limit,
      total,
      totalPages,
      hasMore: safePage < totalPages,
    },
  };
}

/**
 * API response helper (adds CORS)
 */
export function apiResponse<T>(data: T, status: number = 200, headers?: HeadersInit): NextResponse {
  return NextResponse.json(data as any, {
    status,
    headers: {
      ...(corsHeaders() as any),
      ...(headers as any),
    },
  });
}
