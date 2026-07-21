import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart' show isGuest;
import '../services/user_data_manager.dart';

class FriendEntry {
  final String uid;
  final String username;
  final int level;
  final int expPoints;
  final Uint8List? pfpBytes;
  final bool isPremium;

  FriendEntry({
    required this.uid,
    required this.username,
    required this.level,
    required this.expPoints,
    this.pfpBytes,
    this.isPremium = false,
  });

  factory FriendEntry.fromJson(Map<String, dynamic> json) {
    Uint8List? pfp;
    if (json['pfp_base64'] != null) {
      pfp = base64Decode(json['pfp_base64'] as String);
    }
    return FriendEntry(
      uid: json['uid'] as String,
      username: json['username'] as String,
      level: json['level'] as int,
      expPoints: json['exp_points'] as int? ?? 0,
      pfpBytes: pfp,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }
}

class FriendsState {
  final List<FriendEntry> friends;
  final List<FriendEntry> incoming;
  final List<FriendEntry> outgoing;
  final bool friendsHasMore;
  final bool incomingHasMore;
  final bool outgoingHasMore;

  const FriendsState({
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.friendsHasMore = false,
    this.incomingHasMore = false,
    this.outgoingHasMore = false,
  });

  int get incomingCount =>
      incomingHasMore ? incoming.length + 1 : incoming.length;
  int get outgoingCount =>
      outgoingHasMore ? outgoing.length + 1 : outgoing.length;

  FriendsState copyWith({
    List<FriendEntry>? friends,
    List<FriendEntry>? incoming,
    List<FriendEntry>? outgoing,
    bool? friendsHasMore,
    bool? incomingHasMore,
    bool? outgoingHasMore,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      friendsHasMore: friendsHasMore ?? this.friendsHasMore,
      incomingHasMore: incomingHasMore ?? this.incomingHasMore,
      outgoingHasMore: outgoingHasMore ?? this.outgoingHasMore,
    );
  }
}

class FriendsNotifier extends AsyncNotifier<FriendsState> {
  static const int _pageSize = 12;
  // cache for friend search
  final Map<String, FriendEntry> cache = {};

  @override
  Future<FriendsState> build() async {
    if (isGuest) {
      return FriendsState(
        friends: [
          FriendEntry(
            uid: 'guest_1',
            username: 'HealthHero',
            level: 14,
            expPoints: 3200,
          ),
          FriendEntry(
            uid: 'guest_2',
            username: 'FitStreak99',
            level: 8,
            expPoints: 1400,
          ),
          FriendEntry(
            uid: 'guest_3',
            username: 'NutriChamp',
            level: 21,
            expPoints: 7800,
          ),
        ],
      );
    }
    return _fetchAll();
  }

  Future<FriendsState> _fetchAll() async {
    final results = await Future.wait([
      authenticatedGet('friends?limit=$_pageSize&offset=0'),
      authenticatedGet('friends/requests/incoming?limit=5&offset=0'),
      authenticatedGet('friends/requests/outgoing?limit=5&offset=0'),
    ]);

    List<FriendEntry> friends = [];
    bool friendsHasMore = false;
    if (results[0].statusCode == 200) {
      final data = jsonDecode(results[0].body) as Map<String, dynamic>;
      friends = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      friendsHasMore = data['has_more'] as bool? ?? false;
      for (final f in friends) {
        cache[f.uid] = f;
      }
    }

    List<FriendEntry> incoming = [];
    bool incomingHasMore = false;
    if (results[1].statusCode == 200) {
      final data = jsonDecode(results[1].body) as Map<String, dynamic>;
      incoming = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      incomingHasMore = data['has_more'] as bool? ?? false;
    }

    List<FriendEntry> outgoing = [];
    bool outgoingHasMore = false;
    if (results[2].statusCode == 200) {
      final data = jsonDecode(results[2].body) as Map<String, dynamic>;
      outgoing = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      outgoingHasMore = data['has_more'] as bool? ?? false;
    }

    return FriendsState(
      friends: friends,
      incoming: incoming,
      outgoing: outgoing,
      friendsHasMore: friendsHasMore,
      incomingHasMore: incomingHasMore,
      outgoingHasMore: outgoingHasMore,
    );
  }

  Future<void> refresh() async {
    if (isGuest) return;
    try {
      final next = await _fetchAll();
      state = AsyncData(next);
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsNotifier refresh error: $e');
    }
  }

  // frontend-only patch, actual unfriend POST is fired by the profile card
  void removeFriend(String uid) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        friends: current.friends.where((f) => f.uid != uid).toList(),
      ),
    );
  }

  Future<void> loadMoreFriends() async {
    final current = state.value;
    if (current == null || !current.friendsHasMore) return;
    try {
      final res = await authenticatedGet(
        'friends?limit=$_pageSize&offset=${current.friends.length}',
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final f in items) {
        cache[f.uid] = f;
      }
      state = AsyncData(
        current.copyWith(
          friends: [...current.friends, ...items],
          friendsHasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsNotifier loadMoreFriends error: $e');
    }
  }

  Future<void> expandIncoming() async {
    final current = state.value;
    if (current == null) return;
    try {
      final res = await authenticatedGet(
        'friends/requests/incoming?limit=20&offset=0',
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncData(
        current.copyWith(
          incoming: items,
          incomingHasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsNotifier expandIncoming error: $e');
    }
  }

  Future<void> expandOutgoing() async {
    final current = state.value;
    if (current == null) return;
    try {
      final res = await authenticatedGet(
        'friends/requests/outgoing?limit=20&offset=0',
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncData(
        current.copyWith(
          outgoing: items,
          outgoingHasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsNotifier expandOutgoing error: $e');
    }
  }

  Future<List<FriendEntry>> searchFriends(String query) async {
    if (query.isEmpty) return [];
    try {
      final res = await authenticatedGet(
        'friends/search?q=${Uri.encodeComponent(query)}',
      );
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final f in items) {
        cache[f.uid] = f;
      }
      return items;
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsNotifier searchFriends error: $e');
      return [];
    }
  }
}

final friendsProvider = AsyncNotifierProvider<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);
