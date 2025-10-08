import React, { useRef } from 'react';
import { FixedSizeList as List, ListOnScrollProps } from 'react-window';
import AutoSizer from 'react-virtualized-auto-sizer';

const VIRTUAL_SCROLLING = process.env.NEXT_PUBLIC_ENABLE_VIRTUAL_SCROLLING === 'true';

export interface VirtualListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  itemHeight?: number;
  overscanCount?: number;
  onEndReached?: () => void;
  endReachedThreshold?: number; // 0..1 relative to total scrollable height
  className?: string;
}

export default function VirtualList<T>({
  items,
  renderItem,
  itemHeight = 80,
  overscanCount = 3,
  onEndReached,
  endReachedThreshold = 0.8,
  className,
}: VirtualListProps<T>) {
  const listRef = useRef<List>(null);

  const handleScroll = ({ scrollOffset, scrollUpdateWasRequested }: ListOnScrollProps) => {
    if (scrollUpdateWasRequested) return; // ignore programmatic scrolls

    if (onEndReached) {
      const totalHeight = items.length * itemHeight;
      // Avoid division by zero
      const denom = Math.max(1, totalHeight - (typeof window !== 'undefined' ? window.innerHeight : 0));
      const progress = scrollOffset / denom;
      if (progress >= endReachedThreshold) {
        onEndReached();
      }
    }
  };

  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => {
    const item = items[index];
    return <div style={style}>{renderItem(item, index)}</div>;
  };

  if (!VIRTUAL_SCROLLING) {
    return (
      <div className={className}>
        {items.map((item, index) => (
          <div key={index}>{renderItem(item, index)}</div>
        ))}
      </div>
    );
  }

  return (
    <div className={className} style={{ height: '100%', width: '100%' }}>
      <AutoSizer>
        {({ height, width }) => (
          <List
            ref={listRef}
            height={height}
            itemCount={items.length}
            itemSize={itemHeight}
            width={width}
            overscanCount={overscanCount}
            onScroll={handleScroll}
          >
            {Row as any}
          </List>
        )}
      </AutoSizer>
    </div>
  );
}
