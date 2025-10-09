export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      users: {
        Row: {
          id: string
          email: string
          role: string
          full_name: string | null
          phone: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          email: string
          role: string
          full_name?: string | null
          phone?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string
          role?: string
          full_name?: string | null
          phone?: string | null
          updated_at?: string
        }
      }
      hos_entries: {
        Row: {
          id: string
          driver_id: string
          status: string
          start_time: string
          end_time: string | null
          location_lat: number
          location_lng: number
          location_address: string | null
          odometer: number | null
          engine_hours: number | null
          notes: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          driver_id: string
          status: string
          start_time: string
          end_time?: string | null
          location_lat: number
          location_lng: number
          location_address?: string | null
          odometer?: number | null
          engine_hours?: number | null
          notes?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          end_time?: string | null
          location_lat?: number
          location_lng?: number
          location_address?: string | null
          odometer?: number | null
          engine_hours?: number | null
          notes?: string | null
          updated_at?: string
        }
      }
      loads: {
        Row: {
          id: string
          load_number: string
          status: string
          driver_id: string | null
          rate: number
          currency: string
          total_distance: number
          estimated_duration: number
          cargo_description: string
          cargo_weight: number
          cargo_pieces: number | null
          hazmat: boolean
          special_instructions: string | null
          offered_at: string | null
          accepted_at: string | null
          started_at: string | null
          completed_at: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          load_number: string
          status: string
          driver_id?: string | null
          rate: number
          currency?: string
          total_distance: number
          estimated_duration: number
          cargo_description: string
          cargo_weight: number
          cargo_pieces?: number | null
          hazmat?: boolean
          special_instructions?: string | null
          offered_at?: string | null
          accepted_at?: string | null
          started_at?: string | null
          completed_at?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          status?: string
          driver_id?: string | null
          accepted_at?: string | null
          started_at?: string | null
          completed_at?: string | null
          updated_at?: string
        }
      }
      load_stops: {
        Row: {
          id: string
          load_id: string
          type: string
          sequence: number
          location_name: string
          location_address: string
          location_city: string
          location_state: string
          location_zip: string
          location_lat: number | null
          location_lng: number | null
          scheduled_time: string
          arrival_time: string | null
          departure_time: string | null
          status: string
          instructions: string | null
          contact_name: string | null
          contact_phone: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          load_id: string
          type: string
          sequence: number
          location_name: string
          location_address: string
          location_city: string
          location_state: string
          location_zip: string
          location_lat?: number | null
          location_lng?: number | null
          scheduled_time: string
          arrival_time?: string | null
          departure_time?: string | null
          status?: string
          instructions?: string | null
          contact_name?: string | null
          contact_phone?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          arrival_time?: string | null
          departure_time?: string | null
          status?: string
          updated_at?: string
        }
      }
      locations: {
        Row: {
          id: string
          driver_id: string
          latitude: number
          longitude: number
          accuracy: number
          altitude: number | null
          heading: number | null
          speed: number | null
          timestamp: string
          synced: boolean
          offline: boolean
          created_at: string
        }
        Insert: {
          id?: string
          driver_id: string
          latitude: number
          longitude: number
          accuracy: number
          altitude?: number | null
          heading?: number | null
          speed?: number | null
          timestamp: string
          synced?: boolean
          offline?: boolean
          created_at?: string
        }
        Update: {
          synced?: boolean
        }
      }
      violations: {
        Row: {
          id: string
          driver_id: string
          type: string
          severity: string
          message: string
          timestamp: string
          acknowledged: boolean
          acknowledged_at: string | null
          created_at: string
        }
        Insert: {
          id?: string
          driver_id: string
          type: string
          severity: string
          message: string
          timestamp: string
          acknowledged?: boolean
          acknowledged_at?: string | null
          created_at?: string
        }
        Update: {
          acknowledged?: boolean
          acknowledged_at?: string | null
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}
