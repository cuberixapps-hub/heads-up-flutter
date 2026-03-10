import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://ybrtwonwgvangibcvrpx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlicnR3b253Z3ZhbmdpYmN2cnB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3NTU0MzEsImV4cCI6MjA4NDMzMTQzMX0.MYTzmqBXoLgq3kmpEii7d8R81-328NfK-1lSDnSg_F8';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Fixed UUIDs for idempotent upserts
const DECK_IDS = {
  EMOTIONS_FEELINGS: '10000000-0000-4000-a000-000000000001',
  CELEBRITIES:       '10000000-0000-4000-a000-000000000002',
  TASTY_FOOD:        '10000000-0000-4000-a000-000000000003',
  ANIMALS:           '10000000-0000-4000-a000-000000000004',
  MIX:               '10000000-0000-4000-a000-000000000005',
  JUST_FOR_KIDS:     '10000000-0000-4000-a000-000000000006',
  COUNTRIES:         '10000000-0000-4000-a000-000000000007',
  CARS:              '10000000-0000-4000-a000-000000000008',
  MUSIC_INSTRUMENTS: '10000000-0000-4000-a000-000000000009',
  HISTORICAL_FIGURES:'10000000-0000-4000-a000-000000000010',
};

// FontAwesome 6 solid icon code points
const FA_ICONS = {
  faceSmile:    0xf118,
  star:         0xf005,
  utensils:     0xf2e7,
  paw:          0xf1b0,
  shuffle:      0xf074,
  child:        0xe59d,
  globe:        0xf0ac,
  car:          0xf1b9,
  music:        0xf001,
  landmark:     0xf66f,
};

const initialDecks = [
  {
    id: DECK_IDS.EMOTIONS_FEELINGS,
    name: 'Emotions & Feelings',
    description: 'Express and guess different emotions and feelings!',
    cards: [
      'Happy', 'Sad', 'Angry', 'Excited', 'Nervous', 'Jealous', 'Confused',
      'Proud', 'Embarrassed', 'Grateful', 'Surprised', 'Disgusted', 'Anxious',
      'Bored', 'Hopeful', 'Lonely', 'Shy', 'Frustrated', 'Content', 'Fearful',
      'Overwhelmed', 'Relieved', 'Curious', 'Nostalgic', 'Guilty', 'Amused',
      'Determined', 'Peaceful', 'Grumpy', 'Cheerful', 'Terrified', 'Gloomy',
      'Ecstatic', 'Furious', 'Heartbroken', 'Amazed', 'Worried', 'Stubborn',
      'Thoughtful', 'Impatient', 'Moody', 'Playful', 'Sarcastic', 'Dramatic',
      'Courageous',
    ],
    icon_code_point: FA_ICONS.faceSmile,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFFE91E63,
    color_name: 'Pink',
    color_hex: '#E91E63',
    priority: 1,
    tags: ['initial', 'emotions', 'feelings', 'family'],
  },
  {
    id: DECK_IDS.CELEBRITIES,
    name: 'Celebrities',
    description: 'Famous people from movies, music, sports and more!',
    cards: [
      'Taylor Swift', 'Cristiano Ronaldo', 'Beyonce', 'Tom Hanks', 'Elon Musk',
      'Rihanna', 'Lionel Messi', 'Oprah Winfrey', 'Dwayne Johnson', 'Adele',
      'Leonardo DiCaprio', 'Kim Kardashian', 'Drake', 'Selena Gomez',
      'Ariana Grande', 'Brad Pitt', 'Lady Gaga', 'Justin Bieber',
      'Scarlett Johansson', 'Will Smith', 'Ed Sheeran', 'Jennifer Lopez',
      'Chris Hemsworth', 'Emma Watson', 'Robert Downey Jr.', 'Billie Eilish',
      'Tom Cruise', 'Shakira', 'LeBron James', 'Katy Perry', 'Bruno Mars',
      'Zendaya', 'Post Malone', 'Margot Robbie', 'Bad Bunny', 'Cardi B',
      'Ryan Reynolds', 'Angelina Jolie', 'Travis Kelce', 'Miley Cyrus',
      'Morgan Freeman', 'Keanu Reeves', 'Gal Gadot', 'Nicki Minaj',
      'The Weeknd',
    ],
    icon_code_point: FA_ICONS.star,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFFFFD93D,
    color_name: 'Gold',
    color_hex: '#FFD93D',
    priority: 2,
    tags: ['initial', 'celebrities', 'famous', 'pop culture'],
  },
  {
    id: DECK_IDS.TASTY_FOOD,
    name: 'Tasty Food',
    description: 'Delicious foods and dishes from around the world!',
    cards: [
      'Pizza', 'Sushi', 'Tacos', 'Pasta', 'Burger', 'Ice Cream', 'Pancakes',
      'Fried Chicken', 'Chocolate Cake', 'French Fries', 'Hot Dog', 'Steak',
      'Dumplings', 'Nachos', 'Waffles', 'Ramen', 'Sandwich', 'Donut',
      'Popcorn', 'Lasagna', 'Cupcake', 'Burrito', 'Cheesecake', 'Fried Rice',
      'Fish and Chips', 'Croissant', 'Milkshake', 'Mac and Cheese',
      'Spring Rolls', 'Brownies', 'Pad Thai', 'Kebab', 'Churros',
      'Chicken Wings', 'Cinnamon Roll', 'Onion Rings', 'Garlic Bread',
      'Mashed Potatoes', 'Corn Dog', 'Banana Split', 'BBQ Ribs',
      'Grilled Cheese', 'Mozzarella Sticks', 'Cotton Candy', 'Apple Pie',
    ],
    icon_code_point: FA_ICONS.utensils,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFFFF9800,
    color_name: 'Orange',
    color_hex: '#FF9800',
    priority: 3,
    tags: ['initial', 'food', 'cooking', 'delicious'],
  },
  {
    id: DECK_IDS.ANIMALS,
    name: 'Animals',
    description: 'Wild, domestic and exotic animals from everywhere!',
    cards: [
      'Lion', 'Elephant', 'Penguin', 'Dolphin', 'Eagle', 'Octopus',
      'Kangaroo', 'Chameleon', 'Giraffe', 'Tiger', 'Monkey', 'Shark',
      'Butterfly', 'Panda', 'Parrot', 'Koala', 'Crocodile', 'Flamingo',
      'Wolf', 'Hippopotamus', 'Cheetah', 'Polar Bear', 'Jellyfish',
      'Rhinoceros', 'Hummingbird', 'Gorilla', 'Seahorse', 'Sloth',
      'Peacock', 'Lobster', 'Bat', 'Owl', 'Tortoise', 'Zebra', 'Whale',
      'Fox', 'Hedgehog', 'Rattlesnake', 'Toucan', 'Moose', 'Camel',
      'Squirrel', 'Stingray', 'Pelican', 'Armadillo',
    ],
    icon_code_point: FA_ICONS.paw,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF4CAF50,
    color_name: 'Green',
    color_hex: '#4CAF50',
    priority: 4,
    tags: ['initial', 'animals', 'nature', 'wildlife'],
  },
  {
    id: DECK_IDS.MIX,
    name: 'Mix',
    description: 'A fun mix of random things, actions and ideas!',
    cards: [
      'Umbrella', 'Skyscraper', 'Yoga', 'Volcano', 'Astronaut',
      'Roller Coaster', 'Selfie', 'Trampoline', 'Telescope', 'Pirate',
      'Snowboarding', 'Magician', 'Skateboard', 'Lighthouse', 'Karate',
      'Robot', 'Bungee Jumping', 'Campfire', 'Parachute', 'Ninja',
      'Surfing', 'Disco Ball', 'Hot Air Balloon', 'Snowman', 'Juggling',
      'Scuba Diving', 'Treehouse', 'Fireworks', 'Hammock', 'Limousine',
      'Zipline', 'Sombrero', 'Viking', 'Waterfall', 'Bowling',
      'Carnival', 'Submarine', 'Trampoline', 'Windmill', 'Catapult',
      'Mariachi', 'Gondola', 'Safari', 'Gymnastics', 'Boomerang',
    ],
    icon_code_point: FA_ICONS.shuffle,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF3F51B5,
    color_name: 'Indigo',
    color_hex: '#3F51B5',
    priority: 5,
    tags: ['initial', 'mix', 'random', 'variety'],
  },
  {
    id: DECK_IDS.JUST_FOR_KIDS,
    name: 'Just For Kids',
    description: 'Simple and fun words perfect for young players!',
    cards: [
      'Balloon', 'Rainbow', 'Dinosaur', 'Ice Cream', 'Puppy', 'Butterfly',
      'Robot', 'Princess', 'Dragon', 'Pirate', 'Unicorn', 'Superman',
      'Mermaid', 'Rocket', 'Teddy Bear', 'Clown', 'Fairy', 'Monster',
      'Cowboy', 'Snowman', 'Monkey', 'Castle', 'Train', 'Spider',
      'Astronaut', 'Wizard', 'Pumpkin', 'Elephant', 'Airplane', 'Lion',
      'Cookie', 'Dolphin', 'Penguin', 'Superhero', 'Ghost', 'Ninja',
      'Kangaroo', 'Banana', 'Fireman', 'Rainbow', 'Giraffe', 'Cupcake',
      'Chicken', 'Kitten', 'Treasure',
    ],
    icon_code_point: FA_ICONS.child,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF8BC34A,
    color_name: 'Light Green',
    color_hex: '#8BC34A',
    priority: 6,
    tags: ['initial', 'kids', 'children', 'family', 'easy'],
  },
  {
    id: DECK_IDS.COUNTRIES,
    name: 'Countries',
    description: 'Guess countries from all around the globe!',
    cards: [
      'United States', 'Japan', 'Brazil', 'Australia', 'Egypt', 'India',
      'France', 'Canada', 'Mexico', 'Italy', 'Germany', 'China',
      'South Korea', 'Spain', 'Russia', 'United Kingdom', 'Argentina',
      'South Africa', 'Thailand', 'Turkey', 'Greece', 'Sweden',
      'Switzerland', 'New Zealand', 'Nigeria', 'Colombia', 'Norway',
      'Ireland', 'Portugal', 'Netherlands', 'Poland', 'Philippines',
      'Indonesia', 'Vietnam', 'Chile', 'Peru', 'Morocco', 'Kenya',
      'Cuba', 'Iceland', 'Jamaica', 'Singapore', 'Malaysia', 'Nepal',
      'Croatia',
    ],
    icon_code_point: FA_ICONS.globe,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF2196F3,
    color_name: 'Blue',
    color_hex: '#2196F3',
    priority: 7,
    tags: ['initial', 'countries', 'geography', 'world'],
  },
  {
    id: DECK_IDS.CARS,
    name: 'Cars',
    description: 'Car brands, models and everything automotive!',
    cards: [
      'Ferrari', 'Tesla', 'BMW', 'Toyota', 'Mercedes-Benz', 'Lamborghini',
      'Porsche', 'Audi', 'Ford', 'Chevrolet', 'Honda', 'Rolls-Royce',
      'Bugatti', 'Jeep', 'Volkswagen', 'Nissan', 'Range Rover', 'Maserati',
      'Bentley', 'Jaguar', 'Mini Cooper', 'Dodge', 'Subaru', 'Mazda',
      'Cadillac', 'Hyundai', 'Kia', 'Aston Martin', 'McLaren',
      'Alfa Romeo', 'Lexus', 'Volvo', 'Mustang', 'Corvette', 'Camaro',
      'Land Cruiser', 'Hummer', 'Fiat', 'Suzuki', 'Pagani',
      'Pickup Truck', 'Convertible', 'Monster Truck', 'Go-Kart',
      'Formula 1 Car',
    ],
    icon_code_point: FA_ICONS.car,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF9E9E9E,
    color_name: 'Grey',
    color_hex: '#9E9E9E',
    priority: 8,
    tags: ['initial', 'cars', 'automotive', 'vehicles'],
  },
  {
    id: DECK_IDS.MUSIC_INSTRUMENTS,
    name: 'Music Instruments',
    description: 'Musical instruments from classical to modern!',
    cards: [
      'Guitar', 'Piano', 'Drums', 'Violin', 'Trumpet', 'Flute',
      'Saxophone', 'Harmonica', 'Cello', 'Harp', 'Ukulele', 'Banjo',
      'Accordion', 'Tambourine', 'Xylophone', 'Clarinet', 'Trombone',
      'Bagpipes', 'Bongos', 'Maracas', 'Mandolin', 'Organ', 'Oboe',
      'Bass Guitar', 'Triangle', 'Sitar', 'Didgeridoo', 'Tuba',
      'French Horn', 'Castanets', 'Recorder', 'Keyboard', 'Djembe',
      'Electric Guitar', 'Cymbals', 'Cowbell', 'Piccolo', 'Steel Drum',
      'Synthesizer', 'Kalimba', 'Pan Flute', 'Lyre', 'Conga',
      'Timpani', 'Glockenspiel',
    ],
    icon_code_point: FA_ICONS.music,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFFFF5722,
    color_name: 'Deep Orange',
    color_hex: '#FF5722',
    priority: 9,
    tags: ['initial', 'music', 'instruments', 'orchestra'],
  },
  {
    id: DECK_IDS.HISTORICAL_FIGURES,
    name: 'Historical Figures',
    description: 'Famous people who shaped our world history!',
    cards: [
      'Albert Einstein', 'Cleopatra', 'Napoleon', 'Leonardo da Vinci',
      'Mahatma Gandhi', 'Martin Luther King Jr.', 'Abraham Lincoln',
      'Queen Elizabeth II', 'Winston Churchill', 'Nelson Mandela',
      'Alexander the Great', 'Julius Caesar', 'William Shakespeare',
      'Mozart', 'Beethoven', 'Marie Curie', 'Nikola Tesla',
      'Christopher Columbus', 'George Washington', 'Thomas Edison',
      'Genghis Khan', 'Frida Kahlo', 'Charles Darwin', 'Galileo Galilei',
      'Joan of Arc', 'Marco Polo', 'Aristotle', 'Confucius',
      'Queen Victoria', 'Amelia Earhart', 'Rosa Parks', 'Tutankhamun',
      'Michelangelo', 'Isaac Newton', 'Benjamin Franklin',
      'Pablo Picasso', 'Florence Nightingale', 'Neil Armstrong',
      'Socrates', 'Plato', 'Anne Frank', 'Pocahontas',
      'Harriet Tubman', 'Wright Brothers', 'Mother Teresa',
    ],
    icon_code_point: FA_ICONS.landmark,
    icon_font_family: 'FontAwesomeSolid',
    icon_font_package: 'font_awesome_flutter',
    color_value: 0xFF795548,
    color_name: 'Brown',
    color_hex: '#795548',
    priority: 10,
    tags: ['initial', 'history', 'famous', 'historical'],
  },
];

async function seedInitialDecks() {
  console.log('Starting initial decks seed...\n');

  for (const deck of initialDecks) {
    const row = {
      id: deck.id,
      name: deck.name,
      description: deck.description,
      cards: deck.cards,
      icon_code_point: deck.icon_code_point,
      icon_font_family: deck.icon_font_family,
      icon_font_package: deck.icon_font_package,
      color_value: deck.color_value,
      color_name: deck.color_name,
      color_hex: deck.color_hex,
      image_url: null,
      is_premium: false,
      premium_only: false,
      is_active: true,
      countries: ['UNIVERSAL'],
      country: 'UNIVERSAL',
      tags: deck.tags,
      priority: deck.priority,
      play_count: 0,
      has_difficulty_modes: false,
      cards_by_difficulty: null,
      generated_by_ai: false,
      automated_generation: false,
      research_based: false,
      translations: null,
    };

    const { data, error } = await supabase
      .from('decks')
      .upsert(row, { onConflict: 'id' })
      .select()
      .single();

    if (error) {
      console.error(`  FAILED: ${deck.name} — ${error.message}`);
    } else {
      console.log(`  OK: ${data.name} (${deck.cards.length} cards, priority ${deck.priority})`);
    }
  }

  console.log('\nSeed complete! Verifying...');

  const { data: allDecks, error: fetchError } = await supabase
    .from('decks')
    .select('id, name, cards, priority, is_active')
    .in('id', Object.values(DECK_IDS))
    .order('priority', { ascending: true });

  if (fetchError) {
    console.error('Verification failed:', fetchError.message);
  } else {
    console.log(`\nFound ${allDecks?.length} initial decks in Supabase:`);
    allDecks?.forEach(d => {
      console.log(`  #${d.priority} ${d.name} — ${d.cards.length} cards — active: ${d.is_active}`);
    });
  }
}

seedInitialDecks().catch(console.error);
