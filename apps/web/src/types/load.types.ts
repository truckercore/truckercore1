export type LoadStatus = 
  | 'offered' 
  | 'accepted' 
  | 'in_transit' 
  | 'at_pickup' 
  | 'picked_up' 
  | 'at_delivery' 
  | 'delivered' 
  | 'completed' 
  | 'cancelled';

export interface LoadStop {
  id: string;
  type: 'pickup' | 'delivery';
  sequence: number;
  location: {
    name: string;
    address: string;
    city: string;
    state: string;
    zip: string;
    latitude?: number;
    longitude?: number;
  };
  scheduledTime: Date;
  arrivalTime?: Date;
  departureTime?: Date;
  instructions?: string;
  contactName?: string;
  contactPhone?: string;
  status: 'pending' | 'arrived' | 'completed' | 'skipped';
  proofOfDelivery?: ProofOfDelivery;
}

export interface ProofOfDelivery {
  id: string;
  stopId: string;
  signature?: {
    dataUrl: string;
    signedBy: string;
    timestamp: Date;
  };
  photos: {
    id: string;
    dataUrl: string;
    caption?: string;
    timestamp: Date;
  }[];
  notes?: string;
  deliveredTo?: string;
  deliveryTime: Date;
  odometer?: number;
}

export interface Load {
  id: string;
  loadNumber: string;
  status: LoadStatus;
  driverId?: string;
  
  // Route information
  stops: LoadStop[];
  totalDistance: number;
  estimatedDuration: number; // minutes
  
  // Cargo information
  cargo: {
    description: string;
    weight: number; // lbs
    pieces?: number;
    hazmat?: boolean;
    temperature?: {
      min: number;
      max: number;
      unit: 'F' | 'C';
    };
  };
  
  // Financial
  rate: number;
  currency: 'USD';
  fuelSurcharge?: number;
  
  // Timestamps
  offeredAt?: Date;
  acceptedAt?: Date;
  startedAt?: Date;
  completedAt?: Date;
  
  // Notes
  specialInstructions?: string;
  
  createdAt: Date;
  updatedAt: Date;
}

export interface LoadAcceptanceRequest {
  loadId: string;
  driverId: string;
  acceptedAt: Date;
  estimatedPickupTime?: Date;
}
