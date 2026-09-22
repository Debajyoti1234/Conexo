class AdminUserDetail {
  AdminUserDetail({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.registrationDate,
    required this.lastSignInAt,
    this.emailConfirmedAt,
    this.phoneConfirmedAt,
    this.isAnonymous,
    this.isSsoUser,
    this.bannedUntil,
    this.deletedAt,
    this.bio,
    this.interests,
    this.favoriteActivities,
    this.languages,
    this.gender,
    this.location,
    this.socialLinks,
    this.occupation,
    this.education,
    this.company,
    this.college,
    this.hometown,
    this.website,
    this.aboutMe,
    this.verificationStatus,
    this.profileVisibility,
    this.profileCompleted,
    this.dateOfBirth,
    this.availabilityStatus,
    this.photos,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.locationStatus,
    this.latestPlatform,
    this.latestAppVersion,
    this.lastActiveAt,
    this.connectionCount = 0,
    this.conversationMembershipCount = 0,
    this.messagesSentCount = 0,
    this.safetyReportCount = 0,
    this.blockCount = 0,
    this.profileUpdatedAt,
  });

  factory AdminUserDetail.fromMap(Map<String, dynamic> row) {
    DateTime? toDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value is String ? value : value.toString());
    }

    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<String>? toStringList(dynamic value) {
      if (value is List) {
        return [
          for (final item in value)
            if (item is String) item,
        ];
      }
      return null;
    }

    return AdminUserDetail(
      userId: row['user_id'] as String? ?? '',
      displayName: row['display_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      registrationDate: toDate(row['registration_date']),
      lastSignInAt: toDate(row['last_sign_in_at']),
      emailConfirmedAt: toDate(row['email_confirmed_at']),
      phoneConfirmedAt: toDate(row['phone_confirmed_at']),
      isAnonymous: row['is_anonymous'] as bool?,
      isSsoUser: row['is_sso_user'] as bool?,
      bannedUntil: toDate(row['banned_until']),
      deletedAt: toDate(row['deleted_at']),
      bio: row['bio'] as String?,
      interests: toStringList(row['interests']),
      favoriteActivities: toStringList(row['favorite_activities']),
      languages: toStringList(row['languages']),
      gender: row['gender'] as String?,
      location: row['location'] as String?,
      socialLinks: row['social_links'] is Map<String, dynamic>
          ? row['social_links'] as Map<String, dynamic>
          : null,
      occupation: row['occupation'] as String?,
      education: row['education'] as String?,
      company: row['company'] as String?,
      college: row['college'] as String?,
      hometown: row['hometown'] as String?,
      website: row['website'] as String?,
      aboutMe: row['about_me'] as String?,
      verificationStatus: row['verification_status'] as String?,
      profileVisibility: row['profile_visibility'] as String?,
      profileCompleted: row['profile_completed'] as bool?,
      dateOfBirth: toDate(row['date_of_birth']),
      availabilityStatus: row['availability_status'] as String?,
      photos: row['photos'] as List<dynamic>?,
      latitude: toDouble(row['latitude']),
      longitude: toDouble(row['longitude']),
      locationUpdatedAt: toDate(row['location_updated_at']),
      locationStatus: row['location_status'] as String?,
      latestPlatform: row['latest_platform'] as String?,
      latestAppVersion: row['latest_app_version'] as String?,
      lastActiveAt: toDate(row['last_active_at']),
      connectionCount: toInt(row['connection_count']),
      conversationMembershipCount: toInt(row['conversation_membership_count']),
      messagesSentCount: toInt(row['messages_sent_count']),
      safetyReportCount: toInt(row['safety_report_count']),
      blockCount: toInt(row['block_count']),
      profileUpdatedAt: toDate(row['profile_updated_at']),
    );
  }

  final String userId;
  final String? displayName;
  final String? email;
  final String? phone;
  final DateTime? registrationDate;
  final DateTime? lastSignInAt;
  final DateTime? emailConfirmedAt;
  final DateTime? phoneConfirmedAt;
  final bool? isAnonymous;
  final bool? isSsoUser;
  final DateTime? bannedUntil;
  final DateTime? deletedAt;
  final String? bio;
  final List<String>? interests;
  final List<String>? favoriteActivities;
  final List<String>? languages;
  final String? gender;
  final String? location;
  final Map<String, dynamic>? socialLinks;
  final String? occupation;
  final String? education;
  final String? company;
  final String? college;
  final String? hometown;
  final String? website;
  final String? aboutMe;
  final String? verificationStatus;
  final String? profileVisibility;
  final bool? profileCompleted;
  final DateTime? dateOfBirth;
  final String? availabilityStatus;
  final List<dynamic>? photos;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final String? locationStatus;
  final String? latestPlatform;
  final String? latestAppVersion;
  final DateTime? lastActiveAt;
  final int connectionCount;
  final int conversationMembershipCount;
  final int messagesSentCount;
  final int safetyReportCount;
  final int blockCount;
  final DateTime? profileUpdatedAt;
}
