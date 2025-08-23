class Card {
  final String word;
  final String category;
  final int difficulty;

  Card({required this.word, required this.category, required this.difficulty});

  factory Card.fromMap(Map<String, dynamic> map) {
    return Card(
      word: map['word'] ?? '',
      category: map['category'] ?? '',
      difficulty: map['difficulty'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {'word': word, 'category': category, 'difficulty': difficulty};
  }
}
