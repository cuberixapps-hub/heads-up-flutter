// Comprehensive list of topics for automated deck generation
export interface Topic {
  name: string;
  category: string;
  tags: string[];
  isPremium?: boolean;
}

export interface TopicCategory {
  name: string;
  icon: string;
  topics: Topic[];
}

export const TOPIC_CATEGORIES: TopicCategory[] = [
  {
    name: 'Movies & TV',
    icon: '🎬',
    topics: [
      { name: 'Classic Hollywood Movies', category: 'movies', tags: ['movies', 'classic', 'hollywood'] },
      { name: '80s Action Films', category: 'movies', tags: ['movies', '80s', 'action'] },
      { name: '90s Rom-Coms', category: 'movies', tags: ['movies', '90s', 'romance', 'comedy'] },
      { name: 'Marvel Superheroes', category: 'movies', tags: ['movies', 'marvel', 'superheroes'] },
      { name: 'Disney Animated Classics', category: 'movies', tags: ['movies', 'disney', 'animation'] },
      { name: 'Horror Movie Icons', category: 'movies', tags: ['movies', 'horror', 'scary'] },
      { name: 'Famous Movie Directors', category: 'movies', tags: ['movies', 'directors', 'cinema'] },
      { name: 'Netflix Original Series', category: 'movies', tags: ['tv', 'netflix', 'series'] },
      { name: 'Sitcom Characters', category: 'movies', tags: ['tv', 'sitcom', 'comedy'] },
      { name: 'Science Fiction Movies', category: 'movies', tags: ['movies', 'sci-fi', 'space'] },
      { name: 'Award Winning Films', category: 'movies', tags: ['movies', 'oscars', 'awards'] },
      { name: 'Movie Villains', category: 'movies', tags: ['movies', 'villains', 'antagonist'] },
    ]
  },
  {
    name: 'Food & Drink',
    icon: '🍕',
    topics: [
      { name: 'Italian Cuisine', category: 'food', tags: ['food', 'italian', 'cuisine'] },
      { name: 'Street Food Around the World', category: 'food', tags: ['food', 'street', 'global'] },
      { name: 'Desserts and Sweets', category: 'food', tags: ['food', 'desserts', 'sweet'] },
      { name: 'Coffee Drinks', category: 'food', tags: ['drinks', 'coffee', 'beverages'] },
      { name: 'Fast Food Chains', category: 'food', tags: ['food', 'fast-food', 'restaurants'] },
      { name: 'Asian Cuisine', category: 'food', tags: ['food', 'asian', 'cuisine'] },
      { name: 'Mexican Food', category: 'food', tags: ['food', 'mexican', 'cuisine'] },
      { name: 'Breakfast Foods', category: 'food', tags: ['food', 'breakfast', 'morning'] },
      { name: 'Cocktails and Mocktails', category: 'food', tags: ['drinks', 'cocktails', 'beverages'] },
      { name: 'Cheeses of the World', category: 'food', tags: ['food', 'cheese', 'dairy'] },
      { name: 'BBQ and Grilling', category: 'food', tags: ['food', 'bbq', 'grilling'] },
      { name: 'Vegan and Vegetarian', category: 'food', tags: ['food', 'vegan', 'vegetarian'] },
    ]
  },
  {
    name: 'Music',
    icon: '🎵',
    topics: [
      { name: 'Pop Music Stars', category: 'music', tags: ['music', 'pop', 'artists'] },
      { name: 'Rock Legends', category: 'music', tags: ['music', 'rock', 'legends'] },
      { name: 'Hip Hop Artists', category: 'music', tags: ['music', 'hip-hop', 'rap'] },
      { name: 'Country Music Hits', category: 'music', tags: ['music', 'country', 'hits'] },
      { name: 'Classical Composers', category: 'music', tags: ['music', 'classical', 'composers'] },
      { name: '90s Hits', category: 'music', tags: ['music', '90s', 'nostalgia'] },
      { name: 'K-Pop Groups', category: 'music', tags: ['music', 'kpop', 'korean'] },
      { name: 'Jazz Musicians', category: 'music', tags: ['music', 'jazz', 'musicians'] },
      { name: 'EDM DJs', category: 'music', tags: ['music', 'edm', 'electronic'] },
      { name: 'Musical Instruments', category: 'music', tags: ['music', 'instruments', 'band'] },
      { name: 'One-Hit Wonders', category: 'music', tags: ['music', 'hits', 'nostalgia'] },
      { name: 'Music Festivals', category: 'music', tags: ['music', 'festivals', 'events'] },
    ]
  },
  {
    name: 'Animals & Nature',
    icon: '🦁',
    topics: [
      { name: 'Safari Animals', category: 'animals', tags: ['animals', 'safari', 'wildlife'] },
      { name: 'Ocean Creatures', category: 'animals', tags: ['animals', 'ocean', 'marine'] },
      { name: 'Pet Breeds', category: 'animals', tags: ['animals', 'pets', 'breeds'] },
      { name: 'Extinct Animals', category: 'animals', tags: ['animals', 'extinct', 'prehistoric'] },
      { name: 'Birds of the World', category: 'animals', tags: ['animals', 'birds', 'avian'] },
      { name: 'Insects and Bugs', category: 'animals', tags: ['animals', 'insects', 'bugs'] },
      { name: 'Farm Animals', category: 'animals', tags: ['animals', 'farm', 'domestic'] },
      { name: 'Rainforest Wildlife', category: 'animals', tags: ['animals', 'rainforest', 'jungle'] },
      { name: 'Arctic Animals', category: 'animals', tags: ['animals', 'arctic', 'polar'] },
      { name: 'Flowers and Plants', category: 'animals', tags: ['nature', 'flowers', 'plants'] },
      { name: 'Natural Wonders', category: 'animals', tags: ['nature', 'wonders', 'geography'] },
      { name: 'Weather Phenomena', category: 'animals', tags: ['nature', 'weather', 'science'] },
    ]
  },
  {
    name: 'Sports & Fitness',
    icon: '⚽',
    topics: [
      { name: 'Soccer Legends', category: 'sports', tags: ['sports', 'soccer', 'football'] },
      { name: 'NBA Basketball Stars', category: 'sports', tags: ['sports', 'basketball', 'nba'] },
      { name: 'Olympic Sports', category: 'sports', tags: ['sports', 'olympics', 'athletics'] },
      { name: 'NFL Teams', category: 'sports', tags: ['sports', 'football', 'nfl'] },
      { name: 'Tennis Champions', category: 'sports', tags: ['sports', 'tennis', 'champions'] },
      { name: 'Cricket Heroes', category: 'sports', tags: ['sports', 'cricket', 'legends'] },
      { name: 'Winter Sports', category: 'sports', tags: ['sports', 'winter', 'snow'] },
      { name: 'Extreme Sports', category: 'sports', tags: ['sports', 'extreme', 'adventure'] },
      { name: 'Fitness Exercises', category: 'sports', tags: ['fitness', 'exercise', 'workout'] },
      { name: 'Yoga Poses', category: 'sports', tags: ['fitness', 'yoga', 'wellness'] },
      { name: 'Combat Sports', category: 'sports', tags: ['sports', 'martial-arts', 'combat'] },
      { name: 'Motorsports', category: 'sports', tags: ['sports', 'racing', 'motorsports'] },
    ]
  },
  {
    name: 'Travel & Places',
    icon: '✈️',
    topics: [
      { name: 'World Capitals', category: 'travel', tags: ['travel', 'capitals', 'geography'] },
      { name: 'Famous Landmarks', category: 'travel', tags: ['travel', 'landmarks', 'monuments'] },
      { name: 'Beach Destinations', category: 'travel', tags: ['travel', 'beaches', 'vacation'] },
      { name: 'European Cities', category: 'travel', tags: ['travel', 'europe', 'cities'] },
      { name: 'Asian Adventures', category: 'travel', tags: ['travel', 'asia', 'adventure'] },
      { name: 'US National Parks', category: 'travel', tags: ['travel', 'usa', 'nature'] },
      { name: 'World Heritage Sites', category: 'travel', tags: ['travel', 'unesco', 'heritage'] },
      { name: 'Island Paradises', category: 'travel', tags: ['travel', 'islands', 'paradise'] },
      { name: 'Mountain Ranges', category: 'travel', tags: ['travel', 'mountains', 'geography'] },
      { name: 'Historic Castles', category: 'travel', tags: ['travel', 'castles', 'history'] },
      { name: 'Airports of the World', category: 'travel', tags: ['travel', 'airports', 'aviation'] },
      { name: 'Cruise Destinations', category: 'travel', tags: ['travel', 'cruise', 'ocean'] },
    ]
  },
  {
    name: 'Science & Technology',
    icon: '🔬',
    topics: [
      { name: 'Tech Companies', category: 'tech', tags: ['technology', 'companies', 'business'] },
      { name: 'Programming Languages', category: 'tech', tags: ['technology', 'programming', 'coding'] },
      { name: 'Space Exploration', category: 'tech', tags: ['science', 'space', 'astronomy'] },
      { name: 'Famous Scientists', category: 'tech', tags: ['science', 'scientists', 'history'] },
      { name: 'Elements of the Periodic Table', category: 'tech', tags: ['science', 'chemistry', 'elements'] },
      { name: 'Medical Terms', category: 'tech', tags: ['science', 'medical', 'health'] },
      { name: 'Social Media Platforms', category: 'tech', tags: ['technology', 'social-media', 'apps'] },
      { name: 'Video Game Consoles', category: 'tech', tags: ['technology', 'gaming', 'consoles'] },
      { name: 'Robot and AI', category: 'tech', tags: ['technology', 'ai', 'robotics'] },
      { name: 'Inventions that Changed the World', category: 'tech', tags: ['technology', 'inventions', 'history'] },
      { name: 'Dinosaurs', category: 'tech', tags: ['science', 'dinosaurs', 'paleontology'] },
      { name: 'Human Body Parts', category: 'tech', tags: ['science', 'anatomy', 'biology'] },
    ]
  },
  {
    name: 'Arts & Culture',
    icon: '🎨',
    topics: [
      { name: 'Famous Painters', category: 'arts', tags: ['art', 'painters', 'artists'] },
      { name: 'Art Movements', category: 'arts', tags: ['art', 'movements', 'history'] },
      { name: 'World Literature', category: 'arts', tags: ['literature', 'books', 'authors'] },
      { name: 'Broadway Musicals', category: 'arts', tags: ['theater', 'musicals', 'broadway'] },
      { name: 'Famous Sculptures', category: 'arts', tags: ['art', 'sculptures', 'statues'] },
      { name: 'Dance Styles', category: 'arts', tags: ['dance', 'styles', 'performing-arts'] },
      { name: 'Photography Styles', category: 'arts', tags: ['photography', 'art', 'visual'] },
      { name: 'Fashion Designers', category: 'arts', tags: ['fashion', 'designers', 'style'] },
      { name: 'Architecture Styles', category: 'arts', tags: ['architecture', 'buildings', 'design'] },
      { name: 'Comic Book Heroes', category: 'arts', tags: ['comics', 'superheroes', 'characters'] },
      { name: 'Mythology and Legends', category: 'arts', tags: ['mythology', 'legends', 'folklore'] },
      { name: 'Shakespeare Plays', category: 'arts', tags: ['theater', 'shakespeare', 'literature'] },
    ]
  },
  {
    name: 'Celebrities & Pop Culture',
    icon: '⭐',
    topics: [
      { name: 'Hollywood A-Listers', category: 'celebrities', tags: ['celebrities', 'hollywood', 'actors'] },
      { name: 'Social Media Influencers', category: 'celebrities', tags: ['celebrities', 'influencers', 'social-media'] },
      { name: 'Reality TV Stars', category: 'celebrities', tags: ['celebrities', 'reality-tv', 'entertainment'] },
      { name: 'Late Night Hosts', category: 'celebrities', tags: ['celebrities', 'tv', 'comedy'] },
      { name: 'Fashion Icons', category: 'celebrities', tags: ['celebrities', 'fashion', 'style'] },
      { name: 'YouTube Creators', category: 'celebrities', tags: ['celebrities', 'youtube', 'content'] },
      { name: 'Stand-Up Comedians', category: 'celebrities', tags: ['celebrities', 'comedy', 'entertainment'] },
      { name: 'Talk Show Legends', category: 'celebrities', tags: ['celebrities', 'tv', 'talk-shows'] },
      { name: 'Celebrity Chefs', category: 'celebrities', tags: ['celebrities', 'chefs', 'food'] },
      { name: 'Sports Personalities', category: 'celebrities', tags: ['celebrities', 'sports', 'athletes'] },
      { name: 'TikTok Stars', category: 'celebrities', tags: ['celebrities', 'tiktok', 'social-media'] },
      { name: 'Award Show Moments', category: 'celebrities', tags: ['celebrities', 'awards', 'entertainment'] },
    ]
  },
  {
    name: 'Games & Hobbies',
    icon: '🎮',
    topics: [
      { name: 'Classic Board Games', category: 'games', tags: ['games', 'board-games', 'classic'] },
      { name: 'Video Game Franchises', category: 'games', tags: ['games', 'video-games', 'gaming'] },
      { name: 'Card Games', category: 'games', tags: ['games', 'cards', 'playing'] },
      { name: 'Puzzle Types', category: 'games', tags: ['games', 'puzzles', 'brain-teasers'] },
      { name: 'Casino Games', category: 'games', tags: ['games', 'casino', 'gambling'] },
      { name: 'Video Game Characters', category: 'games', tags: ['games', 'characters', 'gaming'] },
      { name: 'Popular Toys', category: 'games', tags: ['toys', 'games', 'play'] },
      { name: 'Craft Hobbies', category: 'games', tags: ['hobbies', 'crafts', 'diy'] },
      { name: 'Collecting Hobbies', category: 'games', tags: ['hobbies', 'collecting', 'collectors'] },
      { name: 'Outdoor Activities', category: 'games', tags: ['hobbies', 'outdoor', 'activities'] },
      { name: 'Magic and Illusions', category: 'games', tags: ['magic', 'illusions', 'entertainment'] },
      { name: 'Party Games', category: 'games', tags: ['games', 'party', 'social'] },
    ]
  },
  {
    name: 'History & Events',
    icon: '📚',
    topics: [
      { name: 'World Leaders', category: 'history', tags: ['history', 'leaders', 'politics'] },
      { name: 'Historical Battles', category: 'history', tags: ['history', 'battles', 'war'] },
      { name: 'Ancient Civilizations', category: 'history', tags: ['history', 'ancient', 'civilizations'] },
      { name: 'US Presidents', category: 'history', tags: ['history', 'presidents', 'usa'] },
      { name: 'British Royalty', category: 'history', tags: ['history', 'royalty', 'uk'] },
      { name: 'World Wars', category: 'history', tags: ['history', 'war', 'world-wars'] },
      { name: 'Historical Figures', category: 'history', tags: ['history', 'figures', 'people'] },
      { name: 'Revolutionary Movements', category: 'history', tags: ['history', 'revolutions', 'movements'] },
      { name: 'Inventions Timeline', category: 'history', tags: ['history', 'inventions', 'technology'] },
      { name: 'Medieval Times', category: 'history', tags: ['history', 'medieval', 'middle-ages'] },
      { name: 'Cold War Era', category: 'history', tags: ['history', 'cold-war', '20th-century'] },
      { name: 'Historical Documents', category: 'history', tags: ['history', 'documents', 'important'] },
    ]
  },
  {
    name: 'Kids & Family',
    icon: '👨‍👩‍👧‍👦',
    topics: [
      { name: 'Cartoon Characters', category: 'kids', tags: ['kids', 'cartoons', 'characters'] },
      { name: 'Fairy Tales', category: 'kids', tags: ['kids', 'fairy-tales', 'stories'] },
      { name: 'Zoo Animals', category: 'kids', tags: ['kids', 'animals', 'zoo'] },
      { name: 'Children\'s Books', category: 'kids', tags: ['kids', 'books', 'reading'] },
      { name: 'Playground Games', category: 'kids', tags: ['kids', 'games', 'playground'] },
      { name: 'Superhero Powers', category: 'kids', tags: ['kids', 'superheroes', 'powers'] },
      { name: 'Ice Cream Flavors', category: 'kids', tags: ['kids', 'food', 'ice-cream'] },
      { name: 'School Subjects', category: 'kids', tags: ['kids', 'school', 'education'] },
      { name: 'Dinosaur Names', category: 'kids', tags: ['kids', 'dinosaurs', 'prehistoric'] },
      { name: 'Toy Brands', category: 'kids', tags: ['kids', 'toys', 'brands'] },
      { name: 'Nursery Rhymes', category: 'kids', tags: ['kids', 'rhymes', 'songs'] },
      { name: 'Birthday Party Themes', category: 'kids', tags: ['kids', 'party', 'birthday'] },
    ]
  },
  {
    name: 'Holidays & Celebrations',
    icon: '🎉',
    topics: [
      { name: 'Christmas Traditions', category: 'holidays', tags: ['holidays', 'christmas', 'traditions'] },
      { name: 'Halloween Costumes', category: 'holidays', tags: ['holidays', 'halloween', 'costumes'] },
      { name: 'Thanksgiving Foods', category: 'holidays', tags: ['holidays', 'thanksgiving', 'food'] },
      { name: 'Wedding Traditions', category: 'holidays', tags: ['celebrations', 'wedding', 'traditions'] },
      { name: 'New Year Celebrations', category: 'holidays', tags: ['holidays', 'new-year', 'celebrations'] },
      { name: 'Valentine\'s Day', category: 'holidays', tags: ['holidays', 'valentines', 'romance'] },
      { name: 'Easter Activities', category: 'holidays', tags: ['holidays', 'easter', 'spring'] },
      { name: 'Cultural Festivals', category: 'holidays', tags: ['holidays', 'festivals', 'culture'] },
      { name: 'Birthday Traditions', category: 'holidays', tags: ['celebrations', 'birthday', 'traditions'] },
      { name: 'Summer Holidays', category: 'holidays', tags: ['holidays', 'summer', 'vacation'] },
      { name: 'Religious Holidays', category: 'holidays', tags: ['holidays', 'religious', 'celebrations'] },
      { name: 'National Days', category: 'holidays', tags: ['holidays', 'national', 'patriotic'] },
    ]
  },
];

// Utility functions
export const getAllTopics = (): Topic[] => {
  return TOPIC_CATEGORIES.flatMap(category => category.topics);
};

export const getRandomTopic = (): Topic => {
  const allTopics = getAllTopics();
  return allTopics[Math.floor(Math.random() * allTopics.length)];
};

export const getTopicsByCategory = (categoryName: string): Topic[] => {
  const category = TOPIC_CATEGORIES.find(cat => cat.name === categoryName);
  return category ? category.topics : [];
};

export const getCategoryNames = (): string[] => {
  return TOPIC_CATEGORIES.map(cat => cat.name);
};

export const getTotalTopicsCount = (): number => {
  return getAllTopics().length;
};

