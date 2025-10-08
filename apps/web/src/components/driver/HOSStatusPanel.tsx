"use client";
import React from 'react';
import { HOSLimits, HOSWarning, HOSStatus } from '@/types/hos.types';
import { HOSService } from '@/services/hos.service';

interface HOSStatusPanelProps {
  limits: HOSLimits | null;
  warnings: HOSWarning[];
  currentStatus: HOSStatus;
  onStatusChange: (status: HOSStatus) => void;
}

export default function HOSStatusPanel({
  limits,
  warnings,
  currentStatus,
  onStatusChange,
}: HOSStatusPanelProps) {
  if (!limits) {
    return <div className="hos-panel loading">Loading HOS data...</div>;
  }

  const statusOptions: { value: HOSStatus; label: string; icon: string }[] = [
    { value: 'off_duty', label: 'Off Duty', icon: '🛏️' },
    { value: 'sleeper_berth', label: 'Sleeper', icon: '😴' },
    { value: 'driving', label: 'Driving', icon: '🚛' },
    { value: 'on_duty_not_driving', label: 'On Duty', icon: '📋' },
  ];

  const canDrive = limits.drivingTimeRemaining > 0 && 
                   limits.onDutyWindowRemaining > 0 && 
                   !limits.breakRequired;

  return (
    <div className="hos-panel">
      <h2>Hours of Service</h2>

      {/* Warnings */}
      {warnings.length > 0 && (
        <div className="hos-warnings">
          {warnings.map((warning, index) => (
            <div 
              key={index} 
              className={`warning warning-${warning.severity}`}
            >
              <span className="warning-icon">
                {warning.severity === 'critical' ? '🚨' : '⚠️'}
              </span>
              <div className="warning-content">
                <div className="warning-message">{warning.message}</div>
                {warning.actionRequired && (
                  <div className="warning-action">{warning.actionRequired}</div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Current Status */}
      <div className="current-status">
        <h3>Current Status</h3>
        <div className="status-buttons">
          {statusOptions.map(option => (
            <button
              key={option.value}
              className={`status-button ${currentStatus === option.value ? 'active' : ''}`}
              onClick={() => onStatusChange(option.value)}
              disabled={option.value === 'driving' && !canDrive}
            >
              <span className="status-icon">{option.icon}</span>
              <span className="status-label">{option.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Time Limits */}
      <div className="time-limits">
        <div className="limit-card">
          <div className="limit-label">Driving Time</div>
          <div className={`limit-value ${limits.drivingTimeRemaining <= 30 ? 'critical' : ''}`}>
            {HOSService.formatTimeRemaining(limits.drivingTimeRemaining)}
          </div>
          <div className="limit-subtitle">
            of 11 hours remaining
          </div>
          <div className="limit-bar">
            <div 
              className="limit-bar-fill"
              style={{ 
                width: `${(limits.drivingTimeUsed / (11 * 60)) * 100}%`,
              }}
            />
          </div>
        </div>

        <div className="limit-card">
          <div className="limit-label">On-Duty Window</div>
          <div className={`limit-value ${limits.onDutyWindowRemaining <= 30 ? 'critical' : ''}`}>
            {HOSService.formatTimeRemaining(limits.onDutyWindowRemaining)}
          </div>
          <div className="limit-subtitle">
            of 14 hours remaining
          </div>
          <div className="limit-bar">
            <div 
              className="limit-bar-fill"
              style={{ 
                width: `${((14 * 60 - limits.onDutyWindowRemaining) / (14 * 60)) * 100}%`,
              }}
            />
          </div>
        </div>

        <div className="limit-card">
          <div className="limit-label">
            {limits.cycleType === '70-hour-8-day' ? '70-Hour Cycle' : '60-Hour Cycle'}
          </div>
          <div className="limit-value">
            {HOSService.formatTimeRemaining(limits.cycleHoursRemaining)}
          </div>
          <div className="limit-subtitle">
            remaining
          </div>
          <div className="limit-bar">
            <div 
              className="limit-bar-fill"
              style={{ 
                width: `${(limits.cycleHoursUsed / (limits.cycleType === '70-hour-8-day' ? 70 * 60 : 60 * 60)) * 100}%`,
              }}
            />
          </div>
        </div>
      </div>

      {/* Break Info */}
      {limits.breakRequired && (
        <div className="break-required">
          <span className="icon">⏱️</span>
          30-minute break required before continuing to drive
        </div>
      )}

      {/* Restart Info */}
      {limits.restartAvailable && (
        <div className="restart-available">
          <span className="icon">🔄</span>
          34-hour restart available - cycle will reset
        </div>
      )}
    </div>
  );
}
