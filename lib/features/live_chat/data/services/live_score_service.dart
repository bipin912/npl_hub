import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ball_event.dart';
import '../models/match_score.dart';

class LiveScoreService {
  // TODO: paste the Request URL of the "all matches" call here.
  static final Uri _matchesUrl =
  Uri.parse('https://nplt20league.com/api/v1/matches?season=2026');

  static const String _matchesBase = 'https://nplt20league.com/api/v1/matches';

  // One client, one cache and one in-flight request per URL, app-wide.
  static final http.Client _sharedClient = http.Client();
  static final Map<String, ({DateTime at, Object data})> _cache = {};
  static final Map<String, Future<Object>> _inFlight = {};
  static const Duration _ttl = Duration(seconds: 2);

  LiveScoreService({http.Client? client});

  Future<Object> _getJson(Uri url) {
    final key = url.toString();
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return Future.value(hit.data);
    }
    return _inFlight[key] ??= _download(url).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<Object> _download(Uri url) async {
    final response = await _sharedClient.get(
      url,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) NPLCommunityApp/1.0',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch NPL data (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['data'] == null) {
      throw const FormatException('Unexpected NPL API response.');
    }

    final Object data = decoded['data'];
    _cache[url.toString()] = (at: DateTime.now(), data: data);
    return data;
  }

  /// All matches: live, upcoming and completed.
  Future<List<MatchScore>> fetchMatches() async {
    final data = await _getJson(_matchesUrl);
    if (data is! List) {
      throw const FormatException('Unexpected matches response.');
    }
    final fetchedAt = DateTime.now().toUtc();

    return data
        .whereType<Map>()
        .map((m) => MatchScore.fromApi(
      Map<String, dynamic>.from(m),
      fetchedAt: fetchedAt,
    ))
        .toList();
  }

  /// The newest 100 ball rows of a match, merged into deliveries.
  Future<BallFeed> fetchBallFeed({required String matchId}) async {
    if (matchId.trim().isEmpty) {
      throw ArgumentError('Match ID cannot be empty.');
    }

    final url = Uri.parse('$_matchesBase/$matchId/balls?page=1&perPage=100');
    final data = await _getJson(url);

    final raw = data is Map ? data['balls'] : null;
    if (raw is! List) return const BallFeed([], 0);

    return buildFeed(raw.map(BallEvent.tryParse).whereType<BallEvent>());
  }

  // The client is shared, so screens must not close it.
  void dispose() {}
}