class VitalsBookmark {
  final String id;
  final DateTime timestamp;
  final String? note;
  final double? hrBpm;
  final double? hrvMs;
  final double? gsrUs;
  final double? skinTempF;
  final double? spo2Percent;
  final double? ecgHrBpm;

  VitalsBookmark({
    required this.id,
    required this.timestamp,
    this.note,
    this.hrBpm,
    this.hrvMs,
    this.gsrUs,
    this.skinTempF,
    this.spo2Percent,
    this.ecgHrBpm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
        'hrBpm': hrBpm,
        'hrvMs': hrvMs,
        'gsrUs': gsrUs,
        'skinTempF': skinTempF,
        'spo2Percent': spo2Percent,
        'ecgHrBpm': ecgHrBpm,
      };

  factory VitalsBookmark.fromJson(Map<String, dynamic> json) =>
      VitalsBookmark(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        note: json['note'] as String?,
        hrBpm: (json['hrBpm'] as num?)?.toDouble(),
        hrvMs: (json['hrvMs'] as num?)?.toDouble(),
        gsrUs: (json['gsrUs'] as num?)?.toDouble(),
        skinTempF: (json['skinTempF'] as num?)?.toDouble(),
        spo2Percent: (json['spo2Percent'] as num?)?.toDouble(),
        ecgHrBpm: (json['ecgHrBpm'] as num?)?.toDouble(),
      );
}
