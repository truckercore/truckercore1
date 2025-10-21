'use client';
import React, { createContext, useContext, useMemo, useRef, useState } from 'react';

export type LlmChoice = 'gpt-4o'|'gpt-4o-mini'|'claude-3-5'|'local-llama';
type Tool = { name: string; description: string; schema: any; invoke: (args: any) => Promise<any> };

type Ctx = {
  model: LlmChoice;
  setModel(m: LlmChoice): void;
  registerTools(tools: Tool[]): void;
  chat(prompt: string, opts?: { system?: string; history?: Array<{role:'user'|'assistant', content:string}> }): Promise<string>;
};

const LlmCtx = createContext<Ctx | null>(null);

export function LlmProvider({ children, defaultModel = 'gpt-4o-mini' }: { children: React.ReactNode; defaultModel?: LlmChoice }) {
  const [model, setModel] = useState<LlmChoice>(defaultModel);
  const toolsRef = useRef<Record<string, Tool>>({});

  function registerTools(tools: Tool[]) {
    for (const t of tools) toolsRef.current[t.name] = t;
  }

  const client = useMemo(() => {
    return {
      async complete(prompt: string, system?: string, history?: any[]) {
        const r = await fetch('/api/llm/complete', {
          method: 'POST',
          headers: { 'Content-Type':'application/json' },
          body: JSON.stringify({
            model,
            prompt,
            system,
            history,
            tools: Object.values(toolsRef.current).map(t => ({
              name: t.name,
              description: t.description,
              schema: t.schema
            }))
          })
        });
        if (!r.ok) throw new Error(await r.text());
        return await r.text();
      }
    };
  }, [model]);

  const value: Ctx = {
    model, setModel,
    registerTools,
    async chat(prompt, opts) {
      return client.complete(prompt, opts?.system, opts?.history);
    }
  };
  return <LlmCtx.Provider value={value}>{children}</LlmCtx.Provider>;
}

export function useLLM() {
  const ctx = useContext(LlmCtx);
  if (!ctx) throw new Error('useLLM must be used within LlmProvider');
  return ctx;
}
