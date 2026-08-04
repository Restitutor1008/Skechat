class AppHoliday {
  const AppHoliday({
    required this.countryCode,
    required this.date,
    required this.name,
    required this.category,
    required this.isSubstitute,
    required this.source,
    this.descriptionKo,
    this.descriptionEn,
  });

  factory AppHoliday.fromJson(Map<String, dynamic> json) => AppHoliday(
    countryCode: json['country_code']! as String,
    date: DateTime.parse(json['date']! as String),
    name: json['name']! as String,
    descriptionKo: json['description_ko'] as String?,
    descriptionEn: json['description_en'] as String?,
    category: json['category']! as String,
    isSubstitute: json['is_substitute']! as bool,
    source: json['source']! as String,
  );

  final String countryCode;
  final DateTime date;
  final String name;
  final String? descriptionKo;
  final String? descriptionEn;
  final String category;
  final bool isSubstitute;
  final String source;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
