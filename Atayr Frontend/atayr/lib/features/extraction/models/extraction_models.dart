class BoundingBox {
  final double xMin;
  final double yMin;
  final double xMax;
  final double yMax;

  BoundingBox({
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      xMin: (json['x_min'] as num).toDouble(),
      yMin: (json['y_min'] as num).toDouble(),
      xMax: (json['x_max'] as num).toDouble(),
      yMax: (json['y_max'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'x_min': xMin,
    'y_min': yMin,
    'x_max': xMax,
    'y_max': yMax,
  };
}

class ExtractedItem {
  final String id;
  final String category;
  final String subcategory;
  final String name;
  final String primaryColor;
  final String? secondaryColor;
  final String pattern;
  final String style;
  final String fit;
  final double visibility;
  final BoundingBox boundingBox;

  ExtractedItem({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    required this.pattern,
    required this.style,
    required this.fit,
    required this.visibility,
    required this.boundingBox,
  });

  factory ExtractedItem.fromJson(Map<String, dynamic> json) {
    return ExtractedItem(
      id: json['id'],
      category: json['category'],
      subcategory: json['subcategory'],
      name: json['name'],
      primaryColor: json['primary_color'],
      secondaryColor: json['secondary_color'],
      pattern: json['pattern'],
      style: json['style'],
      fit: json['fit'],
      visibility: (json['visibility'] as num).toDouble(),
      boundingBox: BoundingBox.fromJson(json['bounding_box']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'subcategory': subcategory,
    'name': name,
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'pattern': pattern,
    'style': style,
    'fit': fit,
    'visibility': visibility,
    'bounding_box': boundingBox.toJson(),
  };
}

class Person {
  final String id;
  final BoundingBox boundingBox;
  final List<ExtractedItem> garments;

  Person({
    required this.id,
    required this.boundingBox,
    required this.garments,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    var garmentsList = json['garments'] as List? ?? [];
    return Person(
      id: json['id'],
      boundingBox: BoundingBox.fromJson(json['bounding_box']),
      garments: garmentsList.map((g) => ExtractedItem.fromJson(g)).toList(),
    );
  }
}

class AnalysisResponse {
  final String sourceImageId;
  final List<Person> people;

  AnalysisResponse({
    required this.sourceImageId,
    required this.people,
  });

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    var peopleList = json['people'] as List? ?? [];
    return AnalysisResponse(
      sourceImageId: json['source_image_id'] ?? '',
      people: peopleList.map((p) => Person.fromJson(p)).toList(),
    );
  }
}

class GeneratedGarment {
  final String itemId;
  final ExtractedItem? metadata;
  final String? imageUrl;
  final String? imageBase64;
  final String status; // 'success' or 'failed'
  final String? backgroundRemovalStatus;
  final String? error;
  final String? warning;

  GeneratedGarment({
    required this.itemId,
    this.metadata,
    this.imageUrl,
    this.imageBase64,
    required this.status,
    this.backgroundRemovalStatus,
    this.error,
    this.warning,
  });

  factory GeneratedGarment.fromJson(Map<String, dynamic> json) {
    return GeneratedGarment(
      itemId: json['item_id'],
      metadata: json['metadata'] != null ? ExtractedItem.fromJson(json['metadata']) : null,
      imageUrl: json['image_url'],
      imageBase64: json['image_base64'],
      status: json['status'],
      backgroundRemovalStatus: json['background_removal_status'],
      error: json['error'],
      warning: json['warning'],
    );
  }
}

class GenerationResponse {
  final String sourceImageId;
  final List<GeneratedGarment> results;

  GenerationResponse({
    required this.sourceImageId,
    required this.results,
  });

  factory GenerationResponse.fromJson(Map<String, dynamic> json) {
    var resultsList = json['results'] as List? ?? [];
    return GenerationResponse(
      sourceImageId: json['source_image_id'] ?? '',
      results: resultsList.map((r) => GeneratedGarment.fromJson(r)).toList(),
    );
  }
}

class BatchResult {
  final String? jobId;
  final int totalSubmitted;
  final int duplicatesSkipped;

  BatchResult({
    this.jobId,
    required this.totalSubmitted,
    required this.duplicatesSkipped,
  });
}
