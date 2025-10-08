import React, { useState } from 'react';
import { Bug, CheckCircle, XCircle } from 'lucide-react';

interface TestingHelperProps {
  enabled?: boolean;
}

export default function TestingHelper({ enabled = process.env.NODE_ENV === 'development' }: TestingHelperProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [tests, setTests] = useState({
    mapLoaded: false,
    vehiclesDisplayed: false,
    wsConnected: false,
    apisWorking: false,
    alertsWorking: false,
  });

  if (!enabled) return null;

  return (
    <div className="fixed bottom-4 right-4 z-50">
      {isOpen ? (
        <div className="bg-white rounded-lg shadow-2xl border w-80 p-4">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold flex items-center gap-2">
              <Bug className="w-5 h-5 text-purple-600" />
              Testing Checklist
            </h3>
            <button
              onClick={() => setIsOpen(false)}
              className="text-gray-400 hover:text-gray-600"
            >
              ×
            </button>
          </div>

          <div className="space-y-2">
            <TestItem
              label="Map Loaded"
              checked={tests.mapLoaded}
              onChange={(checked) => setTests({ ...tests, mapLoaded: checked })}
            />
            <TestItem
              label="Vehicles Displayed"
              checked={tests.vehiclesDisplayed}
              onChange={(checked) => setTests({ ...tests, vehiclesDisplayed: checked })}
            />
            <TestItem
              label="WebSocket Connected"
              checked={tests.wsConnected}
              onChange={(checked) => setTests({ ...tests, wsConnected: checked })}
            />
            <TestItem
              label="APIs Working"
              checked={tests.apisWorking}
              onChange={(checked) => setTests({ ...tests, apisWorking: checked })}
            />
            <TestItem
              label="Alerts Working"
              checked={tests.alertsWorking}
              onChange={(checked) => setTests({ ...tests, alertsWorking: checked })}
            />
          </div>

          <div className="mt-4 pt-4 border-t">
            <p className="text-sm text-gray-600">
              Progress: {Object.values(tests).filter(Boolean).length} / {Object.keys(tests).length}
            </p>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div
                className="bg-purple-600 h-2 rounded-full transition-all"
                style={{
                  width: `${(Object.values(tests).filter(Boolean).length / Object.keys(tests).length) * 100}%`,
                }}
              />
            </div>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setIsOpen(true)}
          className="bg-purple-600 text-white p-3 rounded-full shadow-lg hover:bg-purple-700 transition-colors"
          title="Open Testing Helper"
        >
          <Bug className="w-6 h-6" />
        </button>
      )}
    </div>
  );
}

function TestItem({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 p-2 hover:bg-gray-50 rounded cursor-pointer">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="rounded"
      />
      {checked ? (
        <CheckCircle className="w-4 h-4 text-green-600" />
      ) : (
        <XCircle className="w-4 h-4 text-gray-300" />
      )}
      <span className="text-sm text-gray-700">{label}</span>
    </label>
  );
}
