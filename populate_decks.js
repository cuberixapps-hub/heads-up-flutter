// Populate Firebase with Country-Specific Decks
// Run this in the browser console while on Firebase Console or use Node.js with firebase-admin

const sampleDecks = [
  // UNIVERSAL DECKS
  {
    name: "Viral TikTok Trends",
    description: "Guess the latest TikTok trends and challenges",
    country: "UNIVERSAL",
    iconCodePoint: 0xf167, // TikTok icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFF000000,
    isPremium: false,
    priority: 1,
    isActive: true,
    tags: ["social", "trending", "viral", "dance"],
    cards: [
      "Renegade Dance",
      "Savage Love",
      "WAP Dance",
      "Silhouette Challenge",
      "Buss It Challenge",
      "Tell Me Without Telling Me",
      "Corn Kid",
      "Wednesday Dance",
      "It's Corn!",
      "Ohio Memes",
      "Girl Dinner",
      "Roman Empire Trend",
      "NPC Streaming",
      "Grimace Shake",
      "Delulu"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Netflix Originals",
    description: "Popular Netflix shows and movies",
    country: "UNIVERSAL",
    iconCodePoint: 0xf008, // Film icon
    iconFontFamily: "FontAwesomeIcons", 
    colorValue: 0xFFE50914,
    isPremium: false,
    priority: 2,
    isActive: true,
    tags: ["movies", "streaming", "entertainment"],
    cards: [
      "Stranger Things",
      "Wednesday",
      "Squid Game",
      "Money Heist",
      "The Crown",
      "Bridgerton",
      "The Witcher",
      "Ozark",
      "Black Mirror",
      "Orange Is the New Black",
      "The Queen's Gambit",
      "Tiger King",
      "Love Is Blind",
      "The Umbrella Academy",
      "Lucifer"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Gaming Icons",
    description: "Popular video game characters and titles",
    country: "UNIVERSAL",
    iconCodePoint: 0xf11b, // Gamepad icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFF9146FF,
    isPremium: false,
    priority: 3,
    isActive: true,
    tags: ["gaming", "esports", "entertainment"],
    cards: [
      "Fortnite",
      "Minecraft",
      "Roblox",
      "Among Us",
      "Call of Duty",
      "Grand Theft Auto",
      "Pokemon",
      "Super Mario",
      "Zelda",
      "FIFA",
      "Apex Legends",
      "Valorant",
      "League of Legends",
      "Overwatch",
      "Fall Guys"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },

  // INDIA DECKS
  {
    name: "Bollywood Superstars",
    description: "Iconic Bollywood actors and actresses",
    country: "IN",
    iconCodePoint: 0xf008, // Film icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFFF9933,
    isPremium: false,
    priority: 1,
    isActive: true,
    tags: ["bollywood", "movies", "india", "entertainment"],
    cards: [
      "Shah Rukh Khan",
      "Salman Khan",
      "Aamir Khan",
      "Amitabh Bachchan",
      "Deepika Padukone",
      "Priyanka Chopra",
      "Alia Bhatt",
      "Ranveer Singh",
      "Ranbir Kapoor",
      "Kareena Kapoor",
      "Katrina Kaif",
      "Akshay Kumar",
      "Hrithik Roshan",
      "Varun Dhawan",
      "Anushka Sharma"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Cricket Legends",
    description: "Famous Indian cricket players",
    country: "IN",
    iconCodePoint: 0xf434, // Baseball icon (closest to cricket)
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFF138808,
    isPremium: false,
    priority: 2,
    isActive: true,
    tags: ["cricket", "sports", "india"],
    cards: [
      "Virat Kohli",
      "MS Dhoni",
      "Sachin Tendulkar",
      "Rohit Sharma",
      "Kapil Dev",
      "Sunil Gavaskar",
      "Rahul Dravid",
      "Sourav Ganguly",
      "Yuvraj Singh",
      "Hardik Pandya",
      "Jasprit Bumrah",
      "Ravindra Jadeja",
      "KL Rahul",
      "Shikhar Dhawan",
      "Rishabh Pant"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Indian Street Food",
    description: "Delicious street food from across India",
    country: "IN",
    iconCodePoint: 0xf2e7, // Utensils icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFFF6347,
    isPremium: false,
    priority: 3,
    isActive: true,
    tags: ["food", "cuisine", "india", "street food"],
    cards: [
      "Pani Puri",
      "Vada Pav",
      "Dosa",
      "Samosa",
      "Chole Bhature",
      "Pav Bhaji",
      "Biryani",
      "Momos",
      "Jalebi",
      "Chaat",
      "Kachori",
      "Aloo Tikki",
      "Bhel Puri",
      "Kulfi",
      "Lassi"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Indian Web Series",
    description: "Popular Indian streaming shows",
    country: "IN",
    iconCodePoint: 0xf26c, // TV icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFF673AB7,
    isPremium: true,
    priority: 4,
    isActive: true,
    tags: ["web series", "streaming", "india", "entertainment"],
    cards: [
      "Mirzapur",
      "Sacred Games",
      "The Family Man",
      "Scam 1992",
      "Panchayat",
      "Kota Factory",
      "Aspirants",
      "Criminal Justice",
      "Made in Heaven",
      "Four More Shots Please",
      "Bandish Bandits",
      "Aarya",
      "Mumbai Diaries",
      "Rocket Boys",
      "The Fame Game"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },

  // USA DECKS
  {
    name: "NFL Stars",
    description: "Famous NFL players",
    country: "US",
    iconCodePoint: 0xf44e, // Football icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFF013369,
    isPremium: false,
    priority: 1,
    isActive: true,
    tags: ["sports", "nfl", "football", "usa"],
    cards: [
      "Tom Brady",
      "Patrick Mahomes",
      "Aaron Rodgers",
      "Lamar Jackson",
      "Travis Kelce",
      "Justin Jefferson",
      "Josh Allen",
      "Dak Prescott",
      "Joe Burrow",
      "Russell Wilson",
      "Jalen Hurts",
      "Nick Bosa",
      "TJ Watt",
      "Micah Parsons",
      "Tyreek Hill"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "American Fast Food",
    description: "Popular fast food chains in America",
    country: "US",
    iconCodePoint: 0xf0f5, // Burger icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFFF0000,
    isPremium: false,
    priority: 2,
    isActive: true,
    tags: ["food", "fast food", "usa", "restaurants"],
    cards: [
      "McDonald's",
      "Burger King",
      "Wendy's",
      "Taco Bell",
      "KFC",
      "Subway",
      "Chick-fil-A",
      "Pizza Hut",
      "Domino's",
      "Chipotle",
      "Five Guys",
      "In-N-Out",
      "Popeyes",
      "Arby's",
      "Sonic"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },

  // JAPAN DECKS
  {
    name: "Anime Characters",
    description: "Famous anime characters",
    country: "JP",
    iconCodePoint: 0xf6d5, // Dragon icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFBC002D,
    isPremium: true,
    priority: 1,
    isActive: true,
    tags: ["anime", "manga", "japan", "entertainment"],
    cards: [
      "Naruto",
      "Goku",
      "Luffy",
      "Light Yagami",
      "Eren Yeager",
      "Sailor Moon",
      "Pikachu",
      "Ichigo",
      "Levi Ackerman",
      "All Might",
      "Saitama",
      "Vegeta",
      "Todoroki",
      "Nezuko",
      "Edward Elric"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    name: "Japanese Food",
    description: "Traditional Japanese cuisine",
    country: "JP",
    iconCodePoint: 0xf2e7, // Utensils icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFE60012,
    isPremium: false,
    priority: 2,
    isActive: true,
    tags: ["food", "cuisine", "japan", "sushi"],
    cards: [
      "Sushi",
      "Ramen",
      "Tempura",
      "Sashimi",
      "Udon",
      "Miso Soup",
      "Tonkatsu",
      "Yakitori",
      "Onigiri",
      "Takoyaki",
      "Okonomiyaki",
      "Matcha",
      "Mochi",
      "Bento",
      "Teriyaki"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },

  // K-POP DECK (Korea)
  {
    name: "K-Pop Groups",
    description: "Popular Korean pop groups",
    country: "KR",
    iconCodePoint: 0xf001, // Music icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFFF0099,
    isPremium: true,
    priority: 1,
    isActive: true,
    tags: ["kpop", "music", "korea", "entertainment"],
    cards: [
      "BTS",
      "BLACKPINK",
      "Stray Kids",
      "SEVENTEEN",
      "TWICE",
      "NCT",
      "ENHYPEN",
      "ATEEZ",
      "TXT",
      "ITZY",
      "aespa",
      "NewJeans",
      "LE SSERAFIM",
      "IVE",
      "TREASURE"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  },

  // TRENDING 2025
  {
    name: "Trending 2025",
    description: "What's hot in 2025",
    country: "TRENDING",
    iconCodePoint: 0xf06d, // Fire icon
    iconFontFamily: "FontAwesomeIcons",
    colorValue: 0xFFFF6B6B,
    isPremium: false,
    priority: 0, // Highest priority
    isActive: true,
    tags: ["trending", "viral", "2025", "hot"],
    cards: [
      "AI Assistants",
      "Vision Pro",
      "Threads App",
      "ChatGPT",
      "BeReal",
      "Quiet Luxury",
      "Girl Math",
      "Deinfluencing",
      "Digital Detox",
      "Eco Anxiety",
      "Rizz",
      "No Cap",
      "Slay",
      "Bet",
      "Bussin"
    ],
    createdAt: new Date(),
    updatedAt: new Date()
  }
];

// If running in browser console on Firebase
function populateDecksInBrowser() {
  console.log('Copy and paste these decks into your Firebase Console manually:');
  console.log(JSON.stringify(sampleDecks, null, 2));
}

// If using this with firebase-admin in Node.js
async function populateDecksWithAdmin(admin) {
  const db = admin.firestore();
  const batch = db.batch();
  
  sampleDecks.forEach((deck, index) => {
    const docRef = db.collection('decks').doc();
    batch.set(docRef, {
      ...deck,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  await batch.commit();
  console.log(`Successfully added ${sampleDecks.length} decks to Firebase!`);
}

// Export for use in different environments
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { sampleDecks, populateDecksWithAdmin };
} else {
  populateDecksInBrowser();
}
