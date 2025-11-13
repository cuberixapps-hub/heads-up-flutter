class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired {
    final expiryTime = timestamp.add(ttl);
    return DateTime.now().isAfter(expiryTime);
  }

  Duration get timeUntilExpiry {
    final expiryTime = timestamp.add(ttl);
    final remaining = expiryTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Map<String, dynamic> toJson({
    required Map<String, dynamic> Function(T) dataToJson,
  }) {
    return {
      'data': dataToJson(data),
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl.inSeconds,
    };
  }

  factory CacheEntry.fromJson({
    required Map<String, dynamic> json,
    required T Function(Map<String, dynamic>) dataFromJson,
  }) {
    return CacheEntry<T>(
      data: dataFromJson(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      ttl: Duration(seconds: json['ttl']),
    );
  }
}
