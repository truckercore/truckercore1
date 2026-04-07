import React, { useState } from 'react';
import { DashboardInstance, Widget } from '../../types/dashboard.types';

interface CustomDashboardBuilderProps {
  initialDashboard?: DashboardInstance;
  onSave: (dashboard: DashboardInstance) => void;
  availableWidgets: Array<{
    type: string;
    name: string;
    description: string;
    defaultSize: { width: number; height: number };
  }>;
}

export const CustomDashboardBuilder: React.FC<CustomDashboardBuilderProps> = ({
  initialDashboard,
  onSave,
  availableWidgets,
}) => {
  const [dashboard, setDashboard] = useState<Partial<DashboardInstance>>(
    initialDashboard || {
      name: 'New Dashboard',
      widgets: [],
    }
  );
  const [selectedWidget, setSelectedWidget] = useState<Widget | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [draggedWidget, setDraggedWidget] = useState<Widget | null>(null);

  const handleAddWidget = (widgetType: string) => {
    const widgetConfig = availableWidgets.find((w) => w.type === widgetType);
    if (!widgetConfig) return;

    const newWidget: Widget = {
      id: `widget-${Date.now()}`,
      type: widgetType,
      title: widgetConfig.name,
      position: { x: 0, y: 0 },
      size: widgetConfig.defaultSize,
      config: {},
    };

    setDashboard((prev) => ({ ...prev, widgets: [...(prev.widgets || []), newWidget] }));
  };

  const handleRemoveWidget = (widgetId: string) => {
    setDashboard((prev) => ({ ...prev, widgets: (prev.widgets || []).filter((w) => w.id !== widgetId) }));
    if (selectedWidget?.id === widgetId) setSelectedWidget(null);
  };

  const handleUpdateWidget = (widgetId: string, updates: Partial<Widget>) => {
    setDashboard((prev) => ({
      ...prev,
      widgets: (prev.widgets || []).map((w) => (w.id === widgetId ? { ...w, ...updates } : w)),
    }));
  };

  const handleWidgetDragStart = (widget: Widget) => {
    setIsDragging(true);
    setDraggedWidget(widget);
  };

  const handleWidgetDragEnd = () => {
    setIsDragging(false);
    setDraggedWidget(null);
  };

  const handleWidgetDrop = (e: React.DragEvent, x: number, y: number) => {
    e.preventDefault();
    if (draggedWidget) {
      handleUpdateWidget(draggedWidget.id, { position: { x, y } });
    }
    handleWidgetDragEnd();
  };

  const handleSave = () => {
    if (!dashboard.name || !dashboard.widgets) {
      alert('Please provide a dashboard name and add at least one widget');
      return;
    }

    const completeDashboard: DashboardInstance = {
      id: initialDashboard?.id || `dashboard-${Date.now()}`,
      userId: initialDashboard?.userId || 'current-user',
      templateId: initialDashboard?.templateId || 'custom',
      name: dashboard.name!,
      widgets: dashboard.widgets!,
      customizations: dashboard.customizations,
      createdAt: initialDashboard?.createdAt || new Date(),
      updatedAt: new Date(),
    };

    onSave(completeDashboard);
  };

  return (
    <div className="h-screen flex flex-col bg-gray-100">
      <div className="bg-white border-b border-gray-200 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <input
              type="text"
              value={dashboard.name || ''}
              onChange={(e) => setDashboard((prev) => ({ ...prev, name: e.target.value }))}
              className="text-2xl font-bold border-none focus:outline-none focus:ring-2 focus:ring-blue-500 rounded px-2"
              placeholder="Dashboard Name"
            />
          </div>
          <div className="flex gap-2">
            <button onClick={handleSave} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500">
              Save Dashboard
            </button>
          </div>
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden">
        <div className="w-64 bg-white border-r border-gray-200 overflow-y-auto p-4">
          <h3 className="text-lg font-semibold mb-4">Available Widgets</h3>
          <div className="space-y-2">
            {availableWidgets.map((widget) => (
              <button
                key={widget.type}
                onClick={() => handleAddWidget(widget.type)}
                className="w-full text-left p-3 border border-gray-200 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors"
              >
                <div className="font-medium text-sm">{widget.name}</div>
                <div className="text-xs text-gray-500 mt-1">{widget.description}</div>
              </button>
            ))}
          </div>
        </div>

        <div className="flex-1 overflow-auto p-6">
          <div
            className="relative bg-white rounded-lg shadow-sm min-h-full"
            style={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gridTemplateRows: 'repeat(auto-fill, 100px)', gap: '16px', padding: '24px' }}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => handleWidgetDrop(e, 0, 0)}
          >
            {dashboard.widgets?.length === 0 ? (
              <div className="col-span-12 row-span-4 flex items-center justify-center text-gray-400">
                <div className="text-center">
                  <svg className="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2" />
                  </svg>
                  <p className="text-lg font-medium">No widgets added yet</p>
                  <p className="text-sm mt-1">Add widgets from the sidebar to build your dashboard</p>
                </div>
              </div>
            ) : (
              dashboard.widgets?.map((widget) => (
                <div
                  key={widget.id}
                  draggable
                  onDragStart={() => handleWidgetDragStart(widget)}
                  onDragEnd={handleWidgetDragEnd}
                  onClick={() => setSelectedWidget(widget)}
                  style={{ gridColumn: `span ${widget.size.width}`, gridRow: `span ${widget.size.height}` }}
                  className={`relative bg-white border-2 rounded-lg p-4 cursor-move transition-all ${selectedWidget?.id === widget.id ? 'border-blue-500 shadow-lg' : 'border-gray-200 hover:border-gray-300'}`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <h4 className="font-semibold text-sm">{widget.title}</h4>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleRemoveWidget(widget.id);
                      }}
                      className="text-gray-400 hover:text-red-600"
                    >
                      <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                      </svg>
                    </button>
                  </div>
                  <div className="flex items-center justify-center h-full text-gray-400 text-sm">{widget.type} widget</div>
                  <div className="absolute bottom-0 right-0 w-4 h-4 cursor-se-resize">
                    <svg className="w-full h-full text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M18 18L12 12M18 14L14 18" />
                    </svg>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {selectedWidget && (
          <div className="w-80 bg-white border-l border-gray-200 overflow-y-auto p-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Widget Properties</h3>
              <button onClick={() => setSelectedWidget(null)} className="text-gray-400 hover:text-gray-600">
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
                <input
                  type="text"
                  value={selectedWidget.title}
                  onChange={(e) => handleUpdateWidget(selectedWidget.id, { title: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Width (columns)</label>
                <input
                  type="number"
                  min={1}
                  max={12}
                  value={selectedWidget.size.width}
                  onChange={(e) => handleUpdateWidget(selectedWidget.id, { size: { ...selectedWidget.size, width: parseInt(e.target.value) } })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Height (rows)</label>
                <input
                  type="number"
                  min={1}
                  max={10}
                  value={selectedWidget.size.height}
                  onChange={(e) => handleUpdateWidget(selectedWidget.id, { size: { ...selectedWidget.size, height: parseInt(e.target.value) } })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div className="pt-4 border-t border-gray-200">
                <h4 className="text-sm font-medium text-gray-700 mb-2">Widget Configuration</h4>
                <div className="text-sm text-gray-500">Additional configuration options for {selectedWidget.type} widget</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
