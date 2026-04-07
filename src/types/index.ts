export interface Driver {
  id: string;
  name: string;
  licenseNumber: string;
  phone: string;
  email: string;
  status: 'available' | 'assigned' | 'on-route' | 'off-duty';
  currentLocation?: {
    lat: number;
    lng: number;
    city: string;
    state: string;
  };
  hoursRemaining: number;
  truckId?: string;
}

export interface Truck {
  id: string;
  truckNumber: string;
  type: 'dry-van' | 'reefer' | 'flatbed' | 'tanker';
  capacity: number;
  status: 'available' | 'assigned' | 'maintenance' | 'out-of-service';
  currentLocation?: {
    lat: number;
    lng: number;
  };
}

export interface Location {
  address: string;
  city: string;
  state: string;
  zipCode: string;
  lat?: number;
  lng?: number;
  contactName?: string;
  contactPhone?: string;
  specialInstructions?: string;
}

export interface Load {
  id: string;
  loadNumber: string;
  status: 'posted' | 'assigned' | 'in-transit' | 'delivered' | 'cancelled';
  origin: Location;
  destination: Location;
  pickupDate: string;
  deliveryDate: string;
  cargo: {
    description: string;
    weight: number;
    pieces: number;
    type: string;
  };
  rate: number;
  distance: number;
  requirements?: string[];
  assignedDriver?: string;
  assignedTruck?: string;
  createdBy: string;
  createdAt: string;
}

export interface Expense {
  id: string;
  operatorId: string;
  operatorName: string;
  date: string;
  category: 'fuel' | 'maintenance' | 'tolls' | 'permits' | 'insurance' | 'supplies' | 'other';
  amount: number;
  description: string;
  paymentMethod: 'cash' | 'credit' | 'debit' | 'company-card';
  location: string;
  odometer?: number;
  receipts: Receipt[];
  loadNumber?: string;
  status: 'pending' | 'approved' | 'rejected';
  submittedAt: string;
  reviewedAt?: string;
  reviewedBy?: string;
  notes?: string;
}

export interface Receipt {
  id: string;
  fileName: string;
  fileSize: number;
  fileType: string;
  url: string;
  uploadedAt: string;
}

export interface POD {
  id: string;
  loadId: string;
  loadNumber: string;
  deliveryDate: string;
  deliveryTime: string;
  recipientName: string;
  recipientTitle?: string;
  signature: string;
  photos: Photo[];
  notes?: string;
  location: {
    lat: number;
    lng: number;
    address: string;
  };
  createdAt: string;
  driverId: string;
  driverName: string;
}

export interface Photo {
  id: string;
  url: string;
  caption?: string;
  timestamp: string;
}

export interface Assignment {
  loadId: string;
  driverId: string;
  truckId: string;
  assignedAt: string;
  assignedBy: string;
  notes?: string;
}
