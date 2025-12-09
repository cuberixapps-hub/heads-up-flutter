import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '../config/firebase';
import { getOpenAIClient, handleAIError, withRetry } from './aiConfig';
import { AIErrorCode } from '../types/ai';

// Default fallback image URL (can be customized)
const DEFAULT_DECK_IMAGE = 'https://via.placeholder.com/1024x1365/9C27B0/ffffff?text=Heads+Up!';

/**
 * Brand-associated color palettes (legally safe - colors without logos)
 * These colors evoke brand recognition without trademark infringement
 */
const BRAND_COLOR_PALETTES: Record<string, string[]> = {
  // Streaming Services
  'netflix': ['vibrant red/ink-black', 'crimson red (#E50914) on dark'],
  'streaming': ['red/ink-black', 'deep red on black'],
  'prime': ['electric blue/dark navy', 'cyan blue (#00A8E1) on charcoal'],
  'disney': ['royal blue/starlight white', 'cobalt blue (#113CCF) with gold accents'],
  'hulu': ['neon green/ink-black', 'bright green (#1CE783) on dark'],
  
  // Social Media
  'viral': ['neon pink/teal on dark', 'hot pink (#FE2C55) and cyan (#25F4EE)'],
  'social': ['neon pink/teal on dark', 'magenta/cyan gradient'],
  'instagram': ['pink/orange gradient', 'coral pink (#E4405F) to orange (#F77737)'],
  'snapchat': ['electric yellow/black', 'bright yellow (#FFFC00) on black'],
  'twitter': ['sky blue/dark', 'Twitter blue (#1DA1F2) on charcoal'],
  'youtube': ['vibrant red/dark', 'YouTube red (#FF0000) on dark grey'],
  
  // Gaming
  'gaming': ['purple/electric blue', 'neon purple/cyan gradient'],
  'fortnite': ['purple/electric blue', 'royal purple (#7B3FF2) and cyan (#0F99D4)'],
  'minecraft': ['green/brown/black', 'grass green (#6CAE4C) and earth brown'],
  'roblox': ['red/ink-black', 'bold red (#E03C28) on black'],
  'xbox': ['lime green/black', 'Xbox green (#107C10) on black'],
  'playstation': ['royal blue/black', 'PlayStation blue (#003791) on black'],
  'nintendo': ['red/white', 'Nintendo red (#E60012) and white'],
  
  // Sports
  'nba': ['red/blue/gold', 'NBA red (#C8102E) and blue (#1D428A)'],
  'basketball': ['orange/ink-black/cream', 'basketball orange on dark'],
  'premier': ['purple/cyan/white', 'royal purple (#3D195B) and bright cyan'],
  'soccer': ['green/white/blue', 'pitch green and sky blue'],
  'fifa': ['blue/gold/white', 'royal blue (#326295) and gold'],
  'nfl': ['navy/red/white', 'deep navy (#013369) and red'],
  'cricket': ['green/cream/red', 'cricket green and cream'],
  
  // Tech & AI
  'ai': ['teal/green/white', 'emerald teal (#10A37F) gradient'],
  'tech': ['purple/blue/white', 'tech purple and electric blue'],
  'chatgpt': ['teal/green gradient', 'OpenAI teal (#10A37F) and green (#19C37D)'],
  'apple': ['silver/black/white', 'sleek silver and black'],
  'google': ['blue/red/yellow/green', 'Google primary colors'],
  'tesla': ['red/black/silver', 'Tesla red (#CC0000) on black'],
  'spotify': ['neon green/black', 'Spotify green (#1DB954) on dark'],
  'amazon': ['orange/navy/white', 'Amazon orange (#FF9900) on navy'],
  
  // Food & Lifestyle
  'food': ['red/yellow/cream', 'warm red and golden yellow'],
  'mcdonalds': ['golden yellow/red', 'yellow (#FFC72C) and red (#DA291C)'],
  'starbucks': ['forest green/black', 'Starbucks green (#00704A) on black'],
  'uber': ['green/black', 'Uber green (#06C167) on black'],
  'pizza': ['red/green/cream', 'Italian flag colors'],
  
  // Entertainment & Media
  'marvel': ['red/gold/black', 'Marvel red and gold on black'],
  'comics': ['red/blue/yellow', 'comic book primary colors'],
  'anime': ['pink/violet/sky-blue', 'anime pastel gradient'],
  'k-pop': ['neon pink/purple/blue', 'K-pop candy neon palette'],
  'music': ['purple/pink gradient', 'music festival neon colors'],
  'podcast': ['purple/black/white', 'podcast purple on dark'],
};

/**
 * Detect brand-associated keywords in topic and return appropriate color palette
 * @param topic The deck topic name
 * @returns Color palette string or null
 */
const detectBrandColors = (topic: string): string | null => {
  const topicLower = topic.toLowerCase();
  
  // Check for exact or partial matches
  for (const [keyword, palettes] of Object.entries(BRAND_COLOR_PALETTES)) {
    if (topicLower.includes(keyword)) {
      // Return random palette from options
      return palettes[Math.floor(Math.random() * palettes.length)];
    }
  }
  
  return null;
};

/**
 * Convert base64 string to Blob
 * @param base64 Base64 encoded string
 * @param contentType MIME type of the content
 * @returns Blob object
 */
const base64ToBlob = (base64: string, contentType: string = 'image/png'): Blob => {
  const byteCharacters = atob(base64);
  const byteNumbers = new Array(byteCharacters.length);
  
  for (let i = 0; i < byteCharacters.length; i++) {
    byteNumbers[i] = byteCharacters.charCodeAt(i);
  }
  
  const byteArray = new Uint8Array(byteNumbers);
  return new Blob([byteArray], { type: contentType });
};

/**
 * VISUAL STYLES - Mix of modern and vintage aesthetics
 * Only ~20% should be retro/vintage, rest should be modern and fresh
 */
const VISUAL_STYLES = [
  // MODERN STYLES (80% chance - these should dominate)
  {
    name: 'Clean Modern',
    description: 'clean, modern digital illustration with smooth gradients and vibrant colors',
    texture: 'smooth gradients, clean edges, no texture grain',
    weight: 15
  },
  {
    name: 'Neon Pop',
    description: 'bold neon pop art style with electric colors and dynamic shapes',
    texture: 'glossy finish, sharp contrasts, glowing effects',
    weight: 15
  },
  {
    name: '3D Render',
    description: 'stylized 3D render aesthetic with soft lighting and depth',
    texture: 'smooth surfaces, subtle shadows, professional lighting',
    weight: 12
  },
  {
    name: 'Flat Design',
    description: 'modern flat design with bold colors and geometric shapes',
    texture: 'flat colors, minimal shadows, clean vector style',
    weight: 10
  },
  {
    name: 'Gradient Mesh',
    description: 'beautiful gradient mesh style with flowing colors and modern appeal',
    texture: 'smooth color transitions, contemporary feel, no grain',
    weight: 10
  },
  {
    name: 'Isometric',
    description: 'playful isometric illustration style with depth and dimension',
    texture: 'clean lines, consistent angles, modern gaming aesthetic',
    weight: 8
  },
  {
    name: 'Glassmorphism',
    description: 'trendy glassmorphism style with frosted glass effects and blur',
    texture: 'frosted glass, transparency, soft glows, modern UI aesthetic',
    weight: 5
  },
  {
    name: 'Minimalist',
    description: 'elegant minimalist style with strategic use of negative space',
    texture: 'clean, uncluttered, sophisticated simplicity',
    weight: 5
  },
  
  // VINTAGE/RETRO STYLES (20% chance - occasional variety)
  {
    name: 'Retro Pulp',
    description: 'vintage retro pulp poster style with worn paper aesthetic',
    texture: 'worn paper texture, halftone grain, vintage warmth',
    weight: 8
  },
  {
    name: 'Art Deco',
    description: 'elegant art deco style with geometric patterns and gold accents',
    texture: 'metallic accents, geometric precision, luxurious feel',
    weight: 6
  },
  {
    name: 'Vintage Poster',
    description: 'classic vintage travel poster aesthetic with nostalgic charm',
    texture: 'subtle paper texture, muted vintage colors, classic appeal',
    weight: 6
  },
];

/**
 * Select a random visual style based on weights
 * Modern styles have higher weights and will be selected more often
 */
const selectRandomStyle = (): typeof VISUAL_STYLES[0] => {
  const totalWeight = VISUAL_STYLES.reduce((sum, style) => sum + style.weight, 0);
  let random = Math.random() * totalWeight;
  
  for (const style of VISUAL_STYLES) {
    random -= style.weight;
    if (random <= 0) {
      console.log(`🎨 Selected visual style: ${style.name}`);
      return style;
    }
  }
  
  // Fallback to first modern style
  return VISUAL_STYLES[0];
};

/**
 * Visual drama enhancement libraries for cinematic image generation
 * ENHANCED: Focus on CONCEPTUAL storytelling, not just icons
 */
const VISUAL_EFFECTS = {
  lighting: [
    'dramatic cinematic lighting with deep shadows and bright highlights',
    'soft ambient lighting with gentle gradients',
    'neon glow lighting with contrasting colors',
    'studio lighting with clean, professional look',
    'golden hour warm lighting',
    'cool blue atmospheric lighting',
    'vibrant multi-colored lighting',
    'dramatic spotlight effect',
    'soft diffused daylight',
    'dynamic rim lighting with color contrast'
  ],
  particles: [
    'musical notes transforming into birds taking flight',
    'memories crystallizing into floating photographs',
    'dreams manifesting as ethereal butterflies',
    'emotions visualized as swirling color ribbons',
    'time fragments shattering like glass shards',
    'starlight condensing into liquid gold droplets',
    'thoughts emerging as glowing constellation patterns',
    'energy signatures pulsing in wave patterns',
    'magical runes floating and orbiting',
    'reality fracturing into kaleidoscope fragments'
  ],
  motion: [
    'frozen moment of transformation mid-metamorphosis',
    'parallel dimensions overlapping and phasing',
    'time spiral unwinding dramatically',
    'gravity-defying elements suspended in tableau',
    'echoes of movement creating ghostly trails',
    'explosion of creativity bursting outward',
    'convergence of multiple storylines into one point',
    'wave of change rippling through the scene',
    'portal opening with dimensional distortion',
    'moment of impact captured at peak intensity'
  ],
  atmosphere: [
    'liminal dreamspace between reality and fantasy',
    'nostalgic memory palace with emotional resonance',
    'electric anticipation of a life-changing moment',
    'intimate spotlight on a pivotal scene',
    'epic scale of legendary proportions',
    'mysterious twilight realm of possibilities',
    'euphoric peak moment of pure joy',
    'bittersweet beauty of fleeting fame',
    'raw authentic energy of underground culture',
    'transcendent moment where ordinary becomes extraordinary'
  ]
};

/**
 * CONCEPTUAL THEMES - Transform topics into rich visual metaphors
 * This is the key to making images MEANINGFUL rather than generic
 */
const CONCEPTUAL_APPROACHES = {
  // Transform a topic into deeper visual meaning
  metaphors: [
    'voices becoming visible as ribbons of light and color',
    'fame represented as a crown of light above empty thrones',
    'talent visualized as fire emerging from ordinary objects',
    'dreams taking physical form and floating like lanterns',
    'memories crystallized into precious gem formations',
    'emotions painted across the sky like aurora',
    'legacy shown as footprints turning into stars',
    'passion manifesting as a phoenix rising',
    'creativity flowing like rivers of liquid gold',
    'influence spreading like ripples in cosmic water'
  ],
  
  // Visual storytelling frameworks
  narratives: [
    'the moment just before everything changed forever',
    'a collection of symbols that together tell one story',
    'the intersection where multiple worlds collide',
    'a shrine dedicated to cultural icons without showing them',
    'the energy left behind after lightning strikes',
    'a love letter to an era written in visual symbols',
    'the feeling of a genre captured in abstract form',
    'a museum of moments suspended in amber',
    'the soundtrack of a generation visualized as landscape',
    'a constellation map of cultural touchstones'
  ],
  
  // Artistic interpretations
  styles: [
    'surrealist dreamscape where logic bends beautifully',
    'art deco grandeur with geometric precision',
    'maximalist explosion of meaningful symbols',
    'ethereal watercolor wash effect with defined subjects',
    'bold pop art impact with layered meanings',
    'mystical tarot card composition',
    'vintage travel poster romanticism',
    'cyberpunk neon-noir aesthetic',
    'ancient mythology meets modern iconography',
    'theatrical stage design with dramatic depth'
  ]
};

/**
 * CONCEPTUAL SCENE TEMPLATES - Tell visual stories, don't just show icons
 * Each template creates MEANING and EMOTION, not just objects
 */
const SCENE_TEMPLATES: Record<string, string> = {
  // Music & Entertainment - CONCEPTUAL approaches
  'music': 'a grand concert hall where SOUND HAS BECOME VISIBLE - musical notes transforming into golden birds taking flight, vintage vinyl records floating like celestial bodies, guitar strings stretching into infinity as rays of light, the essence of rhythm visualized as pulsing waves of color cascading through space',
  'singer': 'THE VOICE MADE VISIBLE - a stunning throat/mouth silhouette from which emerges a river of colorful sound ribbons spiraling upward, vintage microphones arranged like sacred relics, sheet music pages fluttering like white doves, the raw emotion of performance captured as bursting light from where a heart would be',
  'concert': 'THE ENERGY OF 10,000 VOICES - a sea of raised hands becoming a field of flowers, stage lights transforming into a constellation map of memories, the bass drop visualized as a tidal wave of neon color, sweat drops crystallizing into diamonds mid-air',
  'band': 'A SYMPHONY OF SOULS - instruments arranged like a shrine with mystical energy connecting them, sound waves colliding and creating aurora patterns, the chemistry between musicians shown as intertwining light threads',
  'dj': 'WHERE BEATS BECOME HEARTBEATS - turntables spinning galaxies, sound waves rippling through reality like water, the dance floor from above showing human energy as thermal patterns of joy',
  
  // Celebrities & Pop Culture
  'celebrity': 'THE WEIGHT OF FAME - a gilded empty throne with a heavy crown floating above it, paparazzi flashes frozen as star fragments, red carpet unfurling into infinity, the silhouette of achievement without the face',
  'influencer': 'DIGITAL STARDOM - massive glowing YouTube play buttons arranged like constellations, ring lights creating divine halos, golden and silver creator award plaques floating majestically, smartphones displaying viral content thumbnails, notification hearts and subscriber counts ascending like fireworks, camera equipment arranged as sacred tools of the new fame, the essence of content creator glory captured in electric digital light',
  'actor': 'A THOUSAND FACES - theatrical masks arranged in a spiral showing the range from tragedy to comedy, spotlight creating a halo, costume pieces floating like memories of characters played',
  'actress': 'THE ART OF TRANSFORMATION - a vanity mirror reflecting multiple personas, makeup brushes as magic wands, the glow of a star being born from ordinary chrysalis',
  
  // Superheroes & Comics
  'superhero': 'THE POWER OF HEROES - iconic superhero symbols floating in cosmic arrangement: shields, hammers, lightning bolts, bat signals, spider webs, all glowing with power. Capes billowing in heroic wind, masks arranged like sacred relics, the city skyline silhouetted below with searchlights piercing the sky. Red, blue, and gold energy radiating from a central heroic emblem.',
  
  // Sports & Competition - COMPREHENSIVE coverage
  'sports': 'THE MOMENT OF GLORY - a magnificent championship trophy levitating with golden energy radiating outward, sweat drops turning to diamonds mid-fall, the grass of a victory field becoming emerald waves, medals orbiting like planets, confetti frozen in time like precious gems',
  'basketball': 'GRAVITY DEFIED - a basketball suspended at the peak of its perfect arc with time frozen, the net rippling like silk, court lines glowing with competitive energy, the essence of "clutch" captured in amber',
  'soccer': 'THE BEAUTIFUL GAME - a soccer ball creating golden ripples in spacetime, goal nets woven from threads of pure light, the pitch from above showing the poetry of player movement as interconnected light trails',
  'football': 'FRIDAY NIGHT FOREVER - stadium lights creating a cathedral of sport, helmet and ball floating in championship formation, turf patterns spiraling into infinity',
  'athlete': 'HUMAN LIMIT TRANSCENDED - gold medals orbiting like planets around an eternal flame, the starting blocks as launchpad to greatness, victory podium glowing with achievement',
  'cricket': 'LEGENDS OF THE GENTLEMAN\'S GAME - a cricket bat and ball floating in cosmic arrangement with stadium lights forming constellations, the perfect cover drive frozen in time, stumps and bails arranged like a shrine, championship trophies orbiting above in golden light',
  
  // Gaming & Technology
  'gaming': 'WORLDS WITHIN WORLDS - game controllers floating amid pixel universes, health bars and power-ups as constellations, the glow of "GAME ON" written in neon destiny',
  'esports': 'DIGITAL GLADIATORS - gaming chairs as thrones of champions, RGB lighting creating aurora patterns, trophy cups filled with pixel gold',
  'tech': 'INNOVATION INCARNATE - circuits forming tree of knowledge patterns, data streams flowing like rivers of light, the smartphone as a modern monolith of power',
  'ai': 'SILICON DREAMS - neural networks visualized as glowing synapses, binary code raining like digital cherry blossoms, the boundary between human and machine shown as a shimmering membrane',
  
  // Film & Media
  'movie': 'SILVER SCREEN MAGIC - film reels unfurling into timelines of emotion, the director\'s clapboard as gateway to other worlds, popcorn suspended mid-pop like fireworks, movie tickets as golden tickets to dreams',
  'cinema': 'TEMPLE OF STORIES - red velvet seats as empty thrones awaiting dreamers, projection light creating visible stories in the beam, the screen as a window to infinite realities',
  'streaming': 'THE AGE OF INFINITE STORIES - play buttons floating like sacred symbols, content thumbnails creating a mosaic of human experience, the glow of "one more episode" at 3am',
  'tv': 'LIVING ROOM MEMORIES - a vintage TV emanating memories as visible light, remote controls as magic wands, the evolution of screens from tube to flat as time travel',
  
  // K-Pop & Anime (Gen Z favorites)
  'kpop': 'STAN CULTURE VISUALIZED - lightsticks creating galaxies of fan devotion, album photocards floating like tarot of destiny, the choreography frozen as geometric art, hearts flooding upward infinitely',
  'anime': 'MANGA COMES ALIVE - speed lines radiating from a dramatic moment, eyes that contain entire universes, the wind of transformation blowing cherry blossoms and power',
  'kdrama': 'SLOW MOTION ROMANCE - two silhouettes almost touching, rain frozen mid-fall catching neon city lights, the first snow of destiny, a bench in autumn holding all the feelings',
  
  // Food & Lifestyle - Enhanced with fast food imagery
  'food': 'FAST FOOD HEAVEN - giant golden fries erupting from a glowing red container, burgers floating with cheese melting in slow motion, milkshakes spiraling, pizza slices with stretchy cheese, tacos and noodles and sushi arranged in a cosmic feast, neon restaurant signs creating a warm glow, the essence of global fast food as celebration',
  'restaurant': 'WHERE MEALS BECOME MEMORIES - neon "OPEN" signs glowing warmly, iconic menu items floating like treasures, the magic of dining captured in nostalgic light',
  'cooking': 'ALCHEMY IN THE KITCHEN - pots and pans as cauldrons of transformation, flames dancing with purpose, the moment of plating as art being born',
  
  // Memes & Internet Culture
  'memes': 'THE MUSEUM OF INTERNET - iconic meme formats arranged like precious art, the "deep fried" effect as artistic statement, screenshots as cultural artifacts floating in digital amber',
  'internet': 'THE COLLECTIVE UNCONSCIOUS ONLINE - cursors leaving trails of creativity, browser tabs as windows to soul, the loading spinner as meditation on waiting',
  'viral': 'THE MOMENT OF IGNITION - a share button creating supernova, engagement metrics soaring like rockets, the retweet as signal boost visualized',
  
  // Travel & Adventure
  'travel': 'WANDERLUST EMBODIED - passport stamps creating constellation maps, luggage tags as tokens of adventure, the departure board showing destinations as dreams',
  'adventure': 'THE CALL TO EXPLORE - a compass pointing to "UNKNOWN", footprints leading to horizon, the map unfolding to reveal possibilities',
  'world': 'GLOBAL VILLAGE - landmarks from every continent floating in harmony, languages swirling together beautifully, humanity connected by threads of light',
  
  // Dating & Relationships
  'dating': 'MODERN ROMANCE - swipe gestures leaving trails of hope, red flags and green flags as literal beautiful banners, the "ick" and the "spark" as visible auras',
  'relationship': 'TWO BECOMING ONE - intertwined hands creating root systems of trust, shared playlists visualized as intertwining melodies, inside jokes floating as private constellations',
  
  // Nostalgia
  'nostalgia': 'MEMORY PALACE - childhood toys arranged like relics, VHS tapes emanating warmth, the past glowing golden through present lens, time capsule opening to release precious moments',
  '90s': 'DECADE OF DREAMS - CD cases, chunky TVs, dial-up sounds visualized, the aesthetic of waiting for images to load, butterfly clips and slap bracelets as sacred objects',
  '2000s': 'Y2K FEVER DREAM - flip phones as communication relics, MSN messenger vibes, the era of low-rise and frosted tips immortalized',
  
  // General/Default - ALWAYS tell a story
  'default': 'A SHRINE TO THE THEME - the essence of the topic visualized as pure emotion and energy, symbolic objects arranged with sacred geometry, the feeling of the topic made tangible through light, color, and metaphor, NOT just objects but the MEANING behind them'
};

const COMPOSITION_RULES = [
  'foreground/background depth with layered elements',
  'dynamic diagonal arrangement creating movement',
  'radial composition with elements emanating from center',
  'golden ratio positioning for visual harmony',
  'rule of thirds focal point placement',
  'circular vignette drawing eye to center',
  'leading lines guiding to main subject',
  'symmetrical balance with central focus',
  'asymmetric tension creating visual interest',
  'Z-pattern flow for eye movement'
];

/**
 * Determine if a topic needs text on the image for clarity
 * Topics with strong visual/color associations = no text needed
 * Generic/ambiguous topics = minimal text helpful
 */
const shouldIncludeText = (topic: string): 'none' | 'minimal' | 'prominent' => {
  const topicLower = topic.toLowerCase();
  
  // Topics with STRONG brand/visual associations - NO text needed
  const strongVisualTopics = [
    'netflix', 'spotify', 'youtube', 'instagram', 'twitter',
    'nba', 'fifa', 'premier league', 'champions league',
    'marvel', 'dc', 'disney', 'pokemon',
    'fortnite', 'minecraft', 'roblox', 'playstation', 'xbox',
    'taylor swift', 'swiftie', 'beyonce', 'drake', 'bts', 'blackpink',
    'christmas', 'halloween', 'valentine',
  ];
  
  // Topics where minimal text adds clarity
  const needsMinimalText = [
    'trivia', 'quiz', 'challenge', 'guess', 'random',
    'facts', 'knowledge', 'brain teaser', 'riddle',
    'quotes', 'sayings', 'phrases', 'idioms',
    'history', 'geography', 'science', 'math',
    'decade', 'era', 'year', 'season',
  ];
  
  // Check for strong visual topics
  if (strongVisualTopics.some(keyword => topicLower.includes(keyword))) {
    return 'none';
  }
  
  // Check for topics needing text
  if (needsMinimalText.some(keyword => topicLower.includes(keyword))) {
    return 'minimal';
  }
  
  // Check if topic is very specific (3+ words, likely descriptive enough)
  const wordCount = topic.trim().split(/\s+/).length;
  if (wordCount >= 3) {
    return 'none'; // Specific topics don't need text
  }
  
  // Default: minimal text for clarity
  return 'minimal';
};

/**
 * Get text styling instructions based on inclusion level
 */
const getTextInstructions = (textLevel: 'none' | 'minimal' | 'prominent', topic: string): string => {
  switch (textLevel) {
    case 'none':
      return 'NO TEXT on image, no titles, no words';
    
    case 'minimal': {
      // Extract 1-2 key words from topic for minimal text
      const words = topic.split(' ').slice(0, 2).join(' ').toUpperCase();
      return `minimal stylized text "${words}" integrated subtly into composition (retro pulp typography, does NOT overpower visuals, small and tasteful)`;
    }
    
    case 'prominent': {
      const fullTitle = topic.toUpperCase();
      return `bold retro pulp headline "${fullTitle}" integrated into design (vintage typography, part of composition, not dominating)`;
    }
    
    default:
      return 'NO TEXT on image';
  }
};

/**
 * Determine if topic involves people/celebrities and can use generic silhouettes
 */
const shouldUseGenericSilhouette = (topic: string): boolean => {
  const topicLower = topic.toLowerCase();
  
  // Topics where generic human silhouettes make sense
  const peopleTopics = [
    'celebrity', 'celebrities', 'actor', 'actress', 'singer', 'musician', 'artist',
    'movie', 'film', 'hollywood', 'bollywood',
    'music', 'concert', 'performance', 'band',
    'sports', 'athlete', 'player', 'champion',
    'dancer', 'choreography'
  ];
  
  return peopleTopics.some(keyword => topicLower.includes(keyword));
};

/**
 * Get safe silhouette instructions for people topics
 */
const getSilhouetteInstructions = (topic: string): string => {
  if (!shouldUseGenericSilhouette(topic)) {
    return 'NO people, NO faces, NO silhouettes';
  }
  
  return `GENERIC HUMAN SILHOUETTES ALLOWED - Use ONLY if following ALL these rules:
  
SAFE SILHOUETTE RULES:
✔ COMPLETELY GENERIC - basic human outline, no recognizable features
✔ NO distinctive poses (no moonwalk, no signature dance moves, no iconic stances)
✔ NO recognizable hairstyles or body shapes
✔ NO accessories that identify specific people (no gloves, hats, distinctive clothing)
✔ NO celebrity-specific postures (no Beyoncé poses, no Cristiano Ronaldo "Siiiu", no BTS choreography)
✔ PURELY SYMBOLIC - abstract representation of "a person" not "THIS person"
✔ FACELESS - solid silhouette with no facial features whatsoever
✔ NEUTRAL STANCE - standing, walking, or generic performance pose
✔ COULD BE ANYONE - if you can't identify who it is, it's safe

EXAMPLES OF SAFE SILHOUETTES:
- Generic person standing with microphone (no distinctive features)
- Multiple crowd silhouettes (anonymous audience)
- Abstract dancer in neutral pose (not specific choreography)
- Faceless figure with generic props (guitar, ball, etc.)

AVOID COMPLETELY:
✘ Any pose associated with specific celebrities
✘ Distinctive clothing/costume shapes
✘ Recognizable body proportions
✘ Signature gestures or movements
✘ Anything that makes people think "that's [specific celebrity]"`;
};

/**
 * Detect scene category from topic - ENHANCED with more categories
 */
const detectSceneCategory = (topic: string): string => {
  const topicLower = topic.toLowerCase();
  
  // Using an array to ensure correct order - JavaScript objects don't guarantee order
  const categoryChecks: Array<[string, string[]]> = [
    // FOOD - Check early to catch "fast food", "street food", etc.
    ['food', ['food', 'foods', 'fast food', 'cuisine', 'dish', 'dishes', 'meal', 'meals', 'recipe', 'cooking', 'eat', 'burger', 'pizza', 'fries', 'snack', 'snacks', 'street food', 'mcdonalds', 'kfc', 'dominos', 'subway', 'starbucks', 'cafe', 'dessert', 'sweets', 'ice cream', 'biryani', 'curry', 'noodles', 'sushi', 'ramen', 'tacos', 'chains']],
    ['restaurant', ['restaurant', 'restaurants', 'dining', 'chef', 'diner', 'eatery']],
    
    // Superheroes/Comics - Check early to catch Marvel/DC/Heroes
    ['superhero', ['superhero', 'superheroes', 'hero', 'heroes', 'marvel', 'dc', 'avengers', 'justice league', 'batman', 'superman', 'spider-man', 'spiderman', 'iron man', 'captain america', 'thor', 'hulk', 'wonder woman', 'aquaman', 'flash', 'x-men', 'villain', 'villains', 'comic', 'comics']],
    
    // Sports categories
    ['cricket', ['cricket', 'ipl', 'wicket', 'batsman', 'bowler', 'sachin', 'dhoni', 'virat', 'csk', 'mi', 'rcb']],
    ['basketball', ['basketball', 'nba', 'hoops', 'dunk', 'court', 'lebron', 'curry']],
    ['soccer', ['soccer', 'football', 'fifa', 'premier league', 'world cup', 'pitch', 'messi', 'ronaldo']],
    ['football', ['nfl', 'american football', 'quarterback', 'touchdown', 'super bowl']],
    ['athlete', ['athlete', 'athletes', 'olympic', 'olympics', 'medal', 'gold medal']],
    ['sports', ['sport', 'sports', 'championship', 'league', 'cup', 'tournament', 'champion', 'champions', 'legend', 'legends', 'player', 'players', 'team', 'teams', 'trophy']],
    
    // Music categories
    ['singer', ['singer', 'vocalist', 'voice', 'voices', 'diva']],
    ['music', ['music', 'song', 'songs', 'artist', 'artists', 'album', 'hits', 'playlist', 'musical']],
    ['concert', ['concert', 'tour', 'live', 'festival', 'performance', 'stage']],
    ['band', ['band', 'bands', 'rock', 'metal', 'punk', 'jazz']],
    ['dj', ['dj', 'edm', 'electronic', 'dance music', 'rave', 'club']],
    
    // Celebrity/Entertainment - YouTubers and social media stars FIRST
    ['influencer', ['influencer', 'influencers', 'youtuber', 'youtubers', 'youtube star', 'youtube stars', 'content creator', 'content creators', 'vlogger', 'vloggers', 'streamer', 'streamers', 'twitch']],
    ['celebrity', ['celebrity', 'celebrities', 'celeb', 'celebs', 'famous', 'fame']],
    ['actor', ['actor', 'actors']],
    ['actress', ['actress', 'actresses']],
    
    // Gaming categories
    ['gaming', ['game', 'games', 'gaming', 'gamer', 'gamers', 'video game', 'console', 'playstation', 'xbox', 'nintendo']],
    ['esports', ['esports', 'competitive gaming', 'pro gamer']],
    
    // Film/Media categories
    ['movie', ['movie', 'movies', 'film', 'films', 'cinema', 'hollywood', 'bollywood']],
    ['streaming', ['netflix', 'streaming', 'series', 'binge', 'hulu', 'disney+', 'hbo']],
    ['tv', ['tv show', 'tv shows', 'television', 'sitcom', 'drama series']],
    
    // Gen Z favorites
    ['kpop', ['kpop', 'k-pop', 'korean pop', 'bts', 'blackpink', 'idol', 'idols', 'stan']],
    ['anime', ['anime', 'manga', 'otaku', 'weeb', 'japanese animation', 'shonen', 'shoujo']],
    ['kdrama', ['kdrama', 'k-drama', 'korean drama', 'k drama']],
    
    // Tech categories - specific terms to avoid false matches
    ['tech', ['tech', 'technology', 'innovation', 'startup', 'digital']],
    ['ai', ['artificial intelligence', 'chatgpt', 'openai', 'machine learning', 'algorithm']],
    
    // Internet/Social categories (YouTube WITHOUT "stars" goes here)
    ['memes', ['meme', 'memes']],
    ['internet', ['internet', 'online', 'social media', 'instagram', 'twitter']],
    ['viral', ['viral', 'trending', 'went viral', 'broke the internet']],
    
    // Travel/World categories
    ['travel', ['travel', 'traveling', 'destination', 'vacation', 'trip']],
    ['world', ['world tour', 'around the world', 'countries of the world']],
    ['adventure', ['adventure', 'explore', 'explorer', 'journey']],
    
    // Relationship/Dating categories
    ['dating', ['dating', 'date', 'relationship', 'crush', 'ick', 'red flag', 'green flag', 'swipe']],
    ['relationship', ['couple', 'couples', 'love', 'romance', 'romantic']],
    
    // Nostalgia categories
    ['nostalgia', ['nostalgia', 'nostalgic', 'throwback', 'remember', 'childhood', 'growing up']],
    ['90s', ['90s', '1990s', 'nineties']],
    ['2000s', ['2000s', '2000\'s', 'y2k', 'early 2000s']],
  ];
  
  // Check categories in order (array maintains order, unlike Object)
  for (const [category, keywords] of categoryChecks) {
    if (keywords.some(keyword => topicLower.includes(keyword))) {
      return category;
    }
  }
  
  return 'default';
};

/**
 * Generate a creative image prompt using ChatGPT with retro pulp poster style
 * ENHANCED: Creates CONCEPTUAL, MEANINGFUL images that tell visual stories
 * No more generic icons - we create EMOTION and NARRATIVE
 * @param topic The deck topic/theme
 * @param targetColor Optional pre-selected color to match the deck's color scheme
 * @returns Promise<string> The generated prompt for DALL-E
 */
const generateImagePrompt = async (topic: string, targetColor?: { hex: string; name: string; promptDescription: string }): Promise<string> => {
  try {
    const openai = getOpenAIClient();
    
    // 🎨 Select a random visual style (mostly modern, occasionally vintage)
    const selectedStyle = selectRandomStyle();
    
    // Use the pre-selected target color if provided, otherwise detect brand colors
    let colorHint: string;
    if (targetColor) {
      // PRIORITY: Use the exact color selected for this deck
      colorHint = `🎨 MANDATORY COLOR SCHEME: Use ${targetColor.promptDescription} as the DOMINANT colors. The image MUST prominently feature ${targetColor.name} (${targetColor.hex}) as the primary color. This is critical for visual consistency with the deck.`;
    } else {
      // Fallback to brand color detection
      const brandColors = detectBrandColors(topic);
      colorHint = brandColors 
        ? `Use this color palette: ${brandColors}` 
        : 'Choose an appropriate 2-3 color palette from the options';
    }
    
    // Detect scene category for contextual templates
    const sceneCategory = detectSceneCategory(topic);
    const sceneTemplate = SCENE_TEMPLATES[sceneCategory] || SCENE_TEMPLATES['default'];
    
    // Determine if text is needed for clarity
    const textLevel = shouldIncludeText(topic);
    const textInstructions = getTextInstructions(textLevel, topic);
    
    // Determine if generic silhouettes are allowed
    const silhouetteInstructions = getSilhouetteInstructions(topic);
    
    // Select random visual enhancements - CONCEPTUAL ones
    const lighting = VISUAL_EFFECTS.lighting[Math.floor(Math.random() * VISUAL_EFFECTS.lighting.length)];
    const particles = VISUAL_EFFECTS.particles[Math.floor(Math.random() * VISUAL_EFFECTS.particles.length)];
    const motion = VISUAL_EFFECTS.motion[Math.floor(Math.random() * VISUAL_EFFECTS.motion.length)];
    const atmosphere = VISUAL_EFFECTS.atmosphere[Math.floor(Math.random() * VISUAL_EFFECTS.atmosphere.length)];
    const composition = COMPOSITION_RULES[Math.floor(Math.random() * COMPOSITION_RULES.length)];
    
    // Select conceptual approaches for richer imagery
    const metaphor = CONCEPTUAL_APPROACHES.metaphors[Math.floor(Math.random() * CONCEPTUAL_APPROACHES.metaphors.length)];
    const narrative = CONCEPTUAL_APPROACHES.narratives[Math.floor(Math.random() * CONCEPTUAL_APPROACHES.narratives.length)];
    const artStyle = CONCEPTUAL_APPROACHES.styles[Math.floor(Math.random() * CONCEPTUAL_APPROACHES.styles.length)];
    
    const systemPrompt = `You are a VISIONARY CONCEPT ARTIST who creates PREMIUM, GALLERY-WORTHY deck cover images.

⚠️ CRITICAL PHILOSOPHY: You DO NOT create generic icon-based images. You CREATE VISUAL POETRY.

🎨 VISUAL STYLE FOR THIS IMAGE: ${selectedStyle.name}
Style Description: ${selectedStyle.description}
Texture/Finish: ${selectedStyle.texture}

${targetColor ? `🚨 MANDATORY COLOR REQUIREMENT 🚨
The image MUST use ${targetColor.name} (${targetColor.hex}) as the PRIMARY/DOMINANT color.
Color Description: ${targetColor.promptDescription}
This is NON-NEGOTIABLE - the deck UI uses this exact color, so the image MUST match.
Include this color in: backgrounds, main elements, lighting, glows, and overall atmosphere.` : ''}

THE PROBLEM WE'RE SOLVING:
❌ BORING: "A microphone with spotlights" for Singers deck
❌ GENERIC: "A trophy with confetti" for Sports deck
❌ BASIC: "A controller with neon" for Gaming deck

THE SOLUTION - CONCEPTUAL STORYTELLING:
✅ FOR SINGERS: "Sound waves becoming visible as golden ribbons spiraling from a microphone, each note transforming into a bird taking flight, the essence of voice made tangible as light"
✅ FOR SPORTS: "The frozen moment where sweat drops become diamonds, a trophy floating at the peak of its victory throw, grass blades bent by the weight of greatness"
✅ FOR GAMING: "Controllers floating in a pixel universe, each button a portal to another world, the loading screen between reality and dreams"

YOUR MISSION: Transform "${topic}" into a CONCEPTUAL MASTERPIECE that captures the SOUL of the topic, not just its objects.

CONCEPTUAL APPROACHES TO USE:
1. METAPHOR: ${metaphor}
2. NARRATIVE: ${narrative}  
3. ART STYLE: ${artStyle}

VISUAL TECHNIQUES:
- LIGHTING: ${lighting}
- PARTICLES: ${particles}
- MOTION: ${motion}
- ATMOSPHERE: ${atmosphere}
- COMPOSITION: ${composition}

SCENE INSPIRATION for "${topic}":
${sceneTemplate}

TEXT INSTRUCTIONS:
${textInstructions}

SILHOUETTE RULES:
${silhouetteInstructions}

⭐ THE PREMIUM IMAGE FORMULA:

1. ASK: "What is the FEELING/ESSENCE of ${topic}?" - capture THAT, not just objects
2. TRANSFORM: Turn ordinary objects into extraordinary visual metaphors
3. STORY: Every image should feel like it's capturing a PIVOTAL MOMENT
4. EMOTION: The viewer should FEEL something - awe, nostalgia, excitement, wonder
5. DEPTH: Multiple layers of meaning - foreground interest, mid-ground story, background atmosphere
6. UNIQUENESS: This should look like NOTHING they've seen before

EXAMPLES OF CONCEPTUAL TRANSFORMATION:

🎤 "Famous Singers" 
NOT: "A microphone on a stage"
YES: "Sound waves becoming visible as golden ribbons spiraling from a chrome microphone, transforming into luminous birds taking flight, notes crystallizing into starlight. The microphone stands on an infinite stage, sheet music pages flutter like butterflies, the air glows with the energy of songs that changed the world."

🏆 "Sports Champions"
NOT: "A trophy with confetti"  
YES: "A championship trophy levitating in golden light, surrounded by suspended sweat droplets turned to liquid gold. Medals orbit like planets around a sun. Time bends around this frozen moment of triumph."

🎮 "Video Games"
NOT: "A controller with neon lights"
YES: "A game controller floating between dimensions, its buttons glowing as portals to different worlds. Pixel art characters emerge like spirits, cartridge memories float like sacred relics."

🎬 "Movies"
NOT: "A film reel and popcorn"
YES: "Film strips unfurling from a projector, each frame a window into emotional worlds. The light beam contains visible stories - adventures, romances floating in luminous streams."

FORMAT REQUIREMENTS:
- Start with: "Illustration for mobile game deck cover, 3:4 vertical poster"
- APPLY THIS STYLE: ${selectedStyle.description} with ${selectedStyle.texture}
- CRITICAL: Absolutely NO TEXT on the image - no words, no letters, no typography
- End with: "no people, no faces" OR appropriate silhouette handling

CRITICAL RULES:
✅ TELL A VISUAL STORY - every image captures a meaningful moment
✅ TRANSFORM OBJECTS INTO METAPHORS - make the ordinary extraordinary  
✅ CREATE EMOTION - the viewer should FEEL something looking at this
✅ NO GENERIC ICONS - everything should have PURPOSE and MEANING
✅ PREMIUM GALLERY QUALITY - this should look like collectible art
✅ NO copyrighted logos, NO trademarks, NO brand marks
✅ APPLY STYLE: ${selectedStyle.name} - ${selectedStyle.texture}
✅ NO FLAGS with crescent moon symbols - other country flags are allowed
✅ FAMILY-FRIENDLY - no violent, adult, or controversial imagery
✅ ARTISTIC STYLE - use symbolic representations, not realistic depictions
✅ NO RELIGIOUS IMAGERY - no gods, deities, religious figures, or sacred religious symbols

Generate ONE prompt that would make someone say "THIS is art, not just a deck cover."`;

    const userPrompt = `Create a CONCEPTUAL MASTERPIECE prompt for: "${topic}"

${targetColor ? `🚨🚨🚨 CRITICAL COLOR REQUIREMENT 🚨🚨🚨
PRIMARY COLOR: ${targetColor.name} (${targetColor.hex})
COLOR DESCRIPTION: ${targetColor.promptDescription}
YOU MUST include "${targetColor.name}" and "${targetColor.hex}" explicitly in your output prompt!
The generated image MUST be dominated by this color scheme.
🚨🚨🚨 END COLOR REQUIREMENT 🚨🚨🚨` : colorHint}

🎨 REQUIRED VISUAL STYLE: ${selectedStyle.name}
- Description: ${selectedStyle.description}
- Texture/Finish: ${selectedStyle.texture}

CONCEPTUAL INSPIRATION:
- Scene Framework: ${sceneTemplate}
- Visual Metaphor: ${metaphor}
- Narrative Approach: ${narrative}
- Art Style: ${artStyle}

VISUAL ELEMENTS:
- Lighting: ${lighting}
- Particles: ${particles}
- Motion: ${motion}
- Atmosphere: ${atmosphere}
- Composition: ${composition}

TEXT: ${textInstructions}
SILHOUETTES: ${silhouetteInstructions}

YOUR TASK:

Think deeply about "${topic}":
1. What is the ESSENCE/SOUL of this topic?
2. What FEELING should the image evoke?
3. What STORY can you tell in a single frozen moment?
4. What METAPHORS can transform ordinary objects into meaning?
5. What would make someone say "I NEED to play this deck"?

CREATE a prompt that:
- Captures the MEANING, not just objects
- Tells a STORY in one image
- Uses VISUAL METAPHORS (things becoming other things, emotions made visible)
- Creates DEPTH (foreground/midground/background storytelling)
- Feels PREMIUM and COLLECTIBLE
- Makes viewers FEEL something

FORMAT:
- Start: "Illustration for mobile game deck cover, 3:4 vertical poster"
- Include conceptual storytelling elements
- APPLY STYLE: ${selectedStyle.name} - ${selectedStyle.texture}
- CRITICAL: Absolutely NO TEXT on the image - no words, letters, or typography
- End with people handling ("no people, no faces" or safe silhouette note)

Output ONLY the final prompt. Make it UNFORGETTABLE.`;

    console.log('Generating cinematic retro pulp image prompt with GPT-5.1 for:', topic);

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-5.1', // Latest flagship model
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.8, // Higher creativity for dramatic visuals
        max_completion_tokens: 500 // Detailed cinematic descriptions
      });
    });

    const generatedPrompt = response.choices[0]?.message?.content?.trim();

    if (!generatedPrompt) {
      // If GPT returns empty, create a simple topic-focused prompt
      console.warn('⚠️ GPT returned empty response, using direct topic prompt');
      return createDirectTopicPrompt(topic, targetColor);
    }

    // VALIDATION: Ensure the generated prompt is relevant to the topic AND color
    const validatedPrompt = validateAndEnhancePrompt(generatedPrompt, topic, targetColor);
    
    console.log('✅ Generated prompt for topic:', topic);
    if (targetColor) {
      console.log(`🎨 Target color: ${targetColor.name} (${targetColor.hex})`);
    }
    console.log('Prompt:', validatedPrompt);
    return validatedPrompt;

  } catch (error) {
    // If API call fails after retries, use a simple direct prompt
    console.error('❌ Error generating prompt with ChatGPT:', error);
    console.warn('⚠️ Using direct topic prompt as last resort');
    return createDirectTopicPrompt(topic);
  }
};

/**
 * Sanitize topic to avoid moderation issues and inappropriate imagery
 * Removes or replaces words that might trigger OpenAI's safety filters
 * Also prevents religious deity imagery
 */
const sanitizeTopic = (topic: string): string => {
  let sanitized = topic;
  
  // Words/phrases that might trigger moderation - replace with safer alternatives
  const replacements: [RegExp, string][] = [
    [/\bsexy\b/gi, 'attractive'],
    [/\bhot\b/gi, 'popular'],
    [/\bkill(ing|er|s)?\b/gi, 'defeat'],
    [/\bdeath\b/gi, 'end'],
    [/\bdead\b/gi, 'gone'],
    [/\bviolent?\b/gi, 'intense'],
    [/\bweapon(s)?\b/gi, 'equipment'],
    [/\bgun(s)?\b/gi, 'tools'],
    [/\bblood(y)?\b/gi, 'red'],
    [/\bnude\b/gi, 'artistic'],
    [/\bnaked\b/gi, 'natural'],
    [/\bdrug(s)?\b/gi, 'substance'],
    [/\balcohol(ic)?\b/gi, 'beverage'],
    [/\bdrunk\b/gi, 'tipsy'],
    [/\bwar\b/gi, 'conflict'],
    [/\bbattle\b/gi, 'competition'],
    [/\bfight(ing|er|s)?\b/gi, 'competition'],
    [/\bhate\b/gi, 'dislike'],
    [/\bterror(ist|ism)?\b/gi, 'action'],
    [/\bexplosion\b/gi, 'burst'],
    [/\bbomb(s|ing)?\b/gi, 'device'],
    // Religious terms - replace with neutral alternatives to avoid deity imagery
    [/\bgod(s|dess|desses)?\b/gi, 'legend'],
    [/\bdeity\b/gi, 'figure'],
    [/\bdeities\b/gi, 'figures'],
    [/\bdivine\b/gi, 'legendary'],
    [/\bholy\b/gi, 'sacred'],
    [/\bmytholog(y|ical)\b/gi, 'ancient'],
  ];
  
  for (const [pattern, replacement] of replacements) {
    sanitized = sanitized.replace(pattern, replacement);
  }
  
  return sanitized;
};

/**
 * Create a simple, direct prompt that focuses ONLY on the topic
 * This is used when GPT fails - it's simple but guarantees relevance
 */
const createDirectTopicPrompt = (topic: string, targetColor?: { hex: string; name: string; promptDescription: string }): string => {
  const safeTopic = sanitizeTopic(topic);
  const selectedStyle = selectRandomStyle();
  
  // Build color instruction if provided
  const colorInstruction = targetColor 
    ? `\n\n🎨 MANDATORY COLOR: The image MUST use ${targetColor.name} (${targetColor.hex}) as the dominant color.
Color scheme: ${targetColor.promptDescription}
Apply this color to: backgrounds, main elements, lighting, glows, and overall atmosphere.`
    : '';
  
  return `Create a beautiful illustration for a mobile game deck cover about "${safeTopic}".
${colorInstruction}

Style: ${selectedStyle.description}
Texture/Finish: ${selectedStyle.texture}
Format: Vertical 3:4 poster, premium quality.

Requirements:
- Represent "${safeTopic}" through symbolic imagery and icons
${targetColor ? `- DOMINANT COLOR: ${targetColor.name} (${targetColor.hex}) - ${targetColor.promptDescription}` : '- Use rich, vibrant colors'}
- No text or words on the image
- No realistic human faces
- No flags with crescent moon symbols
- No gods, deities, religious figures, or sacred religious symbols
- Family-friendly, artistic style
- The theme should be immediately recognizable as "${safeTopic}"`;
};

/**
 * MODERATION-SAFE FALLBACK PROMPTS
 * These are pre-tested prompts that are guaranteed to pass OpenAI's safety filters
 * Used ONLY when moderation blocks the original prompt
 * Mix of modern and vintage styles for variety
 */
const MODERATION_SAFE_PROMPTS = [
  // MODERN STYLES
  // Clean modern gradient
  `Clean modern digital illustration with colorful geometric shapes, stars, and celebration elements floating in space. Smooth gradients in purple, teal, and gold. Contemporary design, glossy finish. No text, no faces. Vertical 3:4 format.`,
  
  // Neon pop style
  `Bold neon pop art illustration with electric colors - hot pink, cyan, and gold. Dynamic shapes with glowing effects. Modern gaming aesthetic with sharp contrasts. No text. Vertical format.`,
  
  // 3D render style
  `Stylized 3D render illustration of floating musical notes, vinyl records, and stars. Soft lighting, smooth surfaces, professional look. Deep purple to blue gradient background. No text, no people. Vertical poster.`,
  
  // Flat design modern
  `Modern flat design illustration with floating dice, playing cards, puzzle pieces, and stars. Bold solid colors - electric blue, coral, mint. Clean vector aesthetic. No text. Vertical format.`,
  
  // Gradient mesh contemporary
  `Beautiful gradient mesh illustration with flowing colors - sunset orange, teal, magenta. Smooth color transitions, contemporary feel. Abstract shapes floating elegantly. No text, no faces. Vertical 3:4.`,
  
  // Glassmorphism modern
  `Trendy glassmorphism illustration with frosted glass cards, colorful balloons, streamers, and sparkles. Soft glows, transparency effects, modern UI aesthetic. No text. Vertical format.`,
  
  // Minimalist elegant
  `Elegant minimalist illustration of floating books, lightbulbs, and question marks. Strategic negative space, clean lines. Blue and gold accents on white. No text, no people. Vertical.`,
  
  // Isometric playful
  `Playful isometric illustration of art supplies - paint brushes, color palettes, paint splashes in rainbow colors. Clean angles, modern gaming style. Vibrant and fun. No text. Vertical format.`,
  
  // VINTAGE STYLES (for occasional variety)
  // Retro poster
  `Vintage retro poster illustration with geometric shapes and stars. Warm golden and purple tones. Art deco style with halftone texture. No text, no faces. Vertical 3:4 format.`,
  
  // Classic aesthetic
  `Classic vintage travel poster style with celebration elements. Muted warm colors, subtle paper texture. Nostalgic charm and elegance. No text. Vertical format.`,
];

/**
 * Get a random moderation-safe prompt
 * These prompts are generic but visually appealing and guaranteed to pass moderation
 */
const getModerationSafeFallback = (): string => {
  const randomIndex = Math.floor(Math.random() * MODERATION_SAFE_PROMPTS.length);
  return MODERATION_SAFE_PROMPTS[randomIndex];
};

/**
 * Validate and enhance the generated prompt to ensure topic relevance AND color matching
 * CRITICAL: This is the last line of defense against mismatched images AND colors
 * ALWAYS prepends a clear topic statement AND color instruction to ensure the image model gets it right
 */
const validateAndEnhancePrompt = (prompt: string, topic: string, targetColor?: { hex: string; name: string; promptDescription: string }): string => {
  // ⚠️ ALWAYS prepend a clear topic statement - don't rely on keyword matching
  // This ensures the image model CANNOT misunderstand what the deck is about
  let enhancedPrompt = prompt;
  
  // 🎨 CRITICAL: Inject color instruction at the START of the prompt
  // This ensures the image model MUST use this color regardless of what GPT generated
  if (targetColor) {
    const colorPrefix = `[DOMINANT COLOR: ${targetColor.name} ${targetColor.hex} - use ${targetColor.promptDescription} throughout the image] `;
    
    // Only add if not already present
    if (!prompt.toLowerCase().includes(targetColor.hex.toLowerCase())) {
      console.log(`🎨 Injecting color "${targetColor.name}" (${targetColor.hex}) into prompt`);
      enhancedPrompt = colorPrefix + enhancedPrompt;
    }
  }
  
  // Check if prompt already contains the topic
  if (!enhancedPrompt.toUpperCase().includes(topic.toUpperCase())) {
    const topicPrefix = `DECK COVER FOR "${topic.toUpperCase()}": `;
    console.log(`⚠️ Injecting topic "${topic}" into prompt for clarity`);
    enhancedPrompt = topicPrefix + enhancedPrompt;
  } else {
    console.log(`✅ Prompt already contains topic "${topic}"`);
  }
  
  return enhancedPrompt;
};
/**
 * Options for image generation (gpt-image-1 model)
 * Based on: https://platform.openai.com/docs/api-reference/images/create
 * Note: gpt-image-1 has different parameter support than DALL-E 3
 */
export interface ImageGenerationOptions {
  /** Image quality: 'low', 'medium', 'high', or 'auto' (gpt-image-1 specific) */
  quality?: 'low' | 'medium' | 'high' | 'auto';
  /** Image size: '1024x1024', '1024x1536', '1536x1024', or 'auto' */
  size?: '1024x1024' | '1024x1536' | '1536x1024' | 'auto';
  /** Number of images to generate (1-10) */
  n?: number;
  /** Target color palette for the image (hex color and description) */
  targetColor?: {
    hex: string;
    name: string;
    promptDescription: string;
  };
}

// Legacy alias for backward compatibility
export type DallE3Options = ImageGenerationOptions;

/**
 * Generate a deck cover image using gpt-image-1 (ChatGPT's image model)
 * @param topic The deck topic/theme
 * @param _stylePreference Optional style modifier (kept for backward compatibility, not used - retro pulp style is always applied)
 * @param options Optional image generation options (includes targetColor for coordinated color scheme)
 * @returns Promise<string> The Firebase Storage URL of the generated image
 */
export const generateDeckImage = async (
  topic: string,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _stylePreference: string = 'retro pulp',
  options?: ImageGenerationOptions
): Promise<string> => {
  try {
    const openai = getOpenAIClient();
    
    // Default options for gpt-image-1
    const defaultOptions: Required<Omit<ImageGenerationOptions, 'targetColor'>> = {
      quality: 'medium',
      size: '1024x1536',
      n: 1,
    };
    
    const finalOptions = { ...defaultOptions, ...options };
    
    // Sanitize the topic first
    const safeTopic = sanitizeTopic(topic);
    
    // Step 1: Generate creative prompt using ChatGPT
    console.log(`🎨 Generating image prompt for: "${safeTopic}"`);
    if (options?.targetColor) {
      console.log(`🎨 Target color for image: ${options.targetColor.name} (${options.targetColor.hex})`);
    }
    let prompt: string;
    try {
      prompt = await generateImagePrompt(safeTopic, options?.targetColor);
    } catch {
      console.warn('⚠️ GPT prompt generation failed, using direct prompt');
      prompt = createDirectTopicPrompt(safeTopic, options?.targetColor);
    }
    
    console.log('=== GPT-IMAGE-1 IMAGE GENERATION PROMPT ===');
    console.log(prompt);
    console.log('=== END OF PROMPT ===');
    
    // Step 2: Try to generate image with progressively safer prompts
    let response;
    let attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      attempts++;
      console.log(`🖼️ Image generation attempt ${attempts}/${maxAttempts}`);
      
      try {
        response = await openai.images.generate({
          model: 'gpt-image-1',
          prompt: prompt,
          n: finalOptions.n,
          size: finalOptions.size,
          quality: finalOptions.quality,
        });
        break; // Success! Exit the loop
        
      } catch (imageError: unknown) {
        const err = imageError as { message?: string; error?: { message?: string } };
        const errorMessage = err?.message || err?.error?.message || String(imageError);
        const isModeration = errorMessage.includes('moderation') || 
                            errorMessage.includes('safety') || 
                            errorMessage.includes('blocked') ||
                            errorMessage.includes('content_policy');
        
        console.error(`❌ Image generation attempt ${attempts} failed:`, errorMessage);
        
        if (isModeration) {
          console.warn(`⚠️ Moderation block detected for topic: "${topic}"`);
          
          if (attempts === 1) {
            // Second attempt: Use the direct topic prompt with sanitized topic and color
            console.log('🔄 Retrying with safer direct prompt...');
            prompt = createDirectTopicPrompt(safeTopic, options?.targetColor);
          } else if (attempts === 2) {
            // Third attempt: Use a PRE-TESTED moderation-safe prompt
            // This is guaranteed to work - it's a generic but beautiful image
            console.log('🔄 Retrying with moderation-safe fallback (generic but beautiful)...');
            prompt = getModerationSafeFallback();
          } else {
            // All attempts failed - this shouldn't happen with safe fallback
            throw new Error(`Image generation blocked by moderation after ${maxAttempts} attempts. Topic: "${topic}"`);
          }
        } else {
          // Non-moderation error - rethrow
          throw imageError;
        }
      }
    }
    
    if (!response) {
      throw new Error('Failed to generate image after all attempts');
    }
    
    // gpt-image-1 always returns base64-encoded images
    const imageData = response.data?.[0];
    
    if (!imageData) {
      throw new Error('No image data returned from OpenAI');
    }
    
    // gpt-image-1 only returns b64_json format
    if (!imageData.b64_json) {
      throw new Error('No base64 image data returned from gpt-image-1');
    }
    
    // Convert base64 to blob
    const base64Data = imageData.b64_json;
    const blob = base64ToBlob(base64Data, 'image/png');
    
    console.log(`🎨 AI generated image received: ${Math.round(blob.size / 1024)}KB PNG`);
    console.log(`🗜️ Compressing before Firebase upload...`);
    
    // COMPRESS THE IMAGE BEFORE UPLOADING TO FIREBASE
    // Convert blob to data URL for image processing
    const dataUrl = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
    
    // Compress to 600x800 WebP at 50% quality
    const compressedBlob = await compressAIGeneratedImage(dataUrl);
    
    console.log(`✅ Compressed to ${Math.round(compressedBlob.size / 1024)}KB WebP`);
    
    // Upload ONLY the compressed image to Firebase
    const timestamp = Date.now();
    const cleanTopic = topic.toLowerCase().replace(/[^a-z0-9]/g, '-').substring(0, 50);
    const filename = `ai-generated/${cleanTopic}_${timestamp}.webp`;
    const storageRef = ref(storage, `deck-images/${filename}`);
    
    console.log(`☁️ Uploading compressed ${Math.round(compressedBlob.size / 1024)}KB image to Firebase...`);
    
    await uploadBytes(storageRef, compressedBlob, {
      contentType: 'image/webp',
      customMetadata: {
        generatedBy: 'gpt-image-1',
        topic: topic,
        generatedAt: new Date().toISOString(),
        format: 'webp',
        targetSize: '~200KB',
        sizeKB: Math.round(compressedBlob.size / 1024).toString(),
      },
    });
    
    const downloadUrl = await getDownloadURL(storageRef);
    
    console.log(`✅ Compressed AI image uploaded to Firebase!`);
    console.log(`   URL: ${downloadUrl}`);
    
    return downloadUrl;
    
  } catch (error: unknown) {
    console.error('Image generation error:', error);
    
    // Handle specific AI errors
    const aiError = handleAIError(error);
    
    // For image generation failures, return default image instead of throwing
    if (aiError.code === AIErrorCode.API_KEY_MISSING || 
        aiError.code === AIErrorCode.RATE_LIMIT) {
      console.warn('Falling back to default image due to:', aiError.message);
      return DEFAULT_DECK_IMAGE;
    }
    
    // Re-throw other errors
    throw aiError;
  }
};

/**
 * Compress AI-generated image from data URL
 * Resizes to max 800px while maintaining aspect ratio, targets ~200KB
 * @param dataUrl The data URL of the image
 * @returns Promise<Blob> The compressed image blob
 */
const compressAIGeneratedImage = async (dataUrl: string): Promise<Blob> => {
  return new Promise((resolve, reject) => {
    const img = new Image();
    
    img.onload = () => {
      const sourceWidth = img.width;
      const sourceHeight = img.height;
      
      console.log(`📐 AI image dimensions: ${sourceWidth}x${sourceHeight}`);
      
      // Resize to max 800px on longest side, maintaining aspect ratio
      const maxDimension = 800;
      let targetWidth = sourceWidth;
      let targetHeight = sourceHeight;
      
      if (sourceWidth > sourceHeight) {
        // Landscape or square
        if (sourceWidth > maxDimension) {
          targetWidth = maxDimension;
          targetHeight = Math.round((sourceHeight / sourceWidth) * maxDimension);
        }
      } else {
        // Portrait
        if (sourceHeight > maxDimension) {
          targetHeight = maxDimension;
          targetWidth = Math.round((sourceWidth / sourceHeight) * maxDimension);
        }
      }
      
      console.log(`📏 Resizing to ${targetWidth}x${targetHeight} (no cropping, maintaining aspect ratio)`);
      
      // Create canvas with target dimensions
      const canvas = document.createElement('canvas');
      canvas.width = targetWidth;
      canvas.height = targetHeight;
      
      const ctx = canvas.getContext('2d', { alpha: false });
      if (!ctx) {
        reject(new Error('Failed to get canvas context'));
        return;
      }
      
      // Enable high quality image smoothing
      ctx.imageSmoothingEnabled = true;
      ctx.imageSmoothingQuality = 'high';
      
      // Draw resized image (no cropping)
      ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
      
      // Convert to WebP blob with quality adjustment to target ~200KB
      const tryCompress = (quality: number) => {
        canvas.toBlob(
          (blob) => {
            if (!blob) {
              reject(new Error('Failed to compress image'));
              return;
            }
            
            const sizeKB = blob.size / 1024;
            
            // If size is over 200KB and we can reduce quality, try again
            if (sizeKB > 200 && quality > 0.6) {
              console.log(`📦 Size ${Math.round(sizeKB)}KB, adjusting quality...`);
              tryCompress(quality - 0.05);
            } else {
              console.log(`✅ Compressed to ${Math.round(sizeKB)}KB at quality ${Math.round(quality * 100)}%`);
              resolve(blob);
            }
          },
          'image/webp',
          quality
        );
      };
      
      // Start with 85% quality to target ~200KB
      tryCompress(0.85);
    };
    
    img.onerror = () => {
      reject(new Error('Failed to load image'));
    };
    
    img.src = dataUrl;
  });
};

/**
 * Generate multiple image variations for a topic
 * @param topic The deck topic
 * @param count Number of variations to generate (max 10)
 * @param options Optional image generation options
 * @returns Promise<string[]> Array of image URLs
 */
export const generateImageVariations = async (
  topic: string,
  count: number = 3,
  options?: ImageGenerationOptions
): Promise<string[]> => {
  const styles = [
    'retro pulp',
    'vintage pulp',
    'retro pulp poster',
    'vintage pulp poster',
    'pulp poster'
  ];
  
  const promises = styles.slice(0, count).map(style => 
    generateDeckImage(topic, style, options).catch(() => DEFAULT_DECK_IMAGE)
  );
  
  return Promise.all(promises);
};

/**
 * Validate if image generation is available
 */
export const isImageGenerationAvailable = (): boolean => {
  try {
    getOpenAIClient();
    return true;
  } catch {
    return false;
  }
};
