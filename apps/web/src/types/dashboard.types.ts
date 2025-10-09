export enum UserRole {
  ADMIN = 'admin',
  MANAGER = 'manager',
  ANALYST = 'analyst',
  VIEWER = 'viewer',
  DEVELOPER = 'developer',
  SALES = 'sales',
  SUPPORT = 'support',
}

export interface Widget {
  id: string;
  type: string;
  title: string;
  position: { x: number; y: number };
  size: { width: number; height: number };
  config: Record<string, any>;
  permissions?: UserRole[];
}

export interface DashboardTemplate {
  id: string;
  name: string;
  description: string;
  role: UserRole;
  widgets: Widget[];
  layout: 'grid' | 'flex' | 'custom';
  refreshInterval?: number;
  isDefault?: boolean;
}

export interface DashboardInstance {
  id: string;
  userId: string;
  templateId: string;
  name: string;
  widgets: Widget[];
  customizations?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}
