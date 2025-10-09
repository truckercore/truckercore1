'use client';

import { useEffect, useState } from 'react';
import dynamic from 'next/dynamic';
import 'leaflet/dist/leaflet.css';

const MapContainer = dynamic(() => import('react-leaflet').then(m => m.MapContainer), { ssr: false });
const TileLayer = dynamic(() => import('react-leaflet').then(m => m.TileLayer), { ssr: false });
const Marker = dynamic(() => import('react-leaflet').then(m => m.Marker), { ssr: false });
const Popup = dynamic(() => import('react-leaflet').then(m => m.Popup), { ssr: false });

interface TruckStop {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  distance?: number;
  parking_total: number;
  parking_available: number;
  fuel_diesel: number;
  fuel_def: number;
  rating: number;
  review_count: number;
  services: string[];
}

interface Reservation {
  id: string;
  driver_name: string;
  truck_number: string;
  service_type: string;
  check_in: string;
  check_out: string;
  status: string;
  amount: number;
}

interface LoyaltyRewards {
  points: number;
  tier: string;
  benefits: {
    discount: number;
    showerCredits: number;
    freeParking: number;
  };
  pointsValue: string;
}

export default function TruckStopDashboard() {
  const [nearbyStops, setNearbyStops] = useState<TruckStop[]>([]);
  const [selectedStop, setSelectedStop] = useState<TruckStop | null>(null);
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [loyaltyRewards, setLoyaltyRewards] = useState<LoyaltyRewards | null>(null);
  const [showBooking, setShowBooking] = useState(false);
  const [showFuelComparison, setShowFuelComparison] = useState(false);
  const [fuelComparison, setFuelComparison] = useState<any>(null);
  const [view, setView] = useState<'map' | 'reservations' | 'rewards'>('map');

  const [bookingForm, setBookingForm] = useState({
    driverName: '',
    truckNumber: '',
    checkIn: '',
    checkOut: '',
  });

  useEffect(() => {
    getUserLocation();
    loadLoyaltyRewards();

    if (typeof window !== 'undefined' && window.electronAPI?.onNavigate) {
      window.electronAPI.onNavigate((path) => {
        if (path.includes('truck-stop')) {
          setView('map');
        }
      });
    }
  }, []);

  useEffect(() => {
    if (userLocation) {
      void findNearbyStops();
    }
  }, [userLocation]);

  const getUserLocation = () => {
    if (typeof navigator !== 'undefined' && navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({ lat: position.coords.latitude, lng: position.coords.longitude });
        },
        (_error) => {
          // Default to center of US
          setUserLocation({ lat: 39.8283, lng: -98.5795 });
        }
      );
    } else {
      setUserLocation({ lat: 39.8283, lng: -98.5795 });
    }
  };

  const findNearbyStops = async () => {
    if (!userLocation) return;
    try {
      if (window.electronAPI) {
        const stops = await window.electronAPI.invoke('truck-stop:find-nearby', {
          lat: userLocation.lat,
          lng: userLocation.lng,
          radius: 50,
          services: [],
        });
        setNearbyStops(stops || []);
      } else {
        // Mock one stop nearby
        setNearbyStops([
          {
            id: 'TS-001',
            name: 'Sample Truck Stop',
            address: '123 Main St, Anytown, USA',
            lat: userLocation.lat + 0.05,
            lng: userLocation.lng + 0.05,
            distance: 3.2,
            parking_total: 100,
            parking_available: 42,
            fuel_diesel: 3.89,
            fuel_def: 3.29,
            rating: 4.5,
            review_count: 128,
            services: ['fuel', 'parking', 'showers', 'restaurant', 'wifi'],
          },
        ]);
      }
    } catch (error) {
      console.error('Failed to find nearby stops:', error);
    }
  };

  const loadLoyaltyRewards = async () => {
    try {
      if (window.electronAPI) {
        const rewards = await window.electronAPI.invoke('truck-stop:get-loyalty-rewards', 'current-driver');
        setLoyaltyRewards(rewards || null);
      } else {
        setLoyaltyRewards({
          points: 1200,
          tier: 'silver',
          benefits: { discount: 0.05, showerCredits: 1, freeParking: 2 },
          pointsValue: '12.00',
        });
      }
    } catch (error) {
      console.error('Failed to load loyalty rewards:', error);
    }
  };

  const handleBookParking = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedStop) return;
    try {
      let result: any = { success: true };
      if (window.electronAPI) {
        result = await window.electronAPI.invoke('truck-stop:book-parking', {
          truckStopId: selectedStop.id,
          driverId: 'current-driver',
          driverName: bookingForm.driverName,
          truckNumber: bookingForm.truckNumber,
          checkIn: bookingForm.checkIn,
          checkOut: bookingForm.checkOut,
          amount: 25.0,
        });
      }
      if (result?.success) {
        setShowBooking(false);
        setBookingForm({ driverName: '', truckNumber: '', checkIn: '', checkOut: '' });
        if (typeof window !== 'undefined' && 'Notification' in window) {
          try { new Notification('✅ Parking Reserved', { body: `Your spot at ${selectedStop.name} is confirmed!` }); } catch {}
        }
      }
    } catch (error) {
      console.error('Failed to book parking:', error);
    }
  };

  const compareFuelPrices = async () => {
    if (!userLocation) return;
    try {
      if (window.electronAPI) {
        const comparison = await window.electronAPI.invoke('truck-stop:compare-fuel-prices', {
          lat: userLocation.lat,
          lng: userLocation.lng,
          radius: 50,
        });
        setFuelComparison(comparison);
        setShowFuelComparison(true);
      } else {
        // Mock comparison
        setFuelComparison({
          cheapest: { name: 'Sample Truck Stop', price: 3.79, distance: 4.1, savings: '18.00' },
          average: '3.92',
          allStops: [
            { name: 'Sample Truck Stop', price: 3.79, defPrice: 3.25, distance: 4.1, address: '123 Main St' },
          ],
        });
        setShowFuelComparison(true);
      }
    } catch (error) {
      console.error('Failed to compare fuel prices:', error);
    }
  };

  const getOccupancyColor = (available: number, total: number) => {
    const percent = (available / total) * 100;
    if (percent > 50) return 'text-green-400';
    if (percent > 20) return 'text-yellow-400';
    return 'text-red-400';
  };

  const getTierColor = (tier: string) => {
    const colors: Record<string, string> = {
      bronze: 'text-orange-400',
      silver: 'text-gray-300',
      gold: 'text-yellow-400',
      platinum: 'text-purple-400',
    };
    return colors[tier] || 'text-gray-400';
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Top Navigation */}
      <div className="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div className="flex justify-between items-center">
          <div className="flex items-center space-x-8">
            <h1 className="text-2xl font-bold">Truck Stop Services</h1>
            <div className="flex space-x-2">
              <button onClick={() => setView('map')} className={`px-4 py-2 rounded font-semibold transition ${view === 'map' ? 'bg-blue-600' : 'bg-gray-700 hover:bg-gray-600'}`}>Find Stops</button>
              <button onClick={() => setView('reservations')} className={`px-4 py-2 rounded font-semibold transition ${view === 'reservations' ? 'bg-blue-600' : 'bg-gray-700 hover:bg-gray-600'}`}>My Reservations</button>
              <button onClick={() => setView('rewards')} className={`px-4 py-2 rounded font-semibold transition ${view === 'rewards' ? 'bg-blue-600' : 'bg-gray-700 hover:bg-gray-600'}`}>Rewards</button>
            </div>
          </div>
          {loyaltyRewards && (
            <div className="flex items-center space-x-4">
              <div className="text-right">
                <div className="text-sm text-gray-400">Loyalty Points</div>
                <div className="text-xl font-bold">{loyaltyRewards.points}</div>
              </div>
              <div className={`px-3 py-1 rounded font-bold ${getTierColor(loyaltyRewards.tier)}`}>{loyaltyRewards.tier.toUpperCase()}</div>
            </div>
          )}
        </div>
      </div>

      {/* Main Content */}
      <div className="p-6">
        {/* Map View */}
        {view === 'map' && (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Map */}
            <div className="lg:col-span-2">
              <div className="bg-gray-800 rounded-lg border border-gray-700 overflow-hidden" style={{ height: '600px' }}>
                {userLocation && (
                  <MapContainer center={[userLocation.lat, userLocation.lng]} zoom={8} style={{ height: '100%', width: '100%' }}>
                    <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" attribution='&copy; OpenStreetMap' />
                    <Marker position={[userLocation.lat, userLocation.lng]}>
                      <Popup>Your Location</Popup>
                    </Marker>
                    {nearbyStops.map((stop) => (
                      <Marker key={stop.id} position={[stop.lat, stop.lng]}>
                        <Popup>
                          <div className="text-gray-900 min-w-[200px]">
                            <div className="font-bold text-lg mb-2">{stop.name}</div>
                            <div className="text-sm mb-2">{stop.address}</div>
                            <div className="space-y-1 text-sm mb-3">
                              <div>⛽ Diesel: ${'{'}stop.fuel_diesel{'}'}/gal</div>
                              <div>🅿️ Parking: {stop.parking_available}/{stop.parking_total}</div>
                              <div>⭐ Rating: {stop.rating}/5.0</div>
                              <div>📍 Distance: {stop.distance?.toFixed(1)} mi</div>
                            </div>
                            <button onClick={() => setSelectedStop(stop)} className="w-full bg-blue-600 hover:bg-blue-700 text-white px-3 py-2 rounded text-sm font-semibold">View Details</button>
                          </div>
                        </Popup>
                      </Marker>
                    ))}
                  </MapContainer>
                )}
              </div>
              <div className="mt-4 flex space-x-3">
                <button onClick={compareFuelPrices} className="flex-1 bg-green-600 hover:bg-green-700 px-4 py-3 rounded font-semibold transition">💰 Compare Fuel Prices</button>
                <button className="flex-1 bg-purple-600 hover:bg-purple-700 px-4 py-3 rounded font-semibold transition">🚿 Find Showers</button>
              </div>
            </div>

            {/* Stop Details */}
            <div>
              {selectedStop ? (
                <div className="bg-gray-800 rounded-lg border border-gray-700 p-6">
                  <h3 className="text-xl font-bold mb-4">{selectedStop.name}</h3>
                  <div className="space-y-4 mb-6">
                    <div>
                      <div className="text-sm text-gray-400 mb-1">Address</div>
                      <div>{selectedStop.address}</div>
                    </div>
                    <div>
                      <div className="text-sm text-gray-400 mb-1">Distance</div>
                      <div className="font-semibold">{selectedStop.distance?.toFixed(1)} miles away</div>
                    </div>
                    <div>
                      <div className="text-sm text-gray-400 mb-1">Parking Availability</div>
                      <div className="flex items-center justify-between">
                        <span className={`text-2xl font-bold ${getOccupancyColor(selectedStop.parking_available, selectedStop.parking_total)}`}>{selectedStop.parking_available}</span>
                        <span className="text-gray-400">/ {selectedStop.parking_total} spots</span>
                      </div>
                      <div className="w-full bg-gray-700 rounded-full h-2 mt-2">
                        <div className={`h-2 rounded-full ${selectedStop.parking_available / selectedStop.parking_total > 0.5 ? 'bg-green-500' : selectedStop.parking_available / selectedStop.parking_total > 0.2 ? 'bg-yellow-500' : 'bg-red-500'}`} style={{ width: `${(selectedStop.parking_available / selectedStop.parking_total) * 100}%` }} />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <div className="text-sm text-gray-400 mb-1">Diesel</div>
                        <div className="text-xl font-bold text-green-400">${'{'}selectedStop.fuel_diesel{'}'}/gal</div>
                      </div>
                      <div>
                        <div className="text-sm text-gray-400 mb-1">DEF</div>
                        <div className="text-xl font-bold text-blue-400">${'{'}selectedStop.fuel_def{'}'}/gal</div>
                      </div>
                    </div>
                    <div>
                      <div className="text-sm text-gray-400 mb-2">Available Services</div>
                      <div className="flex flex-wrap gap-2">
                        {selectedStop.services?.map((service: string) => (
                          <span key={service} className="px-2 py-1 bg-gray-700 rounded text-sm">{service}</span>
                        ))}
                      </div>
                    </div>
                    <div>
                      <div className="text-sm text-gray-400 mb-1">Rating</div>
                      <div className="flex items-center">
                        <span className="text-xl font-bold text-yellow-400 mr-2">⭐ {selectedStop.rating.toFixed(1)}</span>
                        <span className="text-sm text-gray-400">({selectedStop.review_count} reviews)</span>
                      </div>
                    </div>
                  </div>
                  <button onClick={() => setShowBooking(true)} className="w-full bg-blue-600 hover:bg-blue-700 px-4 py-3 rounded font-semibold transition mb-2">🅿️ Reserve Parking</button>
                  <button className="w-full bg-purple-600 hover:bg-purple-700 px-4 py-2 rounded font-semibold transition">📝 Leave Review</button>
                </div>
              ) : (
                <div className="bg-gray-800 rounded-lg border border-gray-700 p-8 text-center text-gray-400">
                  <svg className="w-16 h-16 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  <p>Select a truck stop from the map to view details</p>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Reservations View */}
        {view === 'reservations' && (
          <div className="bg-gray-800 rounded-lg border border-gray-700">
            <div className="p-4 border-b border-gray-700">
              <h2 className="text-xl font-bold">My Reservations</h2>
            </div>
            {reservations.length === 0 ? (
              <div className="p-8 text-center text-gray-400">
                <svg className="w-16 h-16 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <p className="font-semibold mb-2">No Reservations</p>
                <p className="text-sm">You don't have any active reservations</p>
              </div>
            ) : (
              <div className="divide-y divide-gray-700">
                {reservations.map((reservation) => (
                  <div key={reservation.id} className="p-4">{/* Reservation details here */}</div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Rewards View */}
        {view === 'rewards' && loyaltyRewards && (
          <div className="max-w-4xl mx-auto">
            <div className="bg-gray-800 rounded-lg border border-gray-700 p-8 mb-6">
              <div className="text-center mb-8">
                <div className={`text-6xl font-bold mb-2 ${getTierColor(loyaltyRewards.tier)}`}>{loyaltyRewards.tier.toUpperCase()} TIER</div>
                <div className="text-4xl font-bold mb-2">{loyaltyRewards.points} Points</div>
                <div className="text-gray-400">Worth ${'{'}loyaltyRewards.pointsValue{'}'} in rewards</div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="bg-gray-700 p-4 rounded text-center">
                  <div className="text-3xl mb-2">💳</div>
                  <div className="font-bold">{(loyaltyRewards.benefits.discount * 100).toFixed(0)}% Discount</div>
                  <div className="text-sm text-gray-400">On fuel purchases</div>
                </div>
                <div className="bg-gray-700 p-4 rounded text-center">
                  <div className="text-3xl mb-2">🚿</div>
                  <div className="font-bold">{loyaltyRewards.benefits.showerCredits} Free Showers</div>
                  <div className="text-sm text-gray-400">Per month</div>
                </div>
                <div className="bg-gray-700 p-4 rounded text-center">
                  <div className="text-3xl mb-2">🅿️</div>
                  <div className="font-bold">{loyaltyRewards.benefits.freeParking} Free Nights</div>
                  <div className="text-sm text-gray-400">Per month</div>
                </div>
              </div>
            </div>
            <div className="bg-gray-800 rounded-lg border border-gray-700 p-6">
              <h3 className="text-xl font-bold mb-4">Redeem Points</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <button className="bg-blue-600 hover:bg-blue-700 p-4 rounded font-semibold transition text-left">
                  <div className="text-2xl mb-2">⛽</div>
                  <div className="font-bold mb-1">$10 Fuel Credit</div>
                  <div className="text-sm text-gray-300">1,000 points</div>
                </button>
                <button className="bg-purple-600 hover:bg-purple-700 p-4 rounded font-semibold transition text-left">
                  <div className="text-2xl mb-2">🍔</div>
                  <div className="font-bold mb-1">Free Meal</div>
                  <div className="text-sm text-gray-300">500 points</div>
                </button>
                <button className="bg-green-600 hover:bg-green-700 p-4 rounded font-semibold transition text-left">
                  <div className="text-2xl mb-2">🚿</div>
                  <div className="font-bold mb-1">Free Shower</div>
                  <div className="text-sm text-gray-300">300 points</div>
                </button>
                <button className="bg-orange-600 hover:bg-orange-700 p-4 rounded font-semibold transition text-left">
                  <div className="text-2xl mb-2">🅿️</div>
                  <div className="font-bold mb-1">Free Parking</div>
                  <div className="text-sm text-gray-300">200 points</div>
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Booking Modal */}
      {showBooking && selectedStop && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-800 rounded-lg max-w-md w-full p-6">
            <h2 className="text-2xl font-bold mb-4">Reserve Parking</h2>
            <p className="text-gray-400 mb-4">{selectedStop.name}</p>
            <form onSubmit={handleBookParking} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Driver Name</label>
                <input type="text" value={bookingForm.driverName} onChange={(e) => setBookingForm({ ...bookingForm, driverName: e.target.value })} className="w-full px-3 py-2 bg-gray-700 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" required />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Truck Number</label>
                <input type="text" value={bookingForm.truckNumber} onChange={(e) => setBookingForm({ ...bookingForm, truckNumber: e.target.value })} className="w-full px-3 py-2 bg-gray-700 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" required />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Check-in</label>
                <input type="datetime-local" value={bookingForm.checkIn} onChange={(e) => setBookingForm({ ...bookingForm, checkIn: e.target.value })} className="w-full px-3 py-2 bg-gray-700 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" required />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Check-out</label>
                <input type="datetime-local" value={bookingForm.checkOut} onChange={(e) => setBookingForm({ ...bookingForm, checkOut: e.target.value })} className="w-full px-3 py-2 bg-gray-700 rounded border border-gray-600 focus:border-blue-500 focus:outline-none" required />
              </div>
              <div className="bg-gray-700 p-4 rounded">
                <div className="flex justify-between mb-2"><span>Parking Fee:</span><span className="font-bold">$25.00</span></div>
                {loyaltyRewards && loyaltyRewards.benefits.discount > 0 && (
                  <div className="flex justify-between text-green-400">
                    <span>Loyalty Discount ({(loyaltyRewards.benefits.discount * 100).toFixed(0)}%):</span>
                    <span>-${(25 * loyaltyRewards.benefits.discount).toFixed(2)}</span>
                  </div>
                )}
              </div>
              <div className="flex space-x-2">
                <button type="submit" className="flex-1 bg-blue-600 hover:bg-blue-700 px-4 py-3 rounded font-semibold transition">Confirm Booking</button>
                <button type="button" onClick={() => setShowBooking(false)} className="flex-1 bg-gray-700 hover:bg-gray-600 px-4 py-3 rounded font-semibold transition">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Fuel Comparison Modal */}
      {showFuelComparison && fuelComparison && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-800 rounded-lg max-w-2xl w-full p-6 max-h-[80vh] overflow-y-auto">
            <h2 className="text-2xl font-bold mb-4">Fuel Price Comparison</h2>
            <div className="bg-green-900/30 border border-green-600 rounded p-4 mb-4">
              <div className="font-bold text-lg mb-2">💰 Cheapest Option</div>
              <div className="mb-1">{fuelComparison.cheapest.name}</div>
              <div className="flex justify-between items-center">
                <span className="text-2xl font-bold text-green-400">${'{'}fuelComparison.cheapest.price{'}'}/gal</span>
                <span className="text-sm text-gray-400">{fuelComparison.cheapest.distance.toFixed(1)} mi away</span>
              </div>
              <div className="mt-2 text-sm text-green-400">Save ${'{'}fuelComparison.cheapest.savings{'}'} on 150 gallons</div>
            </div>
            <div className="mb-4">
              <div className="text-sm text-gray-400 mb-2">Area Average: ${'{'}fuelComparison.average{'}'}/gal</div>
            </div>
            <h3 className="font-bold mb-3">All Nearby Stops</h3>
            <div className="space-y-2">
              {fuelComparison.allStops.map((stop: any, index: number) => (
                <div key={index} className="bg-gray-700 p-3 rounded hover:bg-gray-600 transition cursor-pointer">
                  <div className="flex justify-between items-start mb-2">
                    <div className="font-semibold">{stop.name}</div>
                    <div className="text-lg font-bold text-green-400">${'{'}stop.price{'}'}</div>
                  </div>
                  <div className="text-sm text-gray-400">{stop.address}</div>
                  <div className="flex justify-between items-center mt-2 text-sm">
                    <span className="text-gray-400">{stop.distance.toFixed(1)} mi</span>
                    <span className="text-blue-400">DEF: ${'{'}stop.defPrice{'}'}</span>
                  </div>
                </div>
              ))}
            </div>
            <button onClick={() => setShowFuelComparison(false)} className="w-full mt-4 bg-blue-600 hover:bg-blue-700 px-4 py-2 rounded font-semibold transition">Close</button>
          </div>
        </div>
      )}
    </div>
  );
}
