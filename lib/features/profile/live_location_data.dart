class LiveLocation {
  const LiveLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory LiveLocation.fromJson(Map<String, dynamic> json) => LiveLocation(
        userId: json['user_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
      };

  final String userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
}
