import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardPage {
  final List<DocumentSnapshot> entries;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int pageNumber;
  
  LeaderboardPage({
    required this.entries,
    this.lastDocument,
    required this.hasMore,
    this.pageNumber = 0,
  });
  
  List<Map<String, dynamic>> get data {
    return entries.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'userId': doc.id,
        ...data,
      };
    }).toList();
  }
  
  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
  int get length => entries.length;
}

class CachedLeaderboardData {
  final List<LeaderboardPage> pages;
  final DateTime lastUpdated;
  
  CachedLeaderboardData({
    required this.pages,
    required this.lastUpdated,
  });
  
  List<Map<String, dynamic>> get allEntries {
    final List<Map<String, dynamic>> all = [];
    for (final page in pages) {
      all.addAll(page.data);
    }
    return all;
  }
  
  int get totalEntries => pages.fold(0, (sum, page) => sum + page.length);
  bool get hasMore => pages.isEmpty ? true : pages.last.hasMore;
}
