/// Current tracking session metadata persisted when STOP is pressed.
class TrackingSession {
  const TrackingSession({
    required this.id,
    required this.startedAt,
    this.stoppedAt,
    this.isActive = true,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final bool isActive;

  TrackingSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? stoppedAt,
    bool? isActive,
  }) {
    return TrackingSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
