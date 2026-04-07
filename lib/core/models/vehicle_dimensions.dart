class VehicleDimensions {
  final double heightFeet;
  final double widthFeet;
  final double lengthFeet;
  final double weightLbs;
  final bool isHazmat;
  final String? hazmatClass;
  final int axles;

  const VehicleDimensions({
    required this.heightFeet,
    required this.widthFeet,
    required this.lengthFeet,
    required this.weightLbs,
    this.isHazmat = false,
    this.hazmatClass,
    required this.axles,
  });

  Map<String, dynamic> toJson() => {
        'height_feet': heightFeet,
        'width_feet': widthFeet,
        'length_feet': lengthFeet,
        'weight_lbs': weightLbs,
        'is_hazmat': isHazmat,
        'hazmat_class': hazmatClass,
        'axles': axles,
      };

  factory VehicleDimensions.fromJson(Map<String, dynamic> json) => VehicleDimensions(
        heightFeet: (json['height_feet'] as num).toDouble(),
        widthFeet: (json['width_feet'] as num).toDouble(),
        lengthFeet: (json['length_feet'] as num).toDouble(),
        weightLbs: (json['weight_lbs'] as num).toDouble(),
        isHazmat: json['is_hazmat'] as bool? ?? false,
        hazmatClass: json['hazmat_class'] as String?,
        axles: json['axles'] as int,
      );
}
