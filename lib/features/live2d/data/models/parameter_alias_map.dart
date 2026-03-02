class ParameterAliasMap {
  const ParameterAliasMap({
    required this.aliasToReal,
    required this.realToAlias,
  });

  final Map<String, String> aliasToReal;
  final Map<String, String> realToAlias;

  factory ParameterAliasMap.fromAliasToReal(Map<String, String> aliasToReal) {
    final reverse = <String, String>{};
    for (final entry in aliasToReal.entries) {
      reverse[entry.value] = entry.key;
    }
    return ParameterAliasMap(aliasToReal: aliasToReal, realToAlias: reverse);
  }

  factory ParameterAliasMap.fromJson(Map<String, dynamic> json) {
    final aliasRaw = json['aliasToReal'];
    final aliasToReal = <String, String>{};
    if (aliasRaw is Map) {
      for (final entry in aliasRaw.entries) {
        aliasToReal[entry.key.toString()] = entry.value.toString();
      }
    }

    final realRaw = json['realToAlias'];
    final realToAlias = <String, String>{};
    if (realRaw is Map) {
      for (final entry in realRaw.entries) {
        realToAlias[entry.key.toString()] = entry.value.toString();
      }
    }

    if (realToAlias.isEmpty && aliasToReal.isNotEmpty) {
      for (final entry in aliasToReal.entries) {
        realToAlias[entry.value] = entry.key;
      }
    }

    return ParameterAliasMap(
      aliasToReal: aliasToReal,
      realToAlias: realToAlias,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aliasToReal': aliasToReal,
      'realToAlias': realToAlias,
    };
  }
}
