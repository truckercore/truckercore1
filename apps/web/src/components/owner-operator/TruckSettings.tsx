'use client';

import { useEffect, useState } from 'react';

export default function TruckSettings() {
  const [settings, setSettings] = useState({
    mpg: 6.5,
    default_fuel_price: 4.20,
    gross_weight_lbs: 80000,
  });
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    fetch('/api/truck-settings')
      .then(r => r.json())
      .then(data => { if (data.settings) setSettings(data.settings); })
      .catch(() => {});
  }, []);

  const save = async () => {
    await fetch('/api/truck-settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(settings),
    });
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-5 text-white">
      <h3 className="font-bold text-lg mb-4">⚙️ Truck Settings</h3>
      <div className="space-y-3">
        {[
          { label: 'Miles Per Gallon (MPG)', key: 'mpg', step: 0.1 },
          { label: 'Fuel Price ($/gallon)', key: 'default_fuel_price', step: 0.01 },
          { label: 'Gross Weight (lbs)', key: 'gross_weight_lbs', step: 1000 },
        ].map(field => (
          <div key={field.key}>
            <label className="text-gray-400 text-xs">{field.label}</label>
            <input
              type="number"
              step={field.step}
              value={settings[field.key as keyof typeof settings]}
              onChange={e => setSettings(prev => ({
                ...prev, [field.key]: Number(e.target.value)
              }))}
              className="w-full mt-1 bg-gray-800 border border-gray-700 text-white rounded-lg px-3 py-2 text-sm focus:border-blue-500 outline-none"
            />
          </div>
        ))}
        <button
          onClick={save}
          className="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded-lg text-sm transition"
        >
          {saved ? '✓ Saved!' : 'Save Settings'}
        </button>
      </div>
    </div>
  );
}
