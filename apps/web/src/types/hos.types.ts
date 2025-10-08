export type HOSStatus = 'off_duty' | 'sleeper_berth' | 'driving' | 'on_duty_not_driving';

export interface HOSEntry {
  id: string;
  driverId: string;
  status: HOSStatus;
  startTime: Date;
  endTime?: Date;
  location: {
    latitude: number;
    longitude: number;
    address?: string;
  };
  odometer?: number;
  engineHours?: number;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface HOSLimits {
  // 11-hour driving limit
  drivingTimeRemaining: number; // minutes
  drivingTimeUsed: number;
  
  // 14-hour on-duty window
  onDutyWindowRemaining: number; // minutes
  onDutyWindowStart?: Date;
  onDutyWindowEnd?: Date;
  
  // 70-hour/8-day limit (or 60-hour/7-day)
  cycleType: '70-hour-8-day' | '60-hour-7-day';
  cycleHoursRemaining: number; // minutes
  cycleHoursUsed: number;
  cyclePeriodStart: Date;
  cyclePeriodEnd: Date;
  
  // 10-hour break requirement
  consecutiveOffDutyRequired: number; // minutes
  lastBreakEnd?: Date;
  
  // 30-minute break requirement (8 hours of driving)
  breakRequired: boolean;
  breakRequiredBy?: Date;
  
  // 34-hour restart availability
  restartAvailable: boolean;
  restartEligibleAt?: Date;
}

export interface HOSViolation {
  id: string;
  type: 'driving_limit' | 'on_duty_window' | 'cycle_limit' | 'break_required' | 'off_duty_required';
  severity: 'warning' | 'critical' | 'violation';
  message: string;
  timestamp: Date;
  acknowledged: boolean;
}

export interface HOSWarning {
  type: string;
  severity: 'info' | 'warning' | 'critical';
  message: string;
  timeRemaining?: number; // minutes
  actionRequired?: string;
}
