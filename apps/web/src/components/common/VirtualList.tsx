import React, { useRef } from 'react';
import { FixedSizeList as List } from 'react-window';
import AutoSizer from 'react-virtualized-auto-sizer';

const VIRTUAL_SCROLLING = process.env.NEXT_PUBLIC_ENABLE_VIRTUAL_SCROLLING === 'true';

interface VirtualListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  itemHeight?: number;
  overscanCount?: number;
  onEndReached?: () => void;
  endReachedThreshold?: number; // 0..1
}

export default function VirtualList<T>({
  items,
  renderItem,
  itemHeight = 80,
  overscanCount = 3,
  onEndReached,
  endReachedThreshold = 0.8,
}: VirtualListProps<T>) {
  const listRef = useRef<List>(null);
  const lastScrollTop = useRef(0);

  const handleScroll = ({ scrollOffset, scrollUpdateWasRequested }: any) => {
    if (scrollUpdateWasRequested) return;

    lastScrollTop.current = scrollOffset;

    if (onEndReached) {
      // Approximate total list height for progress detection
      const listHeight = items.length * itemHeight;
      const viewportHeight = typeof window !== 'undefined' ? window.innerHeight : itemHeight;
      const denom = Math.max(1, listHeight - viewportHeight);
      const scrollProgress = scrollOffset / denom;

      if (scrollProgress >= endReachedThreshold) {
        onEndReached();
      }
    }
  };

  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => {
    const item = items[index];
    return <div style={style}>{renderItem(item, index)}</div>;
  };

  if (!VIRTUAL_SCROLLING) {
    // Fallback: simple list rendering without virtualization
    return (
      <div className="space-y-2">
        {items.map((item, index) => (
          <div key={index}>{renderItem(item, index)}</div>
        ))}
      </div>
    );
  }

  return (
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
  );
}
