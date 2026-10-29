
class BallCommentary {
  const BallCommentary({
    required this.seq,
    required this.period,
    required this.over,
    required this.text,
  });

  /// Unique commentary event ID provided by the cricket API.
  final int seq;

  /// Innings number.
  final int period;

  /// Ball position, such as 16.5.
  final double over;

  /// Commentary describing the delivery's outcome.
  final String text;

  factory BallCommentary.fromMap(Map<String, dynamic> json) {
    final rawSeq = json['seq'];
    final rawPeriod = json['period'];
    final rawOver = json['over'];
    final rawText = json['text'];

    final seq = rawSeq is num
        ? rawSeq.toInt()
        : int.tryParse(rawSeq?.toString() ?? '');

    final period = rawPeriod is num
        ? rawPeriod.toInt()
        : int.tryParse(rawPeriod?.toString() ?? '');

    final over = rawOver is num
        ? rawOver.toDouble()
        : double.tryParse(rawOver?.toString() ?? '');

    if (seq == null || period == null || over == null) {
      throw const FormatException(
        'Invalid ball commentary: missing sequence, innings, or over.',
      );
    }

    return BallCommentary(
      seq: seq,
      period: period,
      over: over,
      text: rawText?.toString() ?? '',
    );
  }

  String get normalizedText => text.toLowerCase().trim();

  /// The part after "Bowler to Batter," e.g. "six", "no run".
  String get outcome {
    final i = text.indexOf(',');
    return (i == -1 ? text : text.substring(i + 1)).toLowerCase().trim();
  }

  bool get isFour => RegExp(r'\bfour\b').hasMatch(outcome);
  bool get isSix => RegExp(r'\bsix\b').hasMatch(outcome);
  bool get isWide => RegExp(r'\bwide\b').hasMatch(outcome);
  bool get isNoBall => RegExp(r'\bno[- ]ball\b').hasMatch(outcome);

  bool get isDotBall => RegExp(r'^no runs?\b|\bdot ball\b').hasMatch(outcome);

  bool get isWicket =>
      !isFour &&
          !isSix &&
          RegExp(r'\bout\b|\bwicket\b|\bbowled\b|\bcaught\b|\blbw\b|\brun out\b|\bstumped\b')
              .hasMatch(outcome);

  bool get isOrdinaryRuns => RegExp(
    r'^[1-35]\s+runs?\b|\b(single|double|triple)\b|\bleg byes?\b|\bbyes?\b',
  ).hasMatch(outcome);
}
