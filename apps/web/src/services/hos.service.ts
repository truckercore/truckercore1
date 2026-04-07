import { HOSEntry, HOSLimits, HOSStatus, HOSViolation, HOSWarning } from '@/types/hos.types';

export class HOSService {
  // FMCSA Limits (in minutes)
  private static readonly LIMITS = {
    DRIVING_LIMIT: 11 * 60,              // 11 hours
    ON_DUTY_WINDOW: 14 * 60,             // 14 hours
    OFF_DUTY_REQUIRED: 10 * 60,          // 10 hours
    BREAK_REQUIRED_AFTER: 8 * 60,        // 8 hours
    BREAK_DURATION: 30,                  // 30 minutes
    CYCLE_70_8: 70 * 60,                 // 70 hours in 8 days
    CYCLE_60_7: 60 * 60,                 // 60 hours in 7 days
    RESTART_REQUIRED: 34 * 60,           // 34 hours
    WARNING_THRESHOLD: 30,               // 30 minutes warning
  };

  /**
   * Calculate current HOS limits for a driver
   */
  static calculateHOSLimits(
    entries: HOSEntry[],
    cycleType: '70-hour-8-day' | '60-hour-7-day' = '70-hour-8-day'
  ): HOSLimits {
    const onDutyWindow = this.calculateOnDutyWindow(entries);

    const { drivingTimeUsed } = this.calculateDrivingTime(entries);
    const drivingTimeRemaining = Math.max(0, this.LIMITS.DRIVING_LIMIT - drivingTimeUsed);

    const cycleLimit = cycleType === '70-hour-8-day' 
      ? this.LIMITS.CYCLE_70_8 
      : this.LIMITS.CYCLE_60_7;
    const cycleDays = cycleType === '70-hour-8-day' ? 8 : 7;
    const cycleHours = this.calculateCycleHours(entries, cycleDays);

    const breakStatus = this.calculateBreakRequirement(entries);

    const restartStatus = this.calculateRestartEligibility(entries);

    return {
      drivingTimeRemaining,
      drivingTimeUsed,
      onDutyWindowRemaining: onDutyWindow.remaining,
      onDutyWindowStart: onDutyWindow.start,
      onDutyWindowEnd: onDutyWindow.end,
      cycleType,
      cycleHoursRemaining: Math.max(0, cycleLimit - cycleHours.used),
      cycleHoursUsed: cycleHours.used,
      cyclePeriodStart: cycleHours.periodStart,
      cyclePeriodEnd: cycleHours.periodEnd,
      consecutiveOffDutyRequired: this.LIMITS.OFF_DUTY_REQUIRED,
      lastBreakEnd: this.findLastBreak(entries)?.endTime,
      breakRequired: breakStatus.required,
      breakRequiredBy: breakStatus.requiredBy,
      restartAvailable: restartStatus.available,
      restartEligibleAt: restartStatus.eligibleAt,
    };
  }

  /**
   * Calculate driving time since last 10-hour break
   */
  private static calculateDrivingTime(entries: HOSEntry[]): {
    drivingTimeUsed: number;
    lastDrivingStart?: Date;
  } {
    let drivingTime = 0;
    const lastBreakIndex = this.findLastQualifyingBreakIndex(entries);
    
    const relevantEntries = lastBreakIndex >= 0 
      ? entries.slice(lastBreakIndex + 1)
      : entries;
    
    for (const entry of relevantEntries) {
      if (entry.status === 'driving') {
        const endTime = entry.endTime || new Date();
        const duration = (endTime.getTime() - new Date(entry.startTime).getTime()) / 60000;
        drivingTime += duration;
      }
    }
    
    const lastDriving = relevantEntries.find(e => e.status === 'driving' && !e.endTime);
    
    return {
      drivingTimeUsed: drivingTime,
      lastDrivingStart: lastDriving?.startTime,
    };
  }

  /**
   * Calculate 14-hour on-duty window
   */
  private static calculateOnDutyWindow(entries: HOSEntry[]): {
    remaining: number;
    start?: Date;
    end?: Date;
  } {
    const lastBreakIndex = this.findLastQualifyingBreakIndex(entries);
    const relevantEntries = lastBreakIndex >= 0 
      ? entries.slice(lastBreakIndex + 1)
      : entries;
    
    if (relevantEntries.length === 0) {
      return { remaining: this.LIMITS.ON_DUTY_WINDOW };
    }
    
    const firstOnDutyEntry = relevantEntries.find(
      e => e.status !== 'off_duty' && e.status !== 'sleeper_berth'
    );
    
    if (!firstOnDutyEntry) {
      return { remaining: this.LIMITS.ON_DUTY_WINDOW };
    }
    
    const windowStart = new Date(firstOnDutyEntry.startTime);
    const windowEnd = new Date(windowStart.getTime() + this.LIMITS.ON_DUTY_WINDOW * 60000);
    const now = new Date();
    
    const elapsed = (now.getTime() - windowStart.getTime()) / 60000;
    const remaining = Math.max(0, this.LIMITS.ON_DUTY_WINDOW - elapsed);
    
    return {
      remaining,
      start: windowStart,
      end: windowEnd,
    };
  }

  /**
   * Calculate cycle hours (70/8 or 60/7)
   */
  private static calculateCycleHours(entries: HOSEntry[], days: number): {
    used: number;
    periodStart: Date;
    periodEnd: Date;
  } {
    const now = new Date();
    const periodStart = new Date(now.getTime() - (days * 24 * 60 * 60 * 1000));
    
    let totalOnDutyTime = 0;
    
    for (const entry of entries) {
      const start = new Date(entry.startTime);
      if (start < periodStart) continue;
      
      if (entry.status !== 'off_duty') {
        const endTime = entry.endTime ? new Date(entry.endTime) : now;
        const duration = (endTime.getTime() - start.getTime()) / 60000;
        totalOnDutyTime += duration;
      }
    }
    
    return {
      used: totalOnDutyTime,
      periodStart,
      periodEnd: now,
    };
  }

  /**
   * Calculate 30-minute break requirement
   */
  private static calculateBreakRequirement(entries: HOSEntry[]): {
    required: boolean;
    requiredBy?: Date;
  } {
    let continuousDrivingTime = 0;
    let lastBreakTime: Date | null = null;
    let drivingStartAfterBreak: Date | null = null;
    
    for (const entry of entries) {
      if (entry.status === 'driving') {
        if (!drivingStartAfterBreak) {
          drivingStartAfterBreak = new Date(entry.startTime);
        }
        const endTime = entry.endTime ? new Date(entry.endTime) : new Date();
        continuousDrivingTime += (endTime.getTime() - new Date(entry.startTime).getTime()) / 60000;
      } else if (this.isQualifyingBreak(entry, this.LIMITS.BREAK_DURATION)) {
        continuousDrivingTime = 0;
        lastBreakTime = entry.endTime ? new Date(entry.endTime) : null;
        drivingStartAfterBreak = null;
      }
    }
    
    const breakRequired = continuousDrivingTime >= this.LIMITS.BREAK_REQUIRED_AFTER;
    const requiredBy = drivingStartAfterBreak 
      ? new Date(drivingStartAfterBreak.getTime() + this.LIMITS.BREAK_REQUIRED_AFTER * 60000)
      : undefined;
    
    return { required: breakRequired, requiredBy };
  }

  /**
   * Calculate 34-hour restart eligibility
   */
  private static calculateRestartEligibility(entries: HOSEntry[]): {
    available: boolean;
    eligibleAt?: Date;
  } {
    const lastOffDutyPeriod = this.findLastOffDutyPeriod(entries);
    
    if (!lastOffDutyPeriod) {
      return { available: false };
    }
    
    const start = new Date(lastOffDutyPeriod.startTime);
    const offDutyDuration = lastOffDutyPeriod.endTime
      ? (new Date(lastOffDutyPeriod.endTime).getTime() - start.getTime()) / 60000
      : (new Date().getTime() - start.getTime()) / 60000;
    
    const available = offDutyDuration >= this.LIMITS.RESTART_REQUIRED;
    const eligibleAt = !available
      ? new Date(start.getTime() + this.LIMITS.RESTART_REQUIRED * 60000)
      : undefined;
    
    return { available, eligibleAt };
  }

  /**
   * Generate HOS warnings based on current status
   */
  static generateWarnings(limits: HOSLimits, currentStatus: HOSStatus): HOSWarning[] {
    const warnings: HOSWarning[] = [];
    
    // Driving time warnings
    if (currentStatus === 'driving' && limits.drivingTimeRemaining <= this.LIMITS.WARNING_THRESHOLD) {
      warnings.push({
        type: 'driving_limit',
        severity: limits.drivingTimeRemaining <= 15 ? 'critical' : 'warning',
        message: `Only ${Math.floor(limits.drivingTimeRemaining)} minutes of driving time remaining`,
        timeRemaining: limits.drivingTimeRemaining,
        actionRequired: 'Prepare to stop driving and take required break',
      });
    }
    
    // 14-hour window warnings
    if (limits.onDutyWindowRemaining <= this.LIMITS.WARNING_THRESHOLD) {
      warnings.push({
        type: 'on_duty_window',
        severity: limits.onDutyWindowRemaining <= 15 ? 'critical' : 'warning',
        message: `14-hour window expires in ${Math.floor(limits.onDutyWindowRemaining)} minutes`,
        timeRemaining: limits.onDutyWindowRemaining,
        actionRequired: 'Must go off-duty soon',
      });
    }
    
    // Cycle limit warnings
    const cyclePercentUsed = (limits.cycleHoursUsed / (limits.cycleType === '70-hour-8-day' ? this.LIMITS.CYCLE_70_8 : this.LIMITS.CYCLE_60_7)) * 100;
    if (cyclePercentUsed >= 90) {
      warnings.push({
        type: 'cycle_limit',
        severity: cyclePercentUsed >= 95 ? 'critical' : 'warning',
        message: `${Math.round(cyclePercentUsed)}% of ${limits.cycleType} cycle used`,
        timeRemaining: limits.cycleHoursRemaining,
        actionRequired: limits.restartAvailable ? 'Consider 34-hour restart' : 'Monitor cycle hours',
      });
    }
    
    // Break requirement warning
    if (limits.breakRequired) {
      warnings.push({
        type: 'break_required',
        severity: 'critical',
        message: '30-minute break required before continuing to drive',
        actionRequired: 'Take 30-minute break',
      });
    }
    
    return warnings;
  }

  /**
   * Detect HOS violations
   */
  static detectViolations(entries: HOSEntry[], limits: HOSLimits): HOSViolation[] {
    const violations: HOSViolation[] = [];
    const now = new Date();
    
    // Check if currently driving with no time remaining
    const currentEntry = entries.find(e => !e.endTime);
    if (currentEntry?.status === 'driving') {
      if (limits.drivingTimeRemaining <= 0) {
        violations.push({
          id: `violation-${now.getTime()}-driving`,
          type: 'driving_limit',
          severity: 'violation',
          message: '11-hour driving limit exceeded',
          timestamp: now,
          acknowledged: false,
        });
      }
      
      if (limits.onDutyWindowRemaining <= 0) {
        violations.push({
          id: `violation-${now.getTime()}-window`,
          type: 'on_duty_window',
          severity: 'violation',
          message: '14-hour on-duty window exceeded',
          timestamp: now,
          acknowledged: false,
        });
      }
    }
    
    // Check cycle limit
    if (limits.cycleHoursRemaining <= 0) {
      violations.push({
        id: `violation-${now.getTime()}-cycle`,
        type: 'cycle_limit',
        severity: 'violation',
        message: `${limits.cycleType} limit exceeded`,
        timestamp: now,
        acknowledged: false,
      });
    }
    
    return violations;
  }

  /**
   * Helper: Find last qualifying break (10+ hours off-duty or sleeper berth)
   */
  private static findLastQualifyingBreakIndex(entries: HOSEntry[]): number {
    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i];
      if (this.isQualifyingBreak(entry, this.LIMITS.OFF_DUTY_REQUIRED)) {
        return i;
      }
    }
    return -1;
  }

  private static findLastBreak(entries: HOSEntry[]): HOSEntry | undefined {
    const index = this.findLastQualifyingBreakIndex(entries);
    return index >= 0 ? entries[index] : undefined;
  }

  /**
   * Helper: Check if entry is a qualifying break
   */
  private static isQualifyingBreak(entry: HOSEntry, minDuration: number): boolean {
    if (entry.status !== 'off_duty' && entry.status !== 'sleeper_berth') {
      return false;
    }
    if (!entry.endTime) return false;
    
    const duration = (new Date(entry.endTime).getTime() - new Date(entry.startTime).getTime()) / 60000;
    return duration >= minDuration;
  }

  /**
   * Helper: Find last off-duty period for restart calculation
   */
  private static findLastOffDutyPeriod(entries: HOSEntry[]): HOSEntry | null {
    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i];
      if (entry.status === 'off_duty' || entry.status === 'sleeper_berth') {
        return entry;
      }
    }
    return null;
  }

  /**
   * Format time remaining in human-readable format
   */
  static formatTimeRemaining(minutes: number): string {
    const hours = Math.floor(minutes / 60);
    const mins = Math.floor(minutes % 60);
    
    if (hours === 0) {
      return `${mins}m`;
    }
    return `${hours}h ${mins}m`;
  }
}
