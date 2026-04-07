import { NextRequest, NextResponse } from 'next/server';

// Optional: simple in-memory rate limiter (per instance)
const windowMs = 30_000;
const maxReq = 20;
const bucket = new Map<string, number[]>();
function rateLimit(key: string) {
  const now = Date.now();
  const arr = bucket.get(key) ?? [];
  const recent = arr.filter(ts => now - ts < windowMs);
  if (recent.length >= maxReq) return false;
  recent.push(now);
  bucket.set(key, recent);
  return true;
}

export async function POST(req: NextRequest) {
  if (!rateLimit(req.ip ?? 'anon')) {
    return new NextResponse('Rate limit exceeded', { status: 429 });
  }

  const { model, prompt, system, history, tools } = await req.json();
  try {
    switch (model as string) {
      case 'gpt-4o':
      case 'gpt-4o-mini': {
        const text = await callOpenAI({ model, prompt, system, history, tools });
        return withAudit({ provider: 'openai', model, prompt, text, status: 'ok' });
      }
      case 'claude-3-5': {
        const text = await callAnthropic({ model, prompt, system, history, tools });
        return withAudit({ provider: 'anthropic', model, prompt, text, status: 'ok' });
      }
      case 'local-llama': {
        const text = await callLocalLLM({ prompt, system, history });
        return withAudit({ provider: 'local', model, prompt, text, status: 'ok' });
      }
      default:
        throw new Error('Unknown model');
    }
  } catch (e: any) {
    // Fallback to cheaper model
    const text = await callOpenAI({ model: 'gpt-4o-mini', prompt, system, history, tools }).catch(() => 'Service temporarily unavailable.');
    const res = await withAudit({ provider: 'openai', model: 'gpt-4o-mini', prompt, text, status: 'error', error: String(e?.message ?? e) });
    res.headers.set('X-Fallback', 'gpt-4o-mini');
    return res;
  }
}

async function withAudit(args: { provider: string; model: string; prompt: string; text: string; status: 'ok'|'error'; error?: string; }) {
  // Fire-and-forget audit record; do not block response
  void logAudit(args).catch(() => {});
  return new NextResponse(args.text, { status: 200 });
}

async function logAudit({ provider, model, prompt, text, status, error }: { provider: string; model: string; prompt: string; text: string; status: string; error?: string; }) {
  const manifest = { provider, model, status, error_present: !!error };
  // eslint-disable-next-line no-console
  console.log('[ai_audit]', { provider, model, status, prompt_excerpt: String(prompt||'').slice(0, 160), answer_excerpt: String(text||'').slice(0, 160), manifest });
}

// Provider call stubs — replace with real SDK calls and tool wiring

async function callOpenAI({ model, prompt, system, history, tools }: any): Promise<string> {
  // Implement with server-side key in real usage
  // Tools: map to OpenAI tool format and handle tool calls if needed
  return `OK (${model})`;
}

async function callAnthropic({ model, prompt, system, history, tools }: any): Promise<string> {
  // Map to Anthropic Messages API; tools -> tool_schema/functions per Anthropic format
  return `OK (${model})`;
}

async function callLocalLLM({ prompt, system, history }: any): Promise<string> {
  // Example: call local server (Ollama/LLama.cpp) via HTTP
  return `OK (local)`;
}
