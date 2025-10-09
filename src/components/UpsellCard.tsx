import React from 'react';

type Props = {
  feature: string;               // e.g., "AI Capacity Forecasting"
  description?: string;          // short value prop
  tierRequired?: 'premium' | 'ai';
  ctaLabel?: string;             // e.g., "Upgrade to AI"
  onUpgrade?: () => void;        // handler to open Stripe Checkout
  learnMoreHref?: string;        // optional link
  compact?: boolean;             // smaller variant for widgets
};

export const UpsellCard: React.FC<Props> = ({
  feature,
  description = 'Unlock this feature to boost performance and ROI.',
  tierRequired = 'premium',
  ctaLabel,
  onUpgrade,
  learnMoreHref,
  compact = false,
}) => {
  const title = feature;
  const badge = tierRequired === 'ai' ? 'Roaddogg AI' : 'Premium';
  const btnText = ctaLabel ?? (tierRequired === 'ai' ? 'Upgrade to AI' : 'Upgrade to Premium');

  return (
    <div
      style={{
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: compact ? 12 : 16,
        background: '#fafafa',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}
      role="region"
      aria-label={`Upsell: ${title}`}
    >
      <div
        style={{
          minWidth: 36,
          minHeight: 36,
          borderRadius: 6,
          background: tierRequired === 'ai' ? 'linear-gradient(135deg,#6d28d9,#0ea5e9)' : '#0ea5e91a',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#111827',
        }}
        aria-hidden
      >
        <span style={{ color: tierRequired === 'ai' ? '#fff' : '#0369a1' }}>★</span>
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <strong style={{ fontSize: compact ? 14 : 16, color: '#111827' }}>{title}</strong>
          <span
            style={{
              fontSize: 12,
              color: '#374151',
              background: '#e5e7eb',
              borderRadius: 999,
              padding: '2px 8px',
            }}
          >
            {badge}
          </span>
        </div>
        {!compact && (
          <p style={{ marginTop: 6, fontSize: 13, color: '#4b5563' }}>{description}</p>
        )}
        <div style={{ marginTop: 10, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button
            onClick={onUpgrade}
            style={{
              background: tierRequired === 'ai' ? '#6d28d9' : '#0ea5e9',
              color: '#fff',
              border: 0,
              borderRadius: 6,
              padding: '8px 12px',
              fontSize: 13,
              cursor: 'pointer',
            }}
            aria-label={`Upgrade to enable ${title}`}
          >
            {btnText}
          </button>
          {learnMoreHref && (
            <a
              href={learnMoreHref}
              target="_blank"
              rel="noreferrer"
              style={{ fontSize: 13, color: '#0ea5e9', textDecoration: 'underline' }}
              aria-label="Learn more about plans"
            >
              Learn more
            </a>
          )}
        </div>
      </div>
    </div>
  );
};

export default UpsellCard;
