import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firestore = FirebaseFirestore.instance;

  print('🎮 Starting to populate Daily Heads Up data...');

  // Get today's date at midnight
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Create daily challenges for the next 7 days
  final dailyDecks = [
    {
      'date': Timestamp.fromDate(today),
      'title': 'Monday Madness',
      'description': 'Start your week with these fun challenges!',
      'cards': [
        {'word': 'Pizza', 'category': 'Food', 'difficulty': 1},
        {'word': 'Hamburger', 'category': 'Food', 'difficulty': 1},
        {'word': 'Sushi', 'category': 'Food', 'difficulty': 2},
        {'word': 'Tacos', 'category': 'Food', 'difficulty': 1},
        {'word': 'Ice Cream', 'category': 'Dessert', 'difficulty': 1},
        {'word': 'Pasta', 'category': 'Food', 'difficulty': 1},
        {'word': 'Salad', 'category': 'Food', 'difficulty': 1},
        {'word': 'Steak', 'category': 'Food', 'difficulty': 2},
        {'word': 'Soup', 'category': 'Food', 'difficulty': 1},
        {'word': 'Sandwich', 'category': 'Food', 'difficulty': 1},
      ],
      'color': 0xFF4CAF50, // Green
      'iconName': 'calendar_today',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 1))),
      'title': 'Movie Tuesday',
      'description': 'Guess these famous movies and characters!',
      'cards': [
        {'word': 'Harry Potter', 'category': 'Movies', 'difficulty': 1},
        {'word': 'Star Wars', 'category': 'Movies', 'difficulty': 1},
        {'word': 'Avatar', 'category': 'Movies', 'difficulty': 2},
        {'word': 'Titanic', 'category': 'Movies', 'difficulty': 1},
        {'word': 'The Lion King', 'category': 'Movies', 'difficulty': 1},
        {'word': 'Frozen', 'category': 'Movies', 'difficulty': 1},
        {'word': 'Avengers', 'category': 'Movies', 'difficulty': 1},
        {'word': 'Batman', 'category': 'Superheroes', 'difficulty': 1},
        {'word': 'Spider-Man', 'category': 'Superheroes', 'difficulty': 1},
        {'word': 'Wonder Woman', 'category': 'Superheroes', 'difficulty': 2},
      ],
      'color': 0xFF2196F3, // Blue
      'iconName': 'star',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 2))),
      'title': 'Wild Wednesday',
      'description': 'Animals and nature themed challenges!',
      'cards': [
        {'word': 'Lion', 'category': 'Animals', 'difficulty': 1},
        {'word': 'Elephant', 'category': 'Animals', 'difficulty': 1},
        {'word': 'Giraffe', 'category': 'Animals', 'difficulty': 1},
        {'word': 'Penguin', 'category': 'Animals', 'difficulty': 1},
        {'word': 'Dolphin', 'category': 'Animals', 'difficulty': 2},
        {'word': 'Eagle', 'category': 'Birds', 'difficulty': 2},
        {'word': 'Shark', 'category': 'Sea Animals', 'difficulty': 2},
        {'word': 'Butterfly', 'category': 'Insects', 'difficulty': 1},
        {'word': 'Tiger', 'category': 'Animals', 'difficulty': 1},
        {'word': 'Monkey', 'category': 'Animals', 'difficulty': 1},
      ],
      'color': 0xFFFF9800, // Orange
      'iconName': 'trending_up',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 3))),
      'title': 'Throwback Thursday',
      'description': 'Nostalgic items from the past!',
      'cards': [
        {'word': 'Disco', 'category': '70s', 'difficulty': 2},
        {'word': 'Walkman', 'category': '80s', 'difficulty': 2},
        {'word': 'Game Boy', 'category': '90s', 'difficulty': 2},
        {'word': 'VHS', 'category': 'Technology', 'difficulty': 3},
        {'word': 'Polaroid', 'category': 'Photography', 'difficulty': 2},
        {'word': 'Vinyl Records', 'category': 'Music', 'difficulty': 2},
        {'word': 'Typewriter', 'category': 'Technology', 'difficulty': 3},
        {'word': 'Cassette Tape', 'category': 'Music', 'difficulty': 2},
        {'word': 'Flip Phone', 'category': '2000s', 'difficulty': 1},
        {'word': 'MySpace', 'category': 'Internet', 'difficulty': 2},
      ],
      'color': 0xFF9C27B0, // Purple
      'iconName': 'celebration',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 4))),
      'title': 'Fun Friday',
      'description': 'End the week with these entertaining challenges!',
      'cards': [
        {'word': 'Dancing', 'category': 'Activities', 'difficulty': 1},
        {'word': 'Singing', 'category': 'Activities', 'difficulty': 1},
        {'word': 'Swimming', 'category': 'Sports', 'difficulty': 1},
        {'word': 'Basketball', 'category': 'Sports', 'difficulty': 1},
        {'word': 'Soccer', 'category': 'Sports', 'difficulty': 1},
        {'word': 'Tennis', 'category': 'Sports', 'difficulty': 2},
        {'word': 'Golf', 'category': 'Sports', 'difficulty': 2},
        {'word': 'Bowling', 'category': 'Activities', 'difficulty': 1},
        {'word': 'Karaoke', 'category': 'Activities', 'difficulty': 1},
        {'word': 'Video Games', 'category': 'Entertainment', 'difficulty': 1},
      ],
      'color': 0xFFE91E63, // Pink
      'iconName': 'today',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 5))),
      'title': 'Super Saturday',
      'description': 'Weekend vibes with these super challenges!',
      'cards': [
        {'word': 'Beach', 'category': 'Places', 'difficulty': 1},
        {'word': 'Mountain', 'category': 'Places', 'difficulty': 1},
        {'word': 'Paris', 'category': 'Cities', 'difficulty': 1},
        {'word': 'New York', 'category': 'Cities', 'difficulty': 1},
        {'word': 'Tokyo', 'category': 'Cities', 'difficulty': 2},
        {'word': 'London', 'category': 'Cities', 'difficulty': 1},
        {'word': 'Airplane', 'category': 'Travel', 'difficulty': 1},
        {'word': 'Cruise Ship', 'category': 'Travel', 'difficulty': 2},
        {'word': 'Hotel', 'category': 'Travel', 'difficulty': 1},
        {'word': 'Vacation', 'category': 'Activities', 'difficulty': 1},
      ],
      'color': 0xFF00BCD4, // Cyan
      'iconName': 'star',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
    {
      'date': Timestamp.fromDate(today.add(Duration(days: 6))),
      'title': 'Silly Sunday',
      'description': 'Hilarious and silly words to end the weekend!',
      'cards': [
        {'word': 'Banana', 'category': 'Funny', 'difficulty': 1},
        {'word': 'Unicorn', 'category': 'Fantasy', 'difficulty': 1},
        {'word': 'Ninja', 'category': 'Characters', 'difficulty': 1},
        {'word': 'Pirate', 'category': 'Characters', 'difficulty': 1},
        {'word': 'Robot', 'category': 'Technology', 'difficulty': 1},
        {'word': 'Alien', 'category': 'Sci-Fi', 'difficulty': 1},
        {'word': 'Zombie', 'category': 'Horror', 'difficulty': 2},
        {'word': 'Dragon', 'category': 'Fantasy', 'difficulty': 1},
        {'word': 'Wizard', 'category': 'Fantasy', 'difficulty': 1},
        {'word': 'Clown', 'category': 'Characters', 'difficulty': 1},
      ],
      'color': 0xFFFFEB3B, // Yellow
      'iconName': 'celebration',
      'isActive': true,
      'createdAt': Timestamp.now(),
    },
  ];

  // Add each daily deck to Firestore
  for (var deck in dailyDecks) {
    try {
      final docRef = await firestore.collection('daily_decks').add(deck);
      print('✅ Added daily deck: ${deck['title']} with ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error adding daily deck ${deck['title']}: $e');
    }
  }

  print('\n🎉 Successfully populated Daily Heads Up data!');
  print('📱 Open your app to see today\'s challenge!');
}
