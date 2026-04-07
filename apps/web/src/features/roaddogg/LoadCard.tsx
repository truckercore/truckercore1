import { setSuggestionFeedback } from '@/lib/roaddogg/feedback';
import { useFlags } from '@/lib/flags/useFlags';
import { useMemo } from 'react';

type LoadItem = {
  id?: string | number;
  id_suggestion?: number; // suggestions_log.id if available
  origin_zip?: string;
  dest_zip?: string;
  rpm?: number | string;
  deadhead_miles?: number | null;
  broker_credit?: number | string | null;
  _why?: string[]; // explanation tokens
  personalized?: boolean; // optional marker from backend
};

export function LoadCard({ item }: { item: LoadItem }) {
  const { FEATURE_PERSONALIZED_LOADS } = useFlags();

  const why: string[] = item?._why ?? [];
  const sid: number | undefined = item?.id_suggestion;

  const meta = useMemo(() => {
    const rpm = item.rpm ?? '—';
    const dh = item.deadhead_miles ?? 0;
    const credit = item.broker_credit ?? '—';
    return `RPM ${rpm} · Deadhead ${dh} mi · Credit ${credit}`;
  }, [item.rpm, item.deadhead_miles, item.broker_credit]);

  const showPersonalized =
    !!FEATURE_PERSONALIZED_LOADS && (item.personalized || why.length > 0);

  return (
    <div className="rounded-2xl shadow p-4 border border-neutral-200 bg-white">
      <div className="flex items-start justify-between gap-2">
        <div className="font-semibold">
          {item.origin_zip} → {item.dest_zip}
        </div>
        {showPersonalized && (
          <span className="shrink-0 rounded-full text-xs px-2 py-1 bg-amber-100 text-amber-800 border border-amber-200">
            Personalized
          </span>
        )}
      </div>

      <div className="text-sm opacity-80 mt-0.5">{meta}</div>

      {!!why.length && (
        <div className="mt-2 text-xs leading-relaxed">
          <span className="opacity-60">Why this?</span>{' '}
          {why.slice(0, 3).join(' · ')}
        </div>
      )}

      <div className="mt-3 flex gap-2">
        <button
          className="px-3 py-2 rounded bg-emerald-600 text-white hover:bg-emerald-700 disabled:opacity-50"
          onClick={() => sid && setSuggestionFeedback(sid, true)}
          disabled={!sid}
          title={!sid ? 'Feedback unavailable' : 'Accept suggestion'}
        >
          Accept
        </button>
        <button
          className="px-3 py-2 rounded bg-neutral-200 hover:bg-neutral-300 disabled:opacity-50"
          onClick={() => sid && setSuggestionFeedback(sid, false)}
          disabled={!sid}
          title={!sid ? 'Feedback unavailable' : 'Send negative signal'}
        >
          Less like this
        </button>
      </div>
    </div>
  );
}
