class MatchScore {
  const MatchScore({
    required this.id,
    required this.team1,
    required this.team2,
    required this.abbr1,
    required this.abbr2,
    required this.status,
    required this.statusText,
    required this.score1,
    required this.score2,
    required this.overs1,
    required this.overs2,
    required this.matchDesc,
    required this.seriesName,
    required this.winner,
    required this.fetchedAt,
  });

  final String id;
  final String team1;
  final String team2;
  final String abbr1;
  final String abbr2;
  final String status;
  final String statusText;
  final String score1;
  final String score2;
  final String overs1;
  final String overs2;
  final String matchDesc;
  final String seriesName;
  final String winner;
  final DateTime? fetchedAt;

  factory MatchScore.fromApi(
      Map<String, dynamic> json, {
        DateTime? fetchedAt,
      }) {
    final parts = (json['participants'] is List
        ? json['participants'] as List
        : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    Map<String, dynamic> side(String name) => parts.firstWhere(
          (p) => p['side'] == name,
      orElse: () => <String, dynamic>{},
    );

    final t1 = side('team1');
    final t2 = side('team2');

    final rawStatus = _s(json['status'], '').toLowerCase();
    final status = rawStatus == 'scheduled' ? 'upcoming' : rawStatus;
    final result = _s(json['result'], '');

    final String statusText;
    if (status == 'completed') {
      statusText = result.isEmpty ? 'Completed' : result;
    } else if (status == 'live') {
      statusText = 'In progress';
    } else {
      final when = [_s(json['dateLabel'], ''), _s(json['timeLabel'], '')]
          .where((e) => e.isNotEmpty)
          .join(' • ');
      statusText = when.isEmpty ? 'Upcoming' : when;
    }

    return MatchScore(
      id: _s(json['id'], ''),
      team1: _s(t1['teamName'], 'Team 1'),
      team2: _s(t2['teamName'], 'Team 2'),
      abbr1: _s(t1['shortCode'], ''),
      abbr2: _s(t2['shortCode'], ''),
      status: status,
      statusText: statusText,
      score1: _s(t1['score'], ''),
      score2: _s(t2['score'], ''),
      overs1: _s(t1['overs'], ''),
      overs2: _s(t2['overs'], ''),
      matchDesc: _s(json['matchNumber'], ''),
      seriesName: 'Nepal Premier League ${_s(json['year'], '')}'.trim(),
      winner: _s(json['winnerLabel'], ''),
      fetchedAt: fetchedAt,
    );
  }

  static String _s(dynamic value, String fallback) {
    if (value == null) return fallback;
    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';

  bool get isCompleted =>
      status == 'completed' || status == 'complete' || status == 'finished';

  bool get isFinished => isCompleted;

  bool isFreshWithin(Duration maxAge) {
    final f = fetchedAt?.toUtc();
    if (f == null) return false;
    final now = DateTime.now().toUtc();
    return !f.isAfter(now.add(const Duration(minutes: 1))) &&
        now.difference(f) <= maxAge;
  }
}