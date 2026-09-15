class GarmentModel {
  final String? id;
  final String userId;
  final String name;
  final String category;
  final String? subcategory;
  final String? primaryColor;
  final String? secondaryColor;
  final String? pattern;
  final String? style;
  final String? fit;
  final String studioImagePath;
  final String? sourceImagePath;
  final DateTime? createdAt;

  GarmentModel({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.subcategory,
    this.primaryColor,
    this.secondaryColor,
    this.pattern,
    this.style,
    this.fit,
    required this.studioImagePath,
    this.sourceImagePath,
    this.createdAt,
  });

  factory GarmentModel.fromJson(Map<String, dynamic> json) {
    return GarmentModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      category: json['category'],
      subcategory: json['subcategory'],
      primaryColor: json['primary_color'],
      secondaryColor: json['secondary_color'],
      pattern: json['pattern'],
      style: json['style'],
      fit: json['fit'],
      studioImagePath: json['studio_image_path'],
      sourceImagePath: json['source_image_path'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'category': category,
      'studio_image_path': studioImagePath,
    };
    
    if (id != null) data['id'] = id;
    if (subcategory != null) data['subcategory'] = subcategory;
    if (primaryColor != null) data['primary_color'] = primaryColor;
    if (secondaryColor != null) data['secondary_color'] = secondaryColor;
    if (pattern != null) data['pattern'] = pattern;
    if (style != null) data['style'] = style;
    if (fit != null) data['fit'] = fit;
    if (sourceImagePath != null) data['source_image_path'] = sourceImagePath;
    
    return data;
  }
}
