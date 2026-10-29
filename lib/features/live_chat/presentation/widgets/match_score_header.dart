
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/match_score.dart';
import '../../data/services/live_score_service.dart';

class MatchScoreHeader extends StatefulWidget {
  const MatchScoreHeader({super.key});

  @override
  State<MatchScoreHeader> createState() => _MatchScoreHeaderState();
}

class _MatchScoreHeaderState extends State<MatchScoreHeader> {
  final LiveScoreService _scoreService = LiveScoreService();

  List<MatchScore> _matches = [];
  bool _isLoading = true;
  bool _isFetchingScores = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadScores();

    // Refresh scores every 8 seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) => _loadScores(),
    );
  }

  Future<void> _loadScores() async {
    if (_isFetchingScores) return;
    _isFetchingScores = true;

    try {
      final matches = await _scoreService.fetchMatches();

      if (!mounted) return;

      setState(() {
        _matches = matches;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load NPL scores: $error');

      if (!mounted) return;

      setState(() {
        _error = 'Unable to load NPL scores.';
        _isLoading = false;
      });
    } finally {
      _isFetchingScores = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scoreService.dispose();
    super.dispose();
  }

  bool _isCompletedMatch(MatchScore match) {
    final status = match.status.toLowerCase().trim();
    final text = match.statusText.toLowerCase().trim();

    return match.isCompleted ||
        status == 'result' ||
        status == 'complete' ||
        status == 'completed' ||
        status == 'finished' ||
        text.contains('won by') ||
        text.contains('match tied') ||
        text == 'tied' ||
        text.contains('no result') ||
        text.contains('abandoned') ||
        text.contains('match drawn');
  }

  MatchScore _selectMatch(List<MatchScore> matches) {
    for (final match in matches) {
      if (match.isLive && !_isCompletedMatch(match)) {
        return match;
      }
    }

    for (final match in matches) {
      if (match.isUpcoming && !_isCompletedMatch(match)) {
        return match;
      }
    }

    for (final match in matches) {
      if (_isCompletedMatch(match)) {
        return match;
      }
    }

    return matches.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.65),
            width: 0.7,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NEPAL PREMIER LEAGUE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          if (_isLoading && _matches.isEmpty)
            const SizedBox(
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_matches.isEmpty && _error != null)
            _buildError()
          else if (_matches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No NPL matches available.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...[
                _buildMatch(_selectMatch(_matches)),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Showing last available scores',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
        ],
      ),
    );
  }

  Widget _buildMatch(MatchScore match) {
    final isLive = match.isLive && !_isCompletedMatch(match);
    final showLogos = !_isCompletedMatch(match) && (match.isLive || match.isUpcoming);

    final score1 =
    match.score1.isNotEmpty ? match.score1 : 'Yet to bat';
    final score2 =
    match.score2.isNotEmpty ? match.score2 : 'Yet to bat';

    final statusLabel = isLive
        ? 'LIVE • ${match.statusText}'
        : match.statusText.toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TeamScore(
                teamName: match.team1,
                abbr: match.abbr1,
                showLogo: showLogos,
                score: score1,
                overs: match.overs1.isNotEmpty ? '${match.overs1} ov' : '',
                alignment: CrossAxisAlignment.start,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'VS',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: _TeamScore(
                teamName: match.team2,
                abbr: match.abbr2,
                showLogo: showLogos,
                score: score2,
                overs: match.overs2.isNotEmpty ? '${match.overs2} ov' : '',
                alignment: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: isLive
                ? const Color(0xFFE8F5E9)
                : AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: isLive
                  ? const Color(0xFF237A38)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        // if (match.matchDesc.isNotEmpty) ...[
        //   const SizedBox(height: 5),
        //   Text(
        //     match.matchDesc,
        //     maxLines: 1,
        //     overflow: TextOverflow.ellipsis,
        //     textAlign: TextAlign.center,
        //     style: const TextStyle(
        //       fontSize: 10,
        //       color: AppColors.textSecondary,
        //     ),
        //   ),
        // ],
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Unable to load NPL scores.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: _loadScores,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.teamName,
    required this.abbr,
    required this.showLogo,
    required this.score,
    required this.overs,
    required this.alignment,
  });

  final String teamName;
  final String abbr;
  final bool showLogo;
  final String score;
  final String overs;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final isRight = alignment == CrossAxisAlignment.end;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        if (showLogo) ...[
          _TeamLogo(teamName: teamName, abbr: abbr),
          const SizedBox(height: 3),
        ],
        Text(
          teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isRight ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        // Score and overs share one line to save height.
        Text.rich(
          TextSpan(
            text: score,
            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            children: [
              if (overs.isNotEmpty)
                TextSpan(
                  text: '  $overs',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isRight ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.teamName, required this.abbr});

  final String teamName;
  final String abbr;

  static const double _size = 40;

  // "Janakpur Bolts" -> "janakpur_bolts"
  String get _assetPath {
    final slug = teamName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'assets/images/teams/$slug.png';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Image.asset(
        _assetPath,
        fit: BoxFit.contain,
        // Missing file: show the abbreviation as plain text.
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            abbr.isNotEmpty
                ? abbr
                : (teamName.isNotEmpty ? teamName[0] : '?'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
