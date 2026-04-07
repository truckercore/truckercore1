#!/bin/bash
set -e

echo "📱 Generating App Store Assets"
echo "==============================="
echo ""

# Create assets directory
mkdir -p store_assets/{screenshots,icons,descriptions}

echo "📸 Screenshot Instructions"
echo "-------------------------"
echo ""
echo "Please capture the following screenshots for each app:"
echo ""
echo "Driver App (Mobile):"
echo "  1. Login screen"
echo "  2. Dashboard with active load"
echo "  3. Loads list"
echo "  4. HOS summary"
echo "  5. Settings screen"
echo ""
echo "Owner Operator Dashboard (Desktop):"
echo "  1. Login screen"
echo "  2. Fleet overview"
echo "  3. Vehicle management"
echo "  4. Reports screen"
echo ""
echo "Fleet Manager (Desktop):"
echo "  1. Multi-fleet dashboard"
echo "  2. User management"
echo "  3. Compliance view"
echo "  4. Analytics dashboard"
echo ""
echo "Screenshot Requirements:"
echo "  - Android: 1080x1920 (9:16)"
echo "  - iOS: 1242x2208 (iPhone) or 2048x2732 (iPad)"
echo "  - Desktop: 1920x1080"
echo ""

# Create description templates
cat > store_assets/descriptions/driver_app.md << 'EOF'
# TruckerCore Driver App

## Short Description (80 chars)
Professional fleet management for drivers - HOS tracking, load management

## Full Description

Take control of your driving career with TruckerCore Driver App. Our comprehensive platform helps professional drivers manage their hours of service, track loads, and stay compliant.

**Key Features:**

📋 **Load Management**
- View assigned loads in real-time
- Track pickup and delivery locations
- Get turn-by-turn navigation
- Update load status on the go

⏱️ **Hours of Service (HOS)**
- Automatic HOS tracking
- Visual drive time remaining
- Compliance alerts
- Full FMCSA compliant

📱 **Offline Mode**
- Works without internet connection
- Automatic sync when back online
- Never miss critical updates

📍 **Real-time Location**
- Share location with dispatcher
- Route optimization
- Traffic updates

📄 **Document Management**
- Digital BOL and POD
- Camera scanning
- Secure cloud storage

🔔 **Smart Notifications**
- Load updates
- HOS alerts
- Dispatch messages

**Why Choose TruckerCore?**

✅ FMCSA Compliant
✅ Easy to use interface
✅ Works offline
✅ Real-time updates
✅ Secure and reliable
✅ 24/7 support

Join thousands of professional drivers using TruckerCore to manage their business more efficiently.

**Download now and drive smarter!**
EOF

cat > store_assets/descriptions/owner_operator.md << 'EOF'
# TruckerCore Owner Operator Dashboard

## Description

Professional fleet management for owner operators. Manage your vehicles, drivers, loads, and compliance in one powerful desktop application.

**Key Features:**

🚛 **Fleet Management**
- Vehicle tracking and status
- Maintenance scheduling
- Real-time location monitoring

👥 **Driver Management**
- Assign loads to drivers
- Monitor HOS compliance
- Performance tracking

📊 **Business Analytics**
- Revenue tracking
- Expense management
- Profit analysis
- Custom reports

📋 **Load Management**
- Create and assign loads
- Track delivery status
- Rate management
- Customer portal

💼 **Compliance**
- FMCSA compliance tracking
- Document management
- Inspection reports
- Safety monitoring

**System Requirements:**
- Windows 10 or later / macOS 10.15+ / Linux (Ubuntu 20.04+)
- 4GB RAM minimum
- Internet connection

**Perfect for:**
- Owner operators with 1-10 trucks
- Small fleet managers
- Independent carriers
EOF

cat > store_assets/descriptions/fleet_manager.md << 'EOF'
# TruckerCore Fleet Manager

## Description

Enterprise-grade fleet management for managing multiple fleets and operations. Complete visibility and control across your entire organization.

**Key Features:**

🏢 **Multi-Fleet Management**
- Manage unlimited fleets
- Cross-fleet analytics
- Centralized control
- Fleet performance comparison

👤 **User Management**
- Role-based access control
- User provisioning
- Activity tracking
- Audit logs

📈 **Advanced Analytics**
- Real-time dashboards
- Custom reports
- Predictive insights
- Export capabilities

✅ **Compliance Suite**
- FMCSA compliance tracking
- Automated reporting
- Violation alerts
- Safety scoring

🔐 **Security & Audit**
- Complete audit trail
- User activity logs
- Data encryption
- Backup & recovery

🔧 **Integration**
- API access
- Third-party integrations
- Custom workflows
- Data import/export

**Enterprise Features:**
- Unlimited users and vehicles
- 99.9% uptime SLA
- Dedicated support
- Custom training
- White-label options

**System Requirements:**
- Windows 10/11, macOS 10.15+, Linux
- 8GB RAM recommended
- Internet connection

**Perfect for:**
- Fleet managers with 10+ trucks
- Multi-location operations
- Enterprise carriers
- Logistics companies
EOF

echo "✅ Description templates created in store_assets/descriptions/"
echo ""
echo "Next steps:"
echo "1. Capture screenshots following the guide above"
echo "2. Save to store_assets/screenshots/"
echo "3. Create app icons (1024x1024 PNG)"
echo "4. Save to store_assets/icons/"
echo "5. Edit descriptions in store_assets/descriptions/"
echo ""
echo "Then run the store submission process for each platform."