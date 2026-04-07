// types/fleet.ts
// Request/response contracts for Fleet Drivers flows

export type FleetRole = 'driver' | 'dispatcher' | 'safety' | 'admin';

export interface DriversCreateRequest {
  org_id: string; // acting manager org
  name: string;
  email?: string;
  phone?: string; // E.164
  license_no?: string;
  truck_id?: string;
  role: FleetRole; // typically 'driver'
}
export interface DriversCreateResponse {
  user_id: string;
  driver_id: string;
  status: 'created' | 'updated';
}

export interface DriversInviteRequest {
  org_id: string;
  email_or_phone: string;
  role: Exclude<FleetRole, 'admin'>; // driver|dispatcher|safety
  send_via: 'email' | 'sms';
}
export interface DriversInviteResponse {
  invite_id: string;
  token: string;
  status: 'sent' | 'queued';
}

export interface DriversBulkUploadRequest {
  org_id: string;
  rows: Array<{
    name: string;
    email?: string;
    phone?: string;
    license_no?: string;
    truck_id?: string;
    role: FleetRole;
  }>;
  dry_run?: boolean;
}
export interface DriversBulkUploadResponse {
  accepted: number;
  rejected: Array<{ row: number; reason: string }>;
}

export interface InvitesAcceptRequest { token: string }
export interface InvitesAcceptResponse {
  user_id: string;
  org_id: string;
  role: Exclude<FleetRole, 'admin'>;
  auth_hint: 'magic_link' | 'otp';
}
