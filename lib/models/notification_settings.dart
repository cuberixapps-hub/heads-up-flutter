/// Model for user notification preferences
class NotificationSettings {
  /// Master toggle for all notifications
  final bool enabled;

  /// Enable streak reminder notifications
  final bool streakReminders;

  /// Enable new content notifications
  final bool newContentNotifications;

  /// Enable challenge notifications
  final bool challengeReminders;

  /// Enable inactivity re-engagement notifications
  final bool inactivityReminders;

  /// Hour for streak reminder (0-23)
  final int streakReminderHour;

  /// Minute for streak reminder (0-59)
  final int streakReminderMinute;

  const NotificationSettings({
    required this.enabled,
    required this.streakReminders,
    required this.newContentNotifications,
    required this.challengeReminders,
    required this.inactivityReminders,
    required this.streakReminderHour,
    required this.streakReminderMinute,
  });

  /// Default notification settings
  factory NotificationSettings.defaults() {
    return const NotificationSettings(
      enabled: true,
      streakReminders: true,
      newContentNotifications: true,
      challengeReminders: true,
      inactivityReminders: true,
      streakReminderHour: 19, // 7 PM
      streakReminderMinute: 0,
    );
  }

  /// Create from JSON
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] as bool? ?? true,
      streakReminders: json['streakReminders'] as bool? ?? true,
      newContentNotifications: json['newContentNotifications'] as bool? ?? true,
      challengeReminders: json['challengeReminders'] as bool? ?? true,
      inactivityReminders: json['inactivityReminders'] as bool? ?? true,
      streakReminderHour: json['streakReminderHour'] as int? ?? 19,
      streakReminderMinute: json['streakReminderMinute'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'streakReminders': streakReminders,
      'newContentNotifications': newContentNotifications,
      'challengeReminders': challengeReminders,
      'inactivityReminders': inactivityReminders,
      'streakReminderHour': streakReminderHour,
      'streakReminderMinute': streakReminderMinute,
    };
  }

  /// Create a copy with updated values
  NotificationSettings copyWith({
    bool? enabled,
    bool? streakReminders,
    bool? newContentNotifications,
    bool? challengeReminders,
    bool? inactivityReminders,
    int? streakReminderHour,
    int? streakReminderMinute,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      streakReminders: streakReminders ?? this.streakReminders,
      newContentNotifications:
          newContentNotifications ?? this.newContentNotifications,
      challengeReminders: challengeReminders ?? this.challengeReminders,
      inactivityReminders: inactivityReminders ?? this.inactivityReminders,
      streakReminderHour: streakReminderHour ?? this.streakReminderHour,
      streakReminderMinute: streakReminderMinute ?? this.streakReminderMinute,
    );
  }

  /// Get formatted reminder time string
  String get formattedReminderTime {
    final hour = streakReminderHour;
    final minute = streakReminderMinute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  @override
  String toString() {
    return 'NotificationSettings(enabled: $enabled, streak: $streakReminders, '
        'content: $newContentNotifications, challenges: $challengeReminders, '
        'inactivity: $inactivityReminders, time: $formattedReminderTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.streakReminders == streakReminders &&
        other.newContentNotifications == newContentNotifications &&
        other.challengeReminders == challengeReminders &&
        other.inactivityReminders == inactivityReminders &&
        other.streakReminderHour == streakReminderHour &&
        other.streakReminderMinute == streakReminderMinute;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      streakReminders,
      newContentNotifications,
      challengeReminders,
      inactivityReminders,
      streakReminderHour,
      streakReminderMinute,
    );
  }
}







