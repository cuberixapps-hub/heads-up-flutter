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
  'tiktok': ['neon pink/teal on dark', 'hot pink (#FE2C55) and cyan (#25F4EE)'],
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
 * Visual drama enhancement libraries for cinematic image generation
 */
const VISUAL_EFFECTS = {
  lighting: [
    'dramatic spotlight beams converging',
    'neon glow radiating outward',
    'cinematic rim lighting',
    'golden hour backlight',
    'stadium arena lights creating star pattern',
    'ethereal moonlight glow',
    'lens flare effects',
    'volumetric light rays',
    'holographic shimmer',
    'electric luminescence'
  ],
  particles: [
    'golden confetti explosion',
    'sparkle trails floating',
    'stardust shimmer particles',
    'energy orbs pulsing',
    'light particles dancing',
    'magical sparkler effects',
    'glitter cascade',
    'neon particle streams',
    'cosmic dust swirling',
    'prismatic light fragments'
  ],
  motion: [
    'dynamic motion streaks trailing',
    'frozen mid-air action',
    'slow-motion energy burst',
    'spinning with motion blur',
    'levitating dramatically',
    'explosive movement frozen',
    'velocity trails',
    'kinetic energy radiating',
    'suspended in time',
    'dynamic swoosh effects'
  ],
  atmosphere: [
    'epic victory celebration energy',
    'magical concert atmosphere',
    'electrifying stage presence',
    'glamorous premiere vibe',
    'high-energy action scene',
    'mystical enchanted moment',
    'triumphant championship spirit',
    'dazzling showtime atmosphere',
    'powerful hero moment',
    'breathtaking spectacle'
  ]
};

const SCENE_TEMPLATES: Record<string, string> = {
  // Music & Entertainment
  'music': 'concert stage bathed in spotlight glow with {icon} center stage, arena crowd lights bokeh in background, musical notes swirling like constellation patterns',
  'singer': 'ethereal performance stage with {icon} dramatically lit, microphone stands arranged, floating musical notes forming magical trails',
  'concert': 'sold-out stadium atmosphere with {icon} under crossing spotlight beams, arena lights creating dramatic shadows, electric energy',
  'band': 'vintage music venue stage with {icon} arranged prominently, amplifiers glowing, neon signs reflecting',
  'dj': 'pulsing nightclub scene with {icon} bathed in laser lights, sound waves visualized, electric dance energy',
  
  // Sports & Competition
  'sports': 'championship arena frozen at victory moment with {icon} dramatically illuminated, arena lights creating epic atmosphere, confetti suspended mid-air',
  'basketball': 'professional court under arena lights with {icon} center stage, scoreboard glow, championship banners waving',
  'soccer': 'stadium pitch at golden hour with {icon} prominently featured, goal nets in background, victory celebration energy',
  'football': 'packed stadium atmosphere with {icon} under Friday night lights, field markings visible, championship trophy gleam',
  'athlete': 'olympic podium moment with {icon} bathed in golden spotlight, medal ribbons streaming, triumphant energy',
  
  // Gaming & Technology
  'gaming': 'futuristic digital realm with {icon} glowing with neon energy, pixel particles floating, cyber aesthetic',
  'esports': 'competitive gaming arena with {icon} dramatically spotlit, LED screens glowing, electric tournament atmosphere',
  'tech': 'sleek modern environment with {icon} floating holographically, circuit patterns glowing, innovation energy',
  'ai': 'digital consciousness space with {icon} emanating data streams, neural network patterns, futuristic glow',
  
  // Film & Media
  'movie': 'Hollywood premiere scene with {icon} on red carpet backdrop, paparazzi flash bursts, glamorous atmosphere',
  'cinema': 'grand movie theater with {icon} prominently displayed, velvet curtains, golden art deco lighting',
  'streaming': 'binge-watch cozy atmosphere with {icon} glowing warmly, ambient lighting, entertainment vibes',
  'tv': 'retro television studio with {icon} center stage, vintage cameras, broadcast lights',
  
  // Food & Lifestyle
  'food': 'gourmet kitchen atmosphere with {icon} artfully presented, warm ambient lighting, culinary excellence',
  'restaurant': 'upscale dining ambiance with {icon} elegantly displayed, candlelight glow, fine dining aesthetic',
  'cooking': 'professional kitchen with {icon} dramatically lit, steam rising, chef\'s workspace energy',
  
  // Travel & Adventure
  'travel': 'wanderlust destination with {icon} against scenic backdrop, golden hour lighting, adventure energy',
  'adventure': 'epic journey scene with {icon} prominently featured, dramatic landscape, explorer spirit',
  'world': 'global connection atmosphere with {icon} centered, international vibes, cosmopolitan energy',
  
  // General/Default
  'default': 'dramatic scene with {icon} as focal point, cinematic lighting, dynamic composition, eye-catching atmosphere'
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
    'netflix', 'spotify', 'tiktok', 'youtube', 'instagram', 'twitter',
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
 * Detect scene category from topic
 */
const detectSceneCategory = (topic: string): string => {
  const topicLower = topic.toLowerCase();
  
  const categoryMap: Record<string, string[]> = {
    'music': ['music', 'song', 'singer', 'artist', 'band', 'album', 'hits', 'playlist'],
    'concert': ['concert', 'tour', 'live', 'festival', 'performance'],
    'sports': ['sport', 'championship', 'league', 'cup', 'tournament'],
    'basketball': ['basketball', 'nba', 'hoops', 'dunk'],
    'soccer': ['soccer', 'football', 'fifa', 'premier', 'world cup'],
    'gaming': ['game', 'gaming', 'gamer', 'video game', 'console'],
    'esports': ['esports', 'competitive', 'tournament'],
    'movie': ['movie', 'film', 'cinema', 'hollywood', 'actor', 'actress'],
    'streaming': ['netflix', 'streaming', 'series', 'binge', 'watch'],
    'tech': ['tech', 'technology', 'innovation', 'startup'],
    'ai': ['ai', 'artificial', 'chatgpt', 'robot', 'machine learning'],
    'food': ['food', 'cuisine', 'dish', 'meal', 'recipe'],
    'travel': ['travel', 'destination', 'country', 'city', 'world'],
  };
  
  for (const [category, keywords] of Object.entries(categoryMap)) {
    if (keywords.some(keyword => topicLower.includes(keyword))) {
      return category;
    }
  }
  
  return 'default';
};

/**
 * Generate a creative image prompt using ChatGPT with retro pulp poster style
 * Enhanced with visual drama and cinematic effects
 * @param topic The deck topic/theme
 * @returns Promise<string> The generated prompt for DALL-E
 */
const generateImagePrompt = async (topic: string): Promise<string> => {
  try {
    const openai = getOpenAIClient();
    
    // Detect brand-associated colors for this topic (legal - no logos)
    const brandColors = detectBrandColors(topic);
    const colorHint = brandColors 
      ? `Use this color palette: ${brandColors}` 
      : 'Choose an appropriate 2-3 color palette from the options';
    
    // Detect scene category for contextual templates
    const sceneCategory = detectSceneCategory(topic);
    const sceneTemplate = SCENE_TEMPLATES[sceneCategory] || SCENE_TEMPLATES['default'];
    
    // Determine if text is needed for clarity
    const textLevel = shouldIncludeText(topic);
    const textInstructions = getTextInstructions(textLevel, topic);
    
    // Determine if generic silhouettes are allowed
    const silhouetteInstructions = getSilhouetteInstructions(topic);
    
    // Select random visual enhancements
    const lighting = VISUAL_EFFECTS.lighting[Math.floor(Math.random() * VISUAL_EFFECTS.lighting.length)];
    const particles = VISUAL_EFFECTS.particles[Math.floor(Math.random() * VISUAL_EFFECTS.particles.length)];
    const motion = VISUAL_EFFECTS.motion[Math.floor(Math.random() * VISUAL_EFFECTS.motion.length)];
    const atmosphere = VISUAL_EFFECTS.atmosphere[Math.floor(Math.random() * VISUAL_EFFECTS.atmosphere.length)];
    const composition = COMPOSITION_RULES[Math.floor(Math.random() * COMPOSITION_RULES.length)];
    
    const systemPrompt = `You are a master visual storyteller creating STUNNING, CINEMATIC retro pulp poster thumbnails that grab attention instantly.

CORE MISSION: Create images so visually compelling that users MUST click. Think movie posters, album covers, championship moments - EPIC VISUAL DRAMA.

STRICT FORMULA:
App-store deck thumbnail, 3:4 poster (1024×1365), [retro/vintage/pulp] style; [CINEMATIC SCENE with dramatic generic icons], [brand colors], [visual effects], [text if applicable], [retro texture].

VISUAL DRAMA REQUIREMENTS (Make it IRRESISTIBLE):

1. SCALE & IMPACT: Make primary icon LARGE and commanding (fills 40-60% of frame)
2. DRAMATIC LIGHTING: ${lighting}
3. PARTICLE EFFECTS: ${particles}  
4. MOTION & ENERGY: ${motion}
5. ATMOSPHERE: ${atmosphere}
6. COMPOSITION: ${composition}

SCENE CONTEXT for "${topic}":
${sceneTemplate}

TEXT INSTRUCTIONS FOR THIS DECK:
${textInstructions}

HUMAN SILHOUETTE RULES FOR THIS DECK:
${silhouetteInstructions}

CRITICAL RULES:
✅ CREATE A SCENE, not just objects - tell a visual story
✅ GENERIC ICONS ONLY - NO copyrighted logos, NO trademarks, NO brand marks
✅ CINEMATIC DRAMA - dramatic lighting, particles, motion, depth, atmosphere
✅ LARGE SCALE - make primary elements prominent and eye-catching
✅ ENVIRONMENTAL CONTEXT - stage, arena, venue atmosphere
✅ RETRO PULP AESTHETIC - worn paper + halftone grain is MANDATORY
✅ TEXT HANDLING - follow the text instructions above carefully
✅ SILHOUETTE HANDLING - follow silhouette rules strictly (only generic, non-identifiable)

VISUAL EFFECTS TO USE:
- Lighting: spotlight beams, neon glow, rim lighting, lens flare, volumetric rays
- Particles: confetti, sparkles, energy orbs, light trails, stardust
- Motion: levitation, motion blur, frozen action, spinning, velocity trails
- Depth: foreground/background layers, bokeh, atmospheric perspective
- Drama: high contrast, dramatic shadows, epic scale, cinematic composition

TEXT STYLING (when applicable):
- Retro pulp typography (vintage, bold, distressed)
- Should complement, not dominate the visual
- Integrated into composition naturally
- Small to medium size, tasteful placement

SILHOUETTE GUIDELINES (when allowed):
- Use ONLY if topic involves people/celebrities
- Must be completely generic and non-identifiable
- Faceless, neutral poses, no distinctive features
- Could represent ANY person in that profession
- Examples: generic performer with mic, anonymous crowd, abstract dancer

STUNNING EXAMPLES:

Concert (NO SILHOUETTES): "App-store deck thumbnail, 3:4 poster (1024×1365), retro pulp style; MASSIVE chrome microphone center stage under crossing spotlight beams with golden sparkles exploding outward, arena crowd lights creating bokeh background, musical notes swirling like constellation trails, concert stage atmosphere bathed in pink/gold glow, worn paper + halftone grain, cinematic lighting, NO TEXT, no people"

Celebrity Topic (SAFE SILHOUETTES): "App-store deck thumbnail, 3:4 poster (1024×1365), vintage pulp style; GIANT microphone center stage with GENERIC FACELESS performer silhouette in neutral stance holding it, spotlight beams crossing dramatically, golden sparkles exploding, anonymous crowd silhouettes in background (completely generic, non-identifiable), concert atmosphere with pink/gold glow, worn paper + halftone grain, cinematic lighting, minimal text 'MUSIC STARS'"

Sports (SAFE SILHOUETTES): "App-store deck thumbnail, 3:4 poster (1024×1365), retro pulp style; MASSIVE trophy with GENERIC faceless athlete silhouette in neutral celebratory pose (arms raised, no distinctive features), confetti explosion, stadium lights, orange/gold palette, completely anonymous figure that could be ANY athlete, halftone grain, epic scale, NO TEXT"

Your task: Create ONE STUNNING, CINEMATIC prompt that makes users want to click immediately. Use dramatic scale, lighting, effects, and atmosphere. Follow silhouette rules strictly if applicable. Be BOLD and VISUAL!`;

    const userPrompt = `Create a STUNNING retro pulp poster prompt for: "${topic}"

${colorHint}

Scene Template: ${sceneTemplate}

TEXT HANDLING: ${textInstructions}

SILHOUETTE RULES: ${silhouetteInstructions}

REQUIREMENTS - Make it CINEMATIC and CLICK-WORTHY:
1. "App-store deck thumbnail, 3:4 poster (1024×1365)" at start
2. retro/vintage/pulp style  
3. LARGE-SCALE primary icon (40-60% of frame) - make it MASSIVE and commanding
4. DRAMATIC SCENE with environmental context (stage, arena, venue atmosphere)
5. CINEMATIC EFFECTS: ${lighting}, ${particles}, ${motion}
6. ${atmosphere}
7. Brand colors if detected, 2-3 color palette
8. worn paper + halftone grain texture (MANDATORY)
9. ${composition}
10. Handle text according to instructions above
11. For people topics: Use GENERIC, non-identifiable silhouettes ONLY if they follow all safety rules
12. Always end with appropriate people handling ("no people" or "generic anonymous silhouettes only")

CRITICAL: 
- NO copyrighted logos, NO brand marks - GENERIC icons only
- If silhouettes used, they must be completely generic and non-identifiable
- NO recognizable celebrity poses, NO distinctive features, NO identifying characteristics
- CREATE A SCENE with drama, not just objects floating
- Make it SO visually stunning users MUST click
- Think: movie poster / album cover / championship moment level impact
- Use bold, dramatic, cinematic language

Output ONLY the complete prompt, nothing else. Make it EPIC!`;

    console.log('Generating cinematic retro pulp image prompt with GPT-4o for:', topic);

    const response = await withRetry(async () => {
      return await openai.chat.completions.create({
        model: 'gpt-4o', // Upgraded to GPT-4o for better creative output
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.8, // Higher creativity for dramatic visuals
        max_tokens: 350 // More tokens for detailed cinematic descriptions
      });
    });

    const generatedPrompt = response.choices[0]?.message?.content?.trim();

    if (!generatedPrompt) {
      throw new Error('No prompt generated by ChatGPT');
    }

    console.log('Generated prompt:', generatedPrompt);
    return generatedPrompt;

  } catch (error) {
    console.error('Error generating prompt with ChatGPT:', error);
    
    // Fallback to template-based prompt if ChatGPT fails
    console.warn('Falling back to template-based prompt');
    return generateFallbackPrompt(topic);
  }
};

/**
 * Generate a fallback prompt using template (if ChatGPT fails)
 * Enhanced with visual drama effects
 */
const generateFallbackPrompt = (topic: string): string => {
  const styleVariants = ['retro pulp style', 'vintage pulp style', 'retro style'];
  const selectedStyle = styleVariants[Math.floor(Math.random() * styleVariants.length)];
  
  // Try to detect brand colors first, fallback to generic palettes
  const brandColors = detectBrandColors(topic);
  
  const genericPalettes = [
    'neon pink/teal on dark',
    'red/ink-black',
    'purple/blue/white',
    'orange/ink-black/cream',
    'navy/gold/white',
    'magenta/black/white',
    'electric blue/violet',
    'green/cream/red',
    'saffron/teal/black'
  ];
  
  // Use brand colors if detected, otherwise random palette
  const selectedPalette = brandColors || genericPalettes[Math.floor(Math.random() * genericPalettes.length)];
  
  const textures = [
    'worn paper + halftone grain',
    'distressed paper + print dots',
    'paper scuffs + halftone',
    'halftone + worn paper',
    'print-dot grain + distressed paper'
  ];
  
  // Enhanced cinematic icon compositions with visual drama
  const cinematicCompositions = [
    'MASSIVE chrome microphone center stage with spotlight beams crossing and golden sparkles exploding',
    'GIANT trophy levitating dramatically with confetti explosion suspended in slow-motion',
    'HUGE game controller glowing with neon energy and particle streams flowing',
    'LARGE play button bursting with cinematic light rays and motion trails',
    'EPIC basketball frozen mid-air with arena lights creating star pattern',
    'ENORMOUS musical notes swirling like constellation patterns with ethereal glow',
    'DRAMATIC guitar silhouette with electric energy bolts radiating outward',
    'GIGANTIC headphones with sound waves visualized and neon pulse effects',
    'MASSIVE trophy with championship ribbons streaming and victory sparkles',
    'HUGE microphone with stage smoke swirling and dramatic spotlight focus',
    'LARGE film reel spinning with golden light trails and cinematic atmosphere',
    'EPIC soccer ball with motion blur streaks and stadium lights blazing',
    'DRAMATIC popcorn bucket with movie premiere lights and glamorous glow',
    'GIANT chat bubble with digital particles floating and tech energy pulsing',
    'MASSIVE fork and knife crossed with culinary sparkles and warm ambient glow',
    'HUGE camera lens with bokeh lights and photographer flash bursts',
    'EPIC microphone stand tilted dramatically with concert atmosphere and arena crowd bokeh'
  ];
  
  // Random visual enhancements
  const lighting = VISUAL_EFFECTS.lighting[Math.floor(Math.random() * VISUAL_EFFECTS.lighting.length)];
  const atmosphere = VISUAL_EFFECTS.atmosphere[Math.floor(Math.random() * VISUAL_EFFECTS.atmosphere.length)];
  
  const selectedTexture = textures[Math.floor(Math.random() * textures.length)];
  const selectedComposition = cinematicCompositions[Math.floor(Math.random() * cinematicCompositions.length)];
  
  // Generate CINEMATIC prompt focusing on visual drama + brand colors, NO TRADEMARKS
  return `App-store deck thumbnail, 3:4 poster (1024×1365), ${selectedStyle}; ${selectedComposition}, ${lighting}, ${atmosphere}, ${selectedPalette}, ${selectedTexture}, high contrast, epic scale, no text, no people.`;
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
}

// Legacy alias for backward compatibility
export type DallE3Options = ImageGenerationOptions;

/**
 * Generate a deck cover image using gpt-image-1 (ChatGPT's image model)
 * @param topic The deck topic/theme
 * @param _stylePreference Optional style modifier (kept for backward compatibility, not used - retro pulp style is always applied)
 * @param options Optional image generation options
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
    const defaultOptions: Required<ImageGenerationOptions> = {
      quality: 'medium', // Changed from 'standard' to 'medium' (gpt-image-1 supported value)
      size: '1024x1536', // Changed from '1024x1792' to '1024x1536' (gpt-image-1 supported portrait size)
      n: 1,
    };
    
    const finalOptions = { ...defaultOptions, ...options };
    
    // Step 1: Generate creative prompt using ChatGPT
    const prompt = await generateImagePrompt(topic);
    
    console.log('=== GPT-IMAGE-1 IMAGE GENERATION PROMPT ===');
    console.log(prompt);
    console.log('=== END OF PROMPT ===');
    console.log('Generating image with gpt-image-1 (ChatGPT image model)');
    
    // Step 2: Generate image using gpt-image-1
    // Note: gpt-image-1 does NOT support 'style' or 'response_format' parameters
    // It only returns base64-encoded images
    const response = await withRetry(async () => {
      return await openai.images.generate({
        model: 'gpt-image-1', // ChatGPT's image generation model
        prompt: prompt, // Text description of the desired image(s)
        n: finalOptions.n, // Number of images (1-10)
        size: finalOptions.size, // Size options: 1024x1024, 1024x1536, 1536x1024, or auto
        quality: finalOptions.quality, // Quality: 'low', 'medium', 'high', or 'auto'
        // NOTE: No 'style' parameter - not supported by gpt-image-1
        // NOTE: No 'response_format' - always returns b64_json
      });
    });
    
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
