enum BallOutcome { four, six, dot, runs, wicket }

class BallEvent {
  const BallEvent({
    required this.sequence,
    required this.innings,
    required this.overNumber,
    required this.ballNumber,
    required this.text,
    required this.label,
    required this.runs,
    required this.isWicket,
    required this.isBoundary,
    required this.hasBatter,
  });

  final int sequence; // epoch milliseconds
  final String innings;
  final int overNumber;
  final int ballNumber;
  final String text;
  final String label; // "WD", "B1", "L1", "WK", "4", ...
  final int runs;
  final bool isWicket;
  final bool isBoundary;
  final bool hasBatter; // true for the complete (new-format) records

  static BallEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    if (j['type'] != 'ball') return null; // skips batter / wicket / info rows

    final seq = j['sequence'];
    final over = j['overNumber'];
    final ball = j['ballNumber'];
    final innings = j['inningsId'];
    if (seq is! num || over is! num || ball is! num || innings is! String) {
      return null;
    }
    final runs = j['runsScored'];

    return BallEvent(
      sequence: seq.toInt(),
      innings: innings,
      overNumber: over.toInt(),
      ballNumber: ball.toInt(),
      text: (j['text'] ?? '').toString(),
      label: (j['runs'] ?? '').toString().trim(),
      runs: runs is num ? runs.toInt() : 0,
      isWicket: j['isWicket'] == true,
      isBoundary: j['isBoundary'] == true,
      hasBatter: (j['batterName'] ?? '').toString().isNotEmpty,
    );
  }

  /// e.g. "1.2"
  String get ballLabel => '$overNumber.$ballNumber';

  String get key => '$innings|$overNumber|$ballNumber';

  // Text after "Bowler to Batter:" (or the old format's first comma).
  String get _tail {
    final i = text.indexOf(RegExp(r'[:,]'));
    return (i == -1 ? text : text.substring(i + 1)).toLowerCase();
  }

  /// Wide, no-ball, bye, leg bye or penalty.
  bool get isExtra {
    if (RegExp(r'^(WD|NB|LB|B|L)\d*$', caseSensitive: false).hasMatch(label)) {
      return true;
    }
    return RegExp(r'\b(wide|no[- ]?ball|byes?|leg[- ]?byes?|penalty)\b')
        .hasMatch(_tail);
  }

  /// null = not a usable delivery (extras, run outs): skip it.
  BallOutcome? get outcome {
    if (isExtra) return null;
    if (RegExp(r'\brun[- ]?out\b').hasMatch(text.toLowerCase())) return null;
    if (isWicket) return BallOutcome.wicket;
    if (isBoundary && runs == 4) return BallOutcome.four;
    if (isBoundary && runs == 6) return BallOutcome.six;
    if (runs == 0) return BallOutcome.dot;
    if (runs > 0 && !isBoundary) return BallOutcome.runs;
    return null;
  }
}

/// One delivery, after merging all of its duplicate rows.
class Delivery {
  const Delivery({
    required this.key,
    required this.event,
    required this.firstSeen,
    required this.lastSeen,
    required this.hasExtra,
  });

  final String key;
  final BallEvent event; // newest complete row
  final int firstSeen; // used for ordering and baseSeq
  final int lastSeen; // newest row: used to tell when it stopped changing
  final bool hasExtra; // any row for this ball is an extra: don't settle on it
}

class BallFeed {

  /// The ball a prediction made right now will most likely settle on.
  String? get nextBallLabel {
    if (deliveries.isEmpty) return null;
    // Ignore wides/no-balls: they don't use up a legal ball.
    final last = deliveries
        .lastWhere((d) => !d.hasExtra, orElse: () => deliveries.last)
        .event;
    if (last.ballNumber >= 6) return '${last.overNumber + 1}.1';
    return '${last.overNumber}.${last.ballNumber + 1}';
  }
  const BallFeed(this.deliveries, this.newestSequence);

  final List<Delivery> deliveries; // oldest first
  final int newestSequence; // the feed's own clock

  int get latestFirstSeen =>
      deliveries.isEmpty ? 0 : deliveries.last.firstSeen;
}

BallFeed buildFeed(Iterable<BallEvent> events) {
  final groups = <String, List<BallEvent>>{};
  var newest = 0;

  for (final e in events) {
    groups.putIfAbsent(e.key, () => []).add(e);
    if (e.sequence > newest) newest = e.sequence;
  }

  final deliveries = <Delivery>[];
  for (final entry in groups.entries) {
    final rows = entry.value..sort((a, b) => a.sequence.compareTo(b.sequence));
    final complete = rows.where((e) => e.hasBatter).toList();
    final pick = complete.isNotEmpty ? complete.last : rows.last;
    deliveries.add(Delivery(
      key: entry.key,
      event: pick,
      firstSeen: rows.first.sequence,
      lastSeen: rows.last.sequence,
      hasExtra: rows.any((e) => e.isExtra),
    ));
  }

  deliveries.sort((a, b) => a.firstSeen.compareTo(b.firstSeen));
  return BallFeed(deliveries, newest);
}