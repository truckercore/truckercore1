class TimeUtil {
  static DateTime nowUtc() => DateTime.now().toUtc();
  static DateTime toUtc(DateTime d) => d.toUtc();
  static DateTime fromIsoUtc(String s) => DateTime.parse(s).toUtc();
  static String isoUtc(DateTime d) => d.toUtc().toIso8601String();
}
