import 'package:cloud_firestore/cloud_firestore.dart';
import 'card.dart';

class DailyDeck {
  final String id;
  final DateTime date;
  final String title;
  final String description;
  final List<Card> cards;
  final int color; // Store as int for Firebase
  final String iconName;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  DailyDeck({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.cards,
    required this.color,
    required this.iconName,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.expiresAt,
  });

  factory DailyDeck.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyDeck(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] ?? 'Daily Challenge',
      description: data['description'] ?? '',
      cards:
          (data['cards'] as List<dynamic>?)
              ?.map(
                (card) => Card(
                  word: card['word'] ?? '',
                  category: card['category'] ?? '',
                  difficulty: card['difficulty'] ?? 1,
                ),
              )
              .toList() ??
          [],
      color: data['color'] ?? 0xFF4CAF50,
      iconName: data['iconName'] ?? 'calendar_today',
      imageUrl: data['imageUrl'] as String?,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt:
          data['expiresAt'] != null
              ? (data['expiresAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// Create a DailyDeck from Supabase response (snake_case to camelCase)
  factory DailyDeck.fromSupabase(Map<String, dynamic> row) {
    return DailyDeck(
      id: row['id'] as String,
      date: DateTime.parse(row['date'] as String),
      title: row['title'] as String? ?? 'Daily Challenge',
      description: row['description'] as String? ?? '',
      cards: (row['cards'] as List<dynamic>?)
              ?.map(
                (card) => Card(
                  word: card['word'] ?? '',
                  category: card['category'] ?? '',
                  difficulty: card['difficulty'] ?? 1,
                ),
              )
              .toList() ??
          [],
      color: row['color'] as int? ?? 0xFF4CAF50,
      iconName: row['icon_name'] as String? ?? 'calendar_today',
      imageUrl: row['image_url'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      expiresAt: row['expires_at'] != null
          ? DateTime.parse(row['expires_at'] as String)
          : null,
    );
  }

  /// Convert to Supabase format (camelCase to snake_case)
  Map<String, dynamic> toSupabase() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'title': title,
      'description': description,
      'cards': cards.map((card) => {
        'word': card.word,
        'category': card.category,
        'difficulty': card.difficulty,
      }).toList(),
      'color': color,
      'icon_name': iconName,
      'image_url': imageUrl,
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'title': title,
      'description': description,
      'cards':
          cards
              .map(
                (card) => {
                  'word': card.word,
                  'category': card.category,
                  'difficulty': card.difficulty,
                },
              )
              .toList(),
      'color': color,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  // Check if this daily deck is for today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Check if the deck has expired
  bool get hasExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
