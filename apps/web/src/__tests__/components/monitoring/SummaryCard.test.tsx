import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SummaryCard } from '@/components/monitoring/MonitoringDashboard';

describe('SummaryCard', () => {
  it('should render title and value', () => {
    render(<SummaryCard title="Test Metric" value="123" icon="📊" color="#3b82f6" trend="up" />);
    expect(screen.getByText('Test Metric')).toBeInTheDocument();
    expect(screen.getByText('123')).toBeInTheDocument();
  });

  it('should display icon', () => {
    render(<SummaryCard title="Test" value="100" icon="🎯" color="#10b981" trend="up" />);
    expect(screen.getByText('🎯')).toBeInTheDocument();
  });

  it('should display trend icon for up', () => {
    render(<SummaryCard title="Test" value="100" icon="📊" color="#10b981" trend="up" />);
    expect(screen.getByText('📈')).toBeInTheDocument();
  });

  it('should display trend icon for down', () => {
    render(<SummaryCard title="Test" value="100" icon="📊" color="#ef4444" trend="down" />);
    expect(screen.getByText('📉')).toBeInTheDocument();
  });

  it('should display trend icon for neutral', () => {
    render(<SummaryCard title="Test" value="100" icon="📊" color="#64748b" trend="neutral" />);
    expect(screen.getByText('➖')).toBeInTheDocument();
  });

  it('should apply custom color', () => {
    const { container } = render(
      <SummaryCard title="Test" value="100" icon="📊" color="#ff0000" trend="up" />
    );
    const card = container.querySelector('.summary-card') as HTMLElement;
    expect(card).toHaveStyle({ borderColor: '#ff0000' });
  });
});
