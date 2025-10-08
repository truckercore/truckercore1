import React, { useEffect, useMemo, useState } from 'react';
import { Filter, X, ChevronDown, Search } from 'lucide-react';
import debounce from 'lodash.debounce';

const ADVANCED_FILTERS = process.env.NEXT_PUBLIC_ENABLE_ADVANCED_FILTERS === 'true';

export interface FilterOption {
  id: string;
  label: string;
  type: 'select' | 'multiselect' | 'range' | 'date' | 'search';
  options?: { value: string; label: string }[];
  min?: number;
  max?: number;
}

interface AdvancedFiltersProps {
  filters: FilterOption[];
  onFilterChange: (filters: Record<string, any>) => void;
  initialValues?: Record<string, any>;
}

export default function AdvancedFilters({ filters, onFilterChange, initialValues = {} }: AdvancedFiltersProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [values, setValues] = useState<Record<string, any>>(initialValues);
  const [searchTerm, setSearchTerm] = useState('');

  const debouncedFilterChange = useMemo(
    () =>
      debounce((newValues: Record<string, any>) => {
        onFilterChange(newValues);
      }, 300),
    [onFilterChange]
  );

  useEffect(() => {
    debouncedFilterChange(values);
    return () => {
      debouncedFilterChange.cancel();
    };
  }, [values, debouncedFilterChange]);

  const handleValueChange = (filterId: string, value: any) => {
    setValues((prev) => ({ ...prev, [filterId]: value }));
  };

  const handleClear = () => {
    setValues({});
    onFilterChange({});
  };

  const getActiveFilterCount = () => {
    return Object.values(values).filter((v) =>
      v !== undefined && v !== '' && v !== null && (Array.isArray(v) ? v.length > 0 : true)
    ).length;
  };

  if (!ADVANCED_FILTERS) {
    return (
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          placeholder="Search..."
          value={searchTerm}
          onChange={(e) => {
            setSearchTerm(e.target.value);
            onFilterChange({ search: e.target.value });
          }}
          className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
      </div>
    );
  }

  return (
    <div className="relative">
      <button
        onClick={() => setIsOpen((s) => !s)}
        className="flex items-center gap-2 px-4 py-2 border rounded-lg hover:bg-gray-50 transition-colors"
      >
        <Filter className="w-4 h-4" />
        <span>Filters</span>
        {getActiveFilterCount() > 0 && (
          <span className="px-2 py-0.5 bg-blue-600 text-white text-xs rounded-full">
            {getActiveFilterCount()}
          </span>
        )}
        <ChevronDown className={`w-4 h-4 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {isOpen && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setIsOpen(false)} />
          <div className="absolute top-full mt-2 right-0 bg-white rounded-lg shadow-xl border z-20 w-96 max-h-96 overflow-y-auto">
            <div className="p-4 border-b flex items-center justify-between sticky top-0 bg-white">
              <h3 className="font-semibold">Advanced Filters</h3>
              <div className="flex items-center gap-2">
                {getActiveFilterCount() > 0 && (
                  <button onClick={handleClear} className="text-sm text-blue-600 hover:text-blue-700">
                    Clear all
                  </button>
                )}
                <button onClick={() => setIsOpen(false)} className="text-gray-400 hover:text-gray-600">
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            <div className="p-4 space-y-4">
              {filters.map((filter) => (
                <FilterField key={filter.id} filter={filter} value={values[filter.id]} onChange={(v) => handleValueChange(filter.id, v)} />
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

function FilterField({ filter, value, onChange }: { filter: FilterOption; value: any; onChange: (value: any) => void }) {
  switch (filter.type) {
    case 'search':
      return (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
          <input
            type="text"
            value={value || ''}
            onChange={(e) => onChange(e.target.value)}
            placeholder={`Search ${filter.label.toLowerCase()}...`}
            className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      );
    case 'select':
      return (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
          <select
            value={value || ''}
            onChange={(e) => onChange(e.target.value)}
            className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">All</option>
            {filter.options?.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      );
    case 'multiselect':
      return (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
          <div className="space-y-2 max-h-40 overflow-y-auto border rounded-lg p-2">
            {filter.options?.map((option) => (
              <label key={option.value} className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={Array.isArray(value) && value.includes(option.value)}
                  onChange={(e) => {
                    const currentValues = Array.isArray(value) ? value : [];
                    if (e.target.checked) {
                      onChange([...currentValues, option.value]);
                    } else {
                      onChange(currentValues.filter((v: string) => v !== option.value));
                    }
                  }}
                  className="rounded"
                />
                <span className="text-sm">{option.label}</span>
              </label>
            ))}
          </div>
        </div>
      );
    case 'range':
      return (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
          <div className="flex items-center gap-2">
            <input
              type="number"
              placeholder="Min"
              value={value?.min || ''}
              onChange={(e) => onChange({ ...value, min: e.target.value ? Number(e.target.value) : undefined })}
              min={filter.min}
              max={filter.max}
              className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <span className="text-gray-500">to</span>
            <input
              type="number"
              placeholder="Max"
              value={value?.max || ''}
              onChange={(e) => onChange({ ...value, max: e.target.value ? Number(e.target.value) : undefined })}
              min={filter.min}
              max={filter.max}
              className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
        </div>
      );
    case 'date':
      return (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">{filter.label}</label>
          <div className="flex items-center gap-2">
            <input
              type="date"
              value={value?.start || ''}
              onChange={(e) => onChange({ ...value, start: e.target.value })}
              className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <span className="text-gray-500">to</span>
            <input
              type="date"
              value={value?.end || ''}
              onChange={(e) => onChange({ ...value, end: e.target.value })}
              className="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>
        </div>
      );
    default:
      return null;
  }
}
