class Model3Data {
  const Model3Data({
    required this.motionGroups,
    required this.expressions,
    required this.parameters,
    required this.hitAreas,
    this.parts = const <Model3Part>[],
    this.physicsMeta,
    this.physicsSettings = const <Model3PhysicsSetting>[],
    this.displayInfoPath,
    this.physicsPath,
  });

  final Map<String, List<String>> motionGroups;
  final List<Model3Expression> expressions;
  final List<Model3Parameter> parameters;
  final List<Model3HitArea> hitAreas;
  final List<Model3Part> parts;
  final Model3PhysicsMeta? physicsMeta;
  final List<Model3PhysicsSetting> physicsSettings;
  final String? displayInfoPath;
  final String? physicsPath;

  static const Model3Data empty = Model3Data(
    motionGroups: <String, List<String>>{},
    expressions: <Model3Expression>[],
    parameters: <Model3Parameter>[],
    hitAreas: <Model3HitArea>[],
    parts: <Model3Part>[],
    physicsSettings: <Model3PhysicsSetting>[],
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

class Model3Part {
  const Model3Part({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class Model3PhysicsMeta {
  const Model3PhysicsMeta({
    required this.fps,
    required this.settingCount,
    required this.totalInputCount,
    required this.totalOutputCount,
    required this.vertexCount,
    required this.gravityX,
    required this.gravityY,
    required this.windX,
    required this.windY,
  });

  final int fps;
  final int settingCount;
  final int totalInputCount;
  final int totalOutputCount;
  final int vertexCount;
  final double gravityX;
  final double gravityY;
  final double windX;
  final double windY;
}

class Model3PhysicsSetting {
  const Model3PhysicsSetting({
    required this.id,
    required this.name,
    required this.averageDelay,
    required this.averageMobility,
  });

  final String id;
  final String name;
  final double averageDelay;
  final double averageMobility;
}
