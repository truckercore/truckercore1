class FinancialSummary {
  final double totalRevenue;
  final double totalExpenses;
  final double netIncome;
  final double fuelCosts;
  final double maintenanceCosts;
  final double insuranceCosts;
  final int totalLoads;
  final double totalMiles;
  final double revenuePerMile;

  const FinancialSummary({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netIncome,
    required this.fuelCosts,
    required this.maintenanceCosts,
    required this.insuranceCosts,
    required this.totalLoads,
    required this.totalMiles,
    required this.revenuePerMile,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) => FinancialSummary(
        totalRevenue: (json['total_revenue'] as num).toDouble(),
        totalExpenses: (json['total_expenses'] as num).toDouble(),
        netIncome: (json['net_income'] as num).toDouble(),
        fuelCosts: (json['fuel_costs'] as num).toDouble(),
        maintenanceCosts: (json['maintenance_costs'] as num).toDouble(),
        insuranceCosts: (json['insurance_costs'] as num).toDouble(),
        totalLoads: json['total_loads'] as int,
        totalMiles: (json['total_miles'] as num).toDouble(),
        revenuePerMile: (json['revenue_per_mile'] as num).toDouble(),
      );
}

class Settlement {
  final String id;
  final DateTime settlementDate;
  final double grossRevenue;
  final double deductions;
  final double netPay;
  final String status;
  final List<String> loadIds;

  const Settlement({
    required this.id,
    required this.settlementDate,
    required this.grossRevenue,
    required this.deductions,
    required this.netPay,
    required this.status,
    required this.loadIds,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) => Settlement(
        id: json['id'] as String,
        settlementDate: DateTime.parse(json['settlement_date'] as String),
        grossRevenue: (json['gross_revenue'] as num).toDouble(),
        deductions: (json['deductions'] as num).toDouble(),
        netPay: (json['net_pay'] as num).toDouble(),
        status: json['status'] as String,
        loadIds: (json['load_ids'] as List).map((e) => e.toString()).toList(),
      );
}

class LoadRevenue {
  final String loadId;
  final String loadNumber;
  final double revenue;
  final double miles;
  final double revenuePerMile;
  final DateTime completedAt;

  const LoadRevenue({
    required this.loadId,
    required this.loadNumber,
    required this.revenue,
    required this.miles,
    required this.revenuePerMile,
    required this.completedAt,
  });

  factory LoadRevenue.fromJson(Map<String, dynamic> json) => LoadRevenue(
        loadId: json['load_id'] as String,
        loadNumber: json['load_number'] as String,
        revenue: (json['revenue'] as num).toDouble(),
        miles: (json['miles'] as num).toDouble(),
        revenuePerMile: (json['revenue_per_mile'] as num).toDouble(),
        completedAt: DateTime.parse(json['completed_at'] as String),
      );
}

class ExpenseBreakdown {
  final double fuelExpenses;
  final double maintenanceExpenses;
  final double insuranceExpenses;
  final double permitExpenses;
  final double tolls;
  final double other;
  final Map<String, double> byCategory;

  const ExpenseBreakdown({
    required this.fuelExpenses,
    required this.maintenanceExpenses,
    required this.insuranceExpenses,
    required this.permitExpenses,
    required this.tolls,
    required this.other,
    required this.byCategory,
  });

  factory ExpenseBreakdown.fromJson(Map<String, dynamic> json) {
    final byCategory = <String, double>{};
    final categoriesMap = json['by_category'] as Map<String, dynamic>;
    categoriesMap.forEach((key, value) {
      byCategory[key] = (value as num).toDouble();
    });

    return ExpenseBreakdown(
      fuelExpenses: (json['fuel_expenses'] as num).toDouble(),
      maintenanceExpenses: (json['maintenance_expenses'] as num).toDouble(),
      insuranceExpenses: (json['insurance_expenses'] as num).toDouble(),
      permitExpenses: (json['permit_expenses'] as num).toDouble(),
      tolls: (json['tolls'] as num).toDouble(),
      other: (json['other'] as num).toDouble(),
      byCategory: byCategory,
    );
  }
}

class ProfitLossStatement {
  final double grossRevenue;
  final double operatingExpenses;
  final double operatingIncome;
  final double netIncome;
  final double profitMargin;

  const ProfitLossStatement({
    required this.grossRevenue,
    required this.operatingExpenses,
    required this.operatingIncome,
    required this.netIncome,
    required this.profitMargin,
  });

  factory ProfitLossStatement.fromJson(Map<String, dynamic> json) => ProfitLossStatement(
        grossRevenue: (json['gross_revenue'] as num).toDouble(),
        operatingExpenses: (json['operating_expenses'] as num).toDouble(),
        operatingIncome: (json['operating_income'] as num).toDouble(),
        netIncome: (json['net_income'] as num).toDouble(),
        profitMargin: (json['profit_margin'] as num).toDouble(),
      );
}

class TaxDocument {
  final String id;
  final int year;
  final String documentType;
  final String documentUrl;
  final DateTime createdAt;

  const TaxDocument({
    required this.id,
    required this.year,
    required this.documentType,
    required this.documentUrl,
    required this.createdAt,
  });

  factory TaxDocument.fromJson(Map<String, dynamic> json) => TaxDocument(
        id: json['id'] as String,
        year: json['year'] as int,
        documentType: json['document_type'] as String,
        documentUrl: json['document_url'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FuelTransaction {
  final String id;
  final DateTime transactionDate;
  final double gallons;
  final double pricePerGallon;
  final double totalAmount;
  final String location;
  final String vehicleId;

  const FuelTransaction({
    required this.id,
    required this.transactionDate,
    required this.gallons,
    required this.pricePerGallon,
    required this.totalAmount,
    required this.location,
    required this.vehicleId,
  });

  factory FuelTransaction.fromJson(Map<String, dynamic> json) => FuelTransaction(
        id: json['id'] as String,
        transactionDate: DateTime.parse(json['transaction_date'] as String),
        gallons: (json['gallons'] as num).toDouble(),
        pricePerGallon: (json['price_per_gallon'] as num).toDouble(),
        totalAmount: (json['total_amount'] as num).toDouble(),
        location: json['location'] as String,
        vehicleId: json['vehicle_id'] as String,
      );
}

class RevenuePerMileAnalysis {
  final double averageRPM;
  final double highestRPM;
  final double lowestRPM;
  final List<RPMByLane> byLane;

  const RevenuePerMileAnalysis({
    required this.averageRPM,
    required this.highestRPM,
    required this.lowestRPM,
    required this.byLane,
  });

  factory RevenuePerMileAnalysis.fromJson(Map<String, dynamic> json) => RevenuePerMileAnalysis(
        averageRPM: (json['average_rpm'] as num).toDouble(),
        highestRPM: (json['highest_rpm'] as num).toDouble(),
        lowestRPM: (json['lowest_rpm'] as num).toDouble(),
        byLane: (json['by_lane'] as List).map((l) => RPMByLane.fromJson(l)).toList(),
      );
}

class RPMByLane {
  final String origin;
  final String destination;
  final double rpm;
  final int loadCount;

  const RPMByLane({
    required this.origin,
    required this.destination,
    required this.rpm,
    required this.loadCount,
  });

  factory RPMByLane.fromJson(Map<String, dynamic> json) => RPMByLane(
        origin: json['origin'] as String,
        destination: json['destination'] as String,
        rpm: (json['rpm'] as num).toDouble(),
        loadCount: json['load_count'] as int,
      );
}
