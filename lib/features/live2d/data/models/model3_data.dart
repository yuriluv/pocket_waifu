class Model3Data {
  const Model3Data({
    required this.motionGroups,
    required this.expressions,
    required this.parameters,
    required this.hitAreas,
  });

  final Map<String, List<String>> motionGroups;
  final List<Model3Expression> expressions;
  final List<Model3Parameter> parameters;
  final List<Model3HitArea> hitAreas;

  static const Model3Data empty = Model3Data(
    motionGroups: <String, List<String>>{},
    expressions: <Model3Expression>[],
    parameters: <Model3Parameter>[],
    hitAreas: <Model3HitArea>[],
  );
}

class Model3Expression {
  const Model3Expression({
    required this.name,
    required this.filePath,
  });

  final String name;
  final String filePath;
}

class Model3Parameter {
  const Model3Parameter({
    required this.id,
    required this.name,
    required this.min,
    required this.defaultValue,
    required this.max,
  });

  final String id;
  final String name;
  final double min;
  final double defaultValue;
  final double max;
}

class Model3HitArea {
  const Model3HitArea({
    required this.name,
    required this.meshIds,
  });

  final String name;
  final List<String> meshIds;
}
