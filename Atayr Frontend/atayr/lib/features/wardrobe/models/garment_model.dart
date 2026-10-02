class Garment {
  final String id;
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
  final bool isSharedWithFriends;
  final DateTime createdAt;

  Garment({
    required this.id,
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
    this.isSharedWithFriends = false,
    required this.createdAt,
  });

  factory Garment.fromJson(Map<String, dynamic> json) {
    return Garment(
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
      isSharedWithFriends: json['is_shared_with_friends'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category,
    'subcategory': subcategory,
    'primary_color': primaryColor,
    'secondary_color': secondaryColor,
    'pattern': pattern,
    'style': style,
    'fit': fit,
    'studio_image_path': studioImagePath,
    'source_image_path': sourceImagePath,
    'is_shared_with_friends': isSharedWithFriends,
    'created_at': createdAt.toIso8601String(),
  };

  Garment copyWith({
    String? name,
    bool? isSharedWithFriends,
  }) {
    return Garment(
      id: id,
      userId: userId,
      name: name ?? this.name,
      category: category,
      subcategory: subcategory,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      pattern: pattern,
      style: style,
      fit: fit,
      studioImagePath: studioImagePath,
      sourceImagePath: sourceImagePath,
      isSharedWithFriends: isSharedWithFriends ?? this.isSharedWithFriends,
      createdAt: createdAt,
    );
  }

  String get canonicalCategory {
    final lower = category.toLowerCase();
    if (['top', 'tops', 'topwear', 'upper'].contains(lower)) {
      return 'Top';
    } else if (['bottom', 'bottoms', 'bottomwear', 'lower', 'pants'].contains(lower)) {
      return 'Bottom';
    } else if (lower == 'outerwear') {
      return 'Outerwear';
    } else if (lower == 'footwear') {
      return 'Footwear';
    } else if (['accessory', 'accessories'].contains(lower)) {
      return 'Accessories';
    } else {
      // Fallback
      if (lower.isEmpty) return 'Other';
      return lower[0].toUpperCase() + lower.substring(1);
    }
  }
}
