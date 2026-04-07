import { DashboardTemplate, UserRole } from '../types/dashboard.types';

class DashboardTemplateService {
  private templates: Map<string, DashboardTemplate> = new Map();

  constructor() {
    this.initializeDefaultTemplates();
  }

  private initializeDefaultTemplates(): void {
    // Admin Dashboard
    this.templates.set('admin-default', {
      id: 'admin-default',
      name: 'Admin Dashboard',
      description: 'Comprehensive overview for administrators',
      role: UserRole.ADMIN,
      layout: 'grid',
      refreshInterval: 30000,
      isDefault: true,
      widgets: [
        {
          id: 'admin-users',
          type: 'user-stats',
          title: 'User Statistics',
          position: { x: 0, y: 0 },
          size: { width: 4, height: 2 },
          config: { showGrowth: true, showActive: true, timeRange: '30d' },
        },
        {
          id: 'admin-system',
          type: 'system-health',
          title: 'System Health',
          position: { x: 4, y: 0 },
          size: { width: 4, height: 2 },
          config: { metrics: ['cpu', 'memory', 'disk', 'network'], alertThreshold: 80 },
        },
        {
          id: 'admin-activity',
          type: 'activity-log',
          title: 'Recent Activity',
          position: { x: 8, y: 0 },
          size: { width: 4, height: 4 },
          config: { limit: 20, types: ['user', 'system', 'security'] },
        },
        {
          id: 'admin-revenue',
          type: 'revenue-chart',
          title: 'Revenue Overview',
          position: { x: 0, y: 2 },
          size: { width: 8, height: 3 },
          config: { chartType: 'line', timeRange: '90d' },
        },
        {
          id: 'admin-alerts',
          type: 'alerts',
          title: 'System Alerts',
          position: { x: 0, y: 5 },
          size: { width: 6, height: 2 },
          config: { severity: ['high', 'critical'], autoRefresh: true },
        },
        {
          id: 'admin-performance',
          type: 'performance-metrics',
          title: 'Performance Metrics',
          position: { x: 6, y: 5 },
          size: { width: 6, height: 2 },
          config: { metrics: ['responseTime', 'throughput', 'errorRate'] },
        },
      ],
    });

    // Manager Dashboard
    this.templates.set('manager-default', {
      id: 'manager-default',
      name: 'Manager Dashboard',
      description: 'Team and project management overview',
      role: UserRole.MANAGER,
      layout: 'grid',
      refreshInterval: 60000,
      isDefault: true,
      widgets: [
        {
          id: 'manager-team',
          type: 'team-performance',
          title: 'Team Performance',
          position: { x: 0, y: 0 },
          size: { width: 6, height: 3 },
          config: { showIndividual: true, showTrends: true },
        },
        {
          id: 'manager-projects',
          type: 'project-status',
          title: 'Project Status',
          position: { x: 6, y: 0 },
          size: { width: 6, height: 3 },
          config: { view: 'kanban', showDeadlines: true },
        },
        {
          id: 'manager-kpi',
          type: 'kpi-metrics',
          title: 'Key Performance Indicators',
          position: { x: 0, y: 3 },
          size: { width: 8, height: 2 },
          config: { metrics: ['productivity', 'quality', 'delivery'], comparison: 'monthly' },
        },
        {
          id: 'manager-tasks',
          type: 'task-list',
          title: 'Pending Tasks',
          position: { x: 8, y: 3 },
          size: { width: 4, height: 4 },
          config: { filter: 'assigned-to-team', sortBy: 'priority' },
        },
        {
          id: 'manager-budget',
          type: 'budget-tracker',
          title: 'Budget Overview',
          position: { x: 0, y: 5 },
          size: { width: 8, height: 2 },
          config: { showProjection: true, alertOnOverspend: true },
        },
      ],
    });

    // Analyst Dashboard
    this.templates.set('analyst-default', {
      id: 'analyst-default',
      name: 'Analyst Dashboard',
      description: 'Data analysis and reporting tools',
      role: UserRole.ANALYST,
      layout: 'grid',
      refreshInterval: 120000,
      isDefault: true,
      widgets: [
        {
          id: 'analyst-trends',
          type: 'trend-analysis',
          title: 'Trend Analysis',
          position: { x: 0, y: 0 },
          size: { width: 8, height: 3 },
          config: { dataSource: 'multiple', chartTypes: ['line', 'bar', 'scatter'] },
        },
        {
          id: 'analyst-metrics',
          type: 'metric-cards',
          title: 'Key Metrics',
          position: { x: 8, y: 0 },
          size: { width: 4, height: 3 },
          config: { metrics: ['conversion', 'retention', 'churn'], showComparison: true },
        },
        {
          id: 'analyst-data',
          type: 'data-table',
          title: 'Data Explorer',
          position: { x: 0, y: 3 },
          size: { width: 12, height: 4 },
          config: { exportEnabled: true, filterEnabled: true, sortEnabled: true },
        },
        {
          id: 'analyst-reports',
          type: 'report-list',
          title: 'Generated Reports',
          position: { x: 0, y: 7 },
          size: { width: 6, height: 2 },
          config: { showScheduled: true, allowDownload: true },
        },
        {
          id: 'analyst-visualization',
          type: 'custom-chart',
          title: 'Custom Visualization',
          position: { x: 6, y: 7 },
          size: { width: 6, height: 2 },
          config: { editable: true, shareEnabled: true },
        },
      ],
    });

    // Developer Dashboard
    this.templates.set('developer-default', {
      id: 'developer-default',
      name: 'Developer Dashboard',
      description: 'Development metrics and CI/CD status',
      role: UserRole.DEVELOPER,
      layout: 'grid',
      refreshInterval: 30000,
      isDefault: true,
      widgets: [
        {
          id: 'dev-builds',
          type: 'build-status',
          title: 'Build Status',
          position: { x: 0, y: 0 },
          size: { width: 6, height: 2 },
          config: { showHistory: true, branches: ['main', 'develop'] },
        },
        {
          id: 'dev-deployments',
          type: 'deployment-status',
          title: 'Deployments',
          position: { x: 6, y: 0 },
          size: { width: 6, height: 2 },
          config: { environments: ['dev', 'staging', 'production'], showLogs: true },
        },
        {
          id: 'dev-issues',
          type: 'issue-tracker',
          title: 'Issues & Bugs',
          position: { x: 0, y: 2 },
          size: { width: 4, height: 3 },
          config: { filter: 'assigned-to-me', showPriority: true },
        },
        {
          id: 'dev-pr',
          type: 'pull-requests',
          title: 'Pull Requests',
          position: { x: 4, y: 2 },
          size: { width: 4, height: 3 },
          config: { showReviews: true, showCI: true },
        },
        {
          id: 'dev-code-quality',
          type: 'code-metrics',
          title: 'Code Quality',
          position: { x: 8, y: 2 },
          size: { width: 4, height: 3 },
          config: { metrics: ['coverage', 'complexity', 'duplication'] },
        },
        {
          id: 'dev-api',
          type: 'api-health',
          title: 'API Health',
          position: { x: 0, y: 5 },
          size: { width: 12, height: 2 },
          config: { endpoints: [], showLatency: true, showErrors: true },
        },
      ],
    });

    // Sales Dashboard
    this.templates.set('sales-default', {
      id: 'sales-default',
      name: 'Sales Dashboard',
      description: 'Sales performance and pipeline tracking',
      role: UserRole.SALES,
      layout: 'grid',
      refreshInterval: 60000,
      isDefault: true,
      widgets: [
        {
          id: 'sales-revenue',
          type: 'revenue-chart',
          title: 'Sales Revenue',
          position: { x: 0, y: 0 },
          size: { width: 8, height: 3 },
          config: { timeRange: '12m', showTarget: true, showForecast: true },
        },
        {
          id: 'sales-quota',
          type: 'quota-tracker',
          title: 'Quota Achievement',
          position: { x: 8, y: 0 },
          size: { width: 4, height: 3 },
          config: { period: 'monthly', showTeam: true },
        },
        {
          id: 'sales-pipeline',
          type: 'pipeline-view',
          title: 'Sales Pipeline',
          position: { x: 0, y: 3 },
          size: { width: 12, height: 4 },
          config: { stages: ['prospect', 'qualified', 'proposal', 'negotiation', 'closed'], showValue: true },
        },
        {
          id: 'sales-leads',
          type: 'lead-list',
          title: 'Hot Leads',
          position: { x: 0, y: 7 },
          size: { width: 6, height: 2 },
          config: { filter: 'high-priority', limit: 10 },
        },
        {
          id: 'sales-activities',
          type: 'activity-tracker',
          title: 'Activities',
          position: { x: 6, y: 7 },
          size: { width: 6, height: 2 },
          config: { types: ['calls', 'meetings', 'emails'], showUpcoming: true },
        },
      ],
    });

    // Viewer Dashboard
    this.templates.set('viewer-default', {
      id: 'viewer-default',
      name: 'Viewer Dashboard',
      description: 'Read-only overview',
      role: UserRole.VIEWER,
      layout: 'grid',
      refreshInterval: 300000,
      isDefault: true,
      widgets: [
        {
          id: 'viewer-overview',
          type: 'summary-cards',
          title: 'Overview',
          position: { x: 0, y: 0 },
          size: { width: 12, height: 2 },
          config: { metrics: ['users', 'revenue', 'projects', 'status'] },
        },
        {
          id: 'viewer-chart',
          type: 'performance-chart',
          title: 'Performance',
          position: { x: 0, y: 2 },
          size: { width: 8, height: 3 },
          config: { readonly: true, timeRange: '30d' },
        },
        {
          id: 'viewer-status',
          type: 'status-board',
          title: 'Status Board',
          position: { x: 8, y: 2 },
          size: { width: 4, height: 3 },
          config: { readonly: true, categories: ['projects', 'tasks', 'issues'] },
        },
      ],
    });
  }

  getTemplateByRole(role: UserRole): DashboardTemplate | undefined {
    const templateId = `${role.toLowerCase()}-default` as keyof any;
    return this.templates.get(String(templateId));
  }

  getTemplate(templateId: string): DashboardTemplate | undefined {
    return this.templates.get(templateId);
  }

  getAllTemplates(): DashboardTemplate[] {
    return Array.from(this.templates.values());
  }

  getTemplatesByRole(role: UserRole): DashboardTemplate[] {
    return Array.from(this.templates.values()).filter((t) => t.role === role);
  }

  createCustomTemplate(template: Omit<DashboardTemplate, 'id'>): DashboardTemplate {
    const id = `custom-${Date.now()}`;
    const newTemplate: DashboardTemplate = { ...template, id } as DashboardTemplate;
    this.templates.set(id, newTemplate);
    return newTemplate;
  }

  updateTemplate(templateId: string, updates: Partial<DashboardTemplate>): boolean {
    const template = this.templates.get(templateId);
    if (template) {
      this.templates.set(templateId, { ...template, ...updates });
      return true;
    }
    return false;
  }

  deleteTemplate(templateId: string): boolean {
    return this.templates.delete(templateId);
  }

  cloneTemplate(templateId: string, newName: string): DashboardTemplate | null {
    const template = this.templates.get(templateId);
    if (!template) return null;

    const newTemplate: DashboardTemplate = {
      ...template,
      id: `clone-${Date.now()}`,
      name: newName,
      isDefault: false,
    } as DashboardTemplate;

    this.templates.set(newTemplate.id, newTemplate);
    return newTemplate;
  }
}

export const dashboardTemplateService = new DashboardTemplateService();
