# 🚚 Freight Logistics System (React Demo)

A comprehensive web application for managing freight logistics operations including fleet dispatch, expense tracking, load posting, and proof of delivery capture.

## 📋 Features

### 1. Fleet Manager Dispatch System
- Real-time driver and truck availability tracking
- Interactive load assignment workflow
- Visual route information
- Status management for loads, drivers, and trucks
- Assignment notes and confirmations

### 2. Owner Operator Expense Entry
- Multi-category expense tracking (fuel, maintenance, tolls, etc.)
- Receipt upload with drag-and-drop support
- Expense history and status tracking
- Support for multiple file formats (JPG, PNG, PDF)

### 3. Freight Broker Load Posting
- 5-step wizard for load creation
- Pickup and delivery location management
- Cargo details with requirements
- Schedule and rate configuration
- Review and confirmation step

### 4. Driver POD (Proof of Delivery) Capture
- Digital signature capture (HTML5 canvas)
- Photo capture from camera or gallery
- Multiple photo support with captions
- Geolocation tracking
- Recipient information collection

### 5. Utilities
- ErrorBoundary for graceful error handling
- Loading component for consistent loading states
- Toast notification system (success, error, warning, info)
- Print styles for printer-friendly outputs

## 🚀 Getting Started

### Prerequisites
- Node.js (v18 or higher)
- npm or yarn

### Installation

```bash
# From repository root
npm install

# Start development server (CRA/Next script depending on setup)
npm start
```

The application will open at http://localhost:3000

## 🏗 Project Structure (web demo)
```
src/
├── components/
│   ├── ErrorBoundary/
│   ├── ExpenseEntry/
│   ├── FleetDispatch/
│   ├── LoadPosting/
│   ├── PODCapture/
│   ├── Loading/
│   └── Toast/
├── hooks/
│   ├── useLocalStorage.ts
│   └── useToast.ts
├── types/
├── utils/
├── App.css
├── App.tsx
├── index.tsx
└── print.css
```

## 🖨 Print Support
Print-optimized CSS is included (src/print.css) to hide navigation, action buttons, and to ensure signatures/photos render well on paper.

## 🔧 Environment Variables
See src/.env.example for web-demo environment variables used for future integration (API URL, flags, limits). Copy to .env and adjust as needed.

## 🧪 Testing
```bash
npm test
npm test -- --coverage
```

## 🚢 Deployment
- Vercel / Netlify: build and deploy the static site or Next app as configured.
- Docker:

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npx", "serve", "-s", "build"]
```

## 🔐 Security Considerations
- Client-side validation for file types and sizes
- UI-only demo; do not store sensitive data in localStorage

## 🛣️ Roadmap
- Backend API integration (REST/GraphQL)
- Authentication and RBAC
- Persistent storage (PostgreSQL)
- Realtime updates (WebSockets)
- Mobile (React Native)
- Mapping integrations

## 📄 License
MIT
