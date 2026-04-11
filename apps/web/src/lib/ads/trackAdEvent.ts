export async function trackAdEvent(adId: string, eventType: 'impression' | 'click', driverId?: string) {
  try {
    await fetch('/api/ads/track', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ adId, eventType, driverId })
    });
  } catch (err) {
    console.warn('Failed to track ad event', err);
  }
}
