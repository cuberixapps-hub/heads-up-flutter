/**
 * Migration Script: Firestore to Supabase
 * 
 * This script migrates deck data from Firestore to Supabase.
 * 
 * Usage:
 * 1. Ensure both Firebase and Supabase are configured
 * 2. Run: npx ts-node migrate-to-supabase.ts
 * 
 * Prerequisites:
 * - Firebase Admin SDK credentials or Firestore access
 * - Supabase project with schema created (run supabase-schema.sql first)
 */

import { createClient } from '@supabase/supabase-js';
import { initializeApp, cert, type ServiceAccount } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Configuration - UPDATE THESE VALUES
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'your-service-role-key';
const FIREBASE_SERVICE_ACCOUNT = process.env.FIREBASE_SERVICE_ACCOUNT || './firebase-service-account.json';

// Initialize Supabase client with service role key for full access
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Initialize Firebase Admin
let firebaseApp;
try {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const serviceAccount = require(FIREBASE_SERVICE_ACCOUNT) as ServiceAccount;
  firebaseApp = initializeApp({
    credential: cert(serviceAccount),
  });
} catch (error) {
  console.error('Failed to initialize Firebase. Make sure firebase-service-account.json exists.');
  console.error('You can download it from Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

const firestore = getFirestore(firebaseApp);

interface FirestoreDeck {
  name: string;
  description: string;
  cards: string[];
  iconCodePoint: number;
  iconFontFamily: string;
  iconFontPackage?: string;
  colorValue: number;
  colorName?: string;
  colorHex?: string;
  imageUrl?: string;
  isPremium: boolean;
  isActive: boolean;
  country?: string;
  countries?: string[];
  tags?: string[];
  priority?: number;
  playCount?: number;
  hasDifficultyModes?: boolean;
  cardsByDifficulty?: {
    easy: string[];
    medium: string[];
    hard: string[];
  };
  generatedByAI?: boolean;
  automatedGeneration?: boolean;
  researchBased?: boolean;
  generationTopic?: string;
  generationCategory?: string;
  baseTopic?: string;
  research?: Record<string, unknown>;
  translations?: Record<string, unknown>;
  createdAt?: { toDate(): Date };
  updatedAt?: { toDate(): Date };
}

interface FirestoreDailyDeck {
  date: { toDate(): Date };
  title: string;
  description: string;
  cards: Array<{
    word: string;
    category: string;
    difficulty: number;
  }>;
  color: number;
  iconName: string;
  imageUrl?: string;
  isActive: boolean;
  createdAt?: { toDate(): Date };
  expiresAt?: { toDate(): Date };
}

/**
 * Convert Firestore deck to Supabase format (camelCase to snake_case)
 */
function convertDeckToSupabase(doc: FirebaseFirestore.DocumentSnapshot): Record<string, unknown> {
  const data = doc.data() as FirestoreDeck;
  
  return {
    id: doc.id, // Use Firestore ID as Supabase ID for consistency
    name: data.name,
    description: data.description || '',
    cards: data.cards || [],
    icon_code_point: data.iconCodePoint || 0xf005,
    icon_font_family: data.iconFontFamily || 'FontAwesomeIcons',
    icon_font_package: data.iconFontPackage,
    color_value: data.colorValue || 0xFF9C27B0,
    color_name: data.colorName,
    color_hex: data.colorHex,
    image_url: data.imageUrl,
    is_premium: data.isPremium || false,
    is_active: data.isActive !== false,
    country: data.country,
    countries: data.countries || (data.country ? [data.country] : ['UNIVERSAL']),
    tags: data.tags || [],
    priority: data.priority || 0,
    play_count: data.playCount || 0,
    has_difficulty_modes: data.hasDifficultyModes || false,
    cards_by_difficulty: data.cardsByDifficulty,
    generated_by_ai: data.generatedByAI,
    automated_generation: data.automatedGeneration,
    research_based: data.researchBased,
    generation_topic: data.generationTopic,
    generation_category: data.generationCategory,
    base_topic: data.baseTopic,
    research: data.research,
    translations: data.translations,
    created_at: data.createdAt?.toDate()?.toISOString() || new Date().toISOString(),
    updated_at: data.updatedAt?.toDate()?.toISOString() || new Date().toISOString(),
  };
}

/**
 * Convert Firestore daily deck to Supabase format
 */
function convertDailyDeckToSupabase(doc: FirebaseFirestore.DocumentSnapshot): Record<string, unknown> {
  const data = doc.data() as FirestoreDailyDeck;
  
  return {
    id: doc.id,
    date: data.date?.toDate()?.toISOString().split('T')[0],
    title: data.title,
    description: data.description || '',
    cards: data.cards || [],
    color: data.color || 0xFF4CAF50,
    icon_name: data.iconName || 'calendar_today',
    image_url: data.imageUrl,
    is_active: data.isActive !== false,
    created_at: data.createdAt?.toDate()?.toISOString() || new Date().toISOString(),
    expires_at: data.expiresAt?.toDate()?.toISOString(),
  };
}

/**
 * Migrate decks from Firestore to Supabase
 */
async function migrateDecks(): Promise<{ success: number; failed: number }> {
  console.log('\n📦 Migrating decks...');
  
  let success = 0;
  let failed = 0;
  
  try {
    const snapshot = await firestore.collection('decks').get();
    const totalDecks = snapshot.size;
    
    console.log(`Found ${totalDecks} decks to migrate`);
    
    // Process in batches of 50
    const batchSize = 50;
    const decks: Record<string, unknown>[] = [];
    
    snapshot.forEach(doc => {
      try {
        decks.push(convertDeckToSupabase(doc));
      } catch (error) {
        console.error(`Failed to convert deck ${doc.id}:`, error);
        failed++;
      }
    });
    
    // Insert in batches
    for (let i = 0; i < decks.length; i += batchSize) {
      const batch = decks.slice(i, i + batchSize);
      
      const { error } = await supabase
        .from('decks')
        .upsert(batch, { 
          onConflict: 'id',
          ignoreDuplicates: false 
        });
      
      if (error) {
        console.error(`Failed to insert batch ${Math.floor(i / batchSize) + 1}:`, error);
        failed += batch.length;
      } else {
        success += batch.length;
        console.log(`✅ Migrated ${Math.min(i + batchSize, decks.length)}/${decks.length} decks`);
      }
    }
    
  } catch (error) {
    console.error('Error migrating decks:', error);
  }
  
  return { success, failed };
}

/**
 * Migrate daily decks from Firestore to Supabase
 */
async function migrateDailyDecks(): Promise<{ success: number; failed: number }> {
  console.log('\n📅 Migrating daily decks...');
  
  let success = 0;
  let failed = 0;
  
  try {
    const snapshot = await firestore.collection('daily_decks').get();
    const totalDecks = snapshot.size;
    
    console.log(`Found ${totalDecks} daily decks to migrate`);
    
    const dailyDecks: Record<string, unknown>[] = [];
    
    snapshot.forEach(doc => {
      try {
        dailyDecks.push(convertDailyDeckToSupabase(doc));
      } catch (error) {
        console.error(`Failed to convert daily deck ${doc.id}:`, error);
        failed++;
      }
    });
    
    // Insert in batches
    const batchSize = 50;
    for (let i = 0; i < dailyDecks.length; i += batchSize) {
      const batch = dailyDecks.slice(i, i + batchSize);
      
      const { error } = await supabase
        .from('daily_decks')
        .upsert(batch, { 
          onConflict: 'id',
          ignoreDuplicates: false 
        });
      
      if (error) {
        console.error(`Failed to insert daily deck batch:`, error);
        failed += batch.length;
      } else {
        success += batch.length;
        console.log(`✅ Migrated ${Math.min(i + batchSize, dailyDecks.length)}/${dailyDecks.length} daily decks`);
      }
    }
    
  } catch (error) {
    console.error('Error migrating daily decks:', error);
  }
  
  return { success, failed };
}

/**
 * Verify migration by comparing counts
 */
async function verifyMigration(): Promise<void> {
  console.log('\n🔍 Verifying migration...');
  
  // Count Firestore documents
  const firestoreDecks = await firestore.collection('decks').get();
  const firestoreDailyDecks = await firestore.collection('daily_decks').get();
  
  // Count Supabase rows
  const { count: supabaseDecks } = await supabase
    .from('decks')
    .select('*', { count: 'exact', head: true });
  
  const { count: supabaseDailyDecks } = await supabase
    .from('daily_decks')
    .select('*', { count: 'exact', head: true });
  
  console.log('\n📊 Migration Results:');
  console.log(`   Decks: Firestore ${firestoreDecks.size} → Supabase ${supabaseDecks || 0}`);
  console.log(`   Daily Decks: Firestore ${firestoreDailyDecks.size} → Supabase ${supabaseDailyDecks || 0}`);
  
  if (firestoreDecks.size === supabaseDecks && firestoreDailyDecks.size === supabaseDailyDecks) {
    console.log('\n✅ Migration verified successfully!');
  } else {
    console.log('\n⚠️ Some records may have failed to migrate. Check errors above.');
  }
}

/**
 * Main migration function
 */
async function main(): Promise<void> {
  console.log('═══════════════════════════════════════════════════');
  console.log('       Firestore to Supabase Migration');
  console.log('═══════════════════════════════════════════════════');
  
  // Check configuration
  if (SUPABASE_URL.includes('your-project')) {
    console.error('❌ Please configure SUPABASE_URL');
    process.exit(1);
  }
  
  if (SUPABASE_SERVICE_KEY.includes('your-service')) {
    console.error('❌ Please configure SUPABASE_SERVICE_KEY (use the service_role key, not anon)');
    process.exit(1);
  }
  
  console.log('\n🚀 Starting migration...');
  console.log(`   Supabase URL: ${SUPABASE_URL}`);
  
  // Migrate decks
  const deckResults = await migrateDecks();
  
  // Migrate daily decks
  const dailyDeckResults = await migrateDailyDecks();
  
  // Verify
  await verifyMigration();
  
  // Summary
  console.log('\n═══════════════════════════════════════════════════');
  console.log('       Migration Summary');
  console.log('═══════════════════════════════════════════════════');
  console.log(`   Decks: ${deckResults.success} success, ${deckResults.failed} failed`);
  console.log(`   Daily Decks: ${dailyDeckResults.success} success, ${dailyDeckResults.failed} failed`);
  console.log('═══════════════════════════════════════════════════\n');
}

// Run migration
main().catch(console.error);
