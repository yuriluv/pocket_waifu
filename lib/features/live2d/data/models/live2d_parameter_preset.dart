class Live2DParameterPreset {
  const Live2DParameterPreset({
    required this.id,
    required this.name,
    required this.overrides,
  });

  final String id;
  final String name;
  final Map<String, double> overrides;

  Live2DParameterPreset copyWith({
    String? id,
    String? name,
    Map<String, double>? overrides,
  }) {
    return Live2DParameterPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      overrides: overrides ?? this.overrides,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overrides': overrides,
    };
  }

  factory Live2DParameterPreset.fromJson(Map<String, dynamic> json) {
    final raw = json['overrides'];
    final overrides = <String, double>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is num) {
          overrides[entry.key.toString()] = value.toDouble();
        }
      }
    }

    return Live2DParameterPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      overrides: overrides,
    );
  }
}
