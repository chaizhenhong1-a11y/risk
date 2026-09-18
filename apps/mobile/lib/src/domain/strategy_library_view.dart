class StrategyLibraryView {
  const StrategyLibraryView(
      {required this.id,
      required this.name,
      required this.family,
      required this.status,
      required this.reason});

  final String id;
  final String name;
  final String family;
  final String status;
  final String reason;

  factory StrategyLibraryView.fromJson(Map<String, dynamic> json) =>
      StrategyLibraryView(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        family: json['family'] as String? ?? '',
        status: json['status'] as String? ?? 'RESEARCH',
        reason: json['reason'] as String? ?? '',
      );
}
