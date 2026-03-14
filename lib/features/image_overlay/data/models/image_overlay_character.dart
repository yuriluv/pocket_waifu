class ImageOverlayCharacter {
  const ImageOverlayCharacter({
    required this.name,
    required this.folderPath,
    required this.emotions,
  });

  final String name;
  final String folderPath;
  final List<ImageOverlayEmotion> emotions;
}

class ImageOverlayEmotion {
  const ImageOverlayEmotion({
    required this.name,
    required this.filePath,
    this.supportsRename = true,
  });

  final String name;
  final String filePath;
  final bool supportsRename;
}
