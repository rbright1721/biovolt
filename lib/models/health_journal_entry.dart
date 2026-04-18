class HealthJournalEntry {
  final String id;
  final DateTime timestamp;
  final String userMessage;
  final String aiResponse;
  final bool bookmarked;
  final String? sessionId;
  final List<String> autoTags;
  final bool researchGrounded;
  final String conversationId;

  final double? hrBpm;
  final double? hrvMs;
  final double? gsrUs;
  final double? skinTempF;
  final double? spo2Percent;

  HealthJournalEntry({
    required this.id,
    required this.timestamp,
    required this.userMessage,
    required this.aiResponse,
    this.bookmarked = false,
    this.sessionId,
    this.autoTags = const [],
    this.researchGrounded = false,
    this.conversationId = 'default',
    this.hrBpm,
    this.hrvMs,
    this.gsrUs,
    this.skinTempF,
    this.spo2Percent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'userMessage': userMessage,
        'aiResponse': aiResponse,
        'bookmarked': bookmarked,
        'sessionId': sessionId,
        'autoTags': autoTags,
        'researchGrounded': researchGrounded,
        'conversationId': conversationId,
        'hrBpm': hrBpm,
        'hrvMs': hrvMs,
        'gsrUs': gsrUs,
        'skinTempF': skinTempF,
        'spo2Percent': spo2Percent,
      };

  factory HealthJournalEntry.fromJson(Map<String, dynamic> json) =>
      HealthJournalEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        userMessage: json['userMessage'] as String,
        aiResponse: json['aiResponse'] as String,
        bookmarked: json['bookmarked'] as bool? ?? false,
        sessionId: json['sessionId'] as String?,
        autoTags: (json['autoTags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        researchGrounded: json['researchGrounded'] as bool? ?? false,
        conversationId: json['conversationId'] as String? ?? 'default',
        hrBpm: (json['hrBpm'] as num?)?.toDouble(),
        hrvMs: (json['hrvMs'] as num?)?.toDouble(),
        gsrUs: (json['gsrUs'] as num?)?.toDouble(),
        skinTempF: (json['skinTempF'] as num?)?.toDouble(),
        spo2Percent: (json['spo2Percent'] as num?)?.toDouble(),
      );

  HealthJournalEntry copyWithBookmarked(bool bookmarked) => HealthJournalEntry(
        id: id,
        timestamp: timestamp,
        userMessage: userMessage,
        aiResponse: aiResponse,
        bookmarked: bookmarked,
        sessionId: sessionId,
        autoTags: autoTags,
        researchGrounded: researchGrounded,
        conversationId: conversationId,
        hrBpm: hrBpm,
        hrvMs: hrvMs,
        gsrUs: gsrUs,
        skinTempF: skinTempF,
        spo2Percent: spo2Percent,
      );
}
