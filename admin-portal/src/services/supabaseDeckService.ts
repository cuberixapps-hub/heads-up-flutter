import { supabase, isSupabaseConfigured } from '../config/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

// ===========================================
// Types
// ===========================================

export interface DeckData {
  id?: string;
  name: string;
  description: string;
  cards: string[];
  iconCodePoint: number;
  iconFontFamily: string;
  iconFontPackage?: string;
  colorValue: number;
  colorName?: string;
  colorHex?: string;
  imageUrl?: string | null;
  isPremium: boolean;
  premiumOnly?: boolean; // If true, ads cannot unlock this deck - purchase only
  isActive: boolean;
  country?: string;
  countries: string[];
  tags: string[];
  priority: number;
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
  // Fresh web-data columns (migration 2026-05-02)
  usedFreshData?: boolean;
  freshDataRetrievedAt?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface DailyDeckData {
  id?: string;
  date: Date;
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
  createdAt?: Date;
  expiresAt?: Date | null;
}

// ===========================================
// Helper Functions
// ===========================================

/**
 * Convert camelCase object keys to snake_case for Supabase
 */
function toSnakeCase(data: DeckData): Record<string, unknown> {
  return {
    name: data.name,
    description: data.description,
    cards: data.cards,
    icon_code_point: data.iconCodePoint,
    icon_font_family: data.iconFontFamily,
    icon_font_package: data.iconFontPackage,
    color_value: data.colorValue,
    color_name: data.colorName,
    color_hex: data.colorHex,
    image_url: data.imageUrl,
    is_premium: data.isPremium,
    premium_only: data.premiumOnly || false,
    is_active: data.isActive,
    country: data.country,
    countries: data.countries,
    tags: data.tags,
    priority: data.priority,
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
    // Fresh data columns
    used_fresh_data: data.usedFreshData ?? false,
    fresh_data_retrieved_at: data.freshDataRetrievedAt ?? null,
  };
}

/**
 * Convert snake_case Supabase row to camelCase for frontend
 */
function toCamelCase(row: Record<string, unknown>): DeckData {
  return {
    id: row.id as string,
    name: row.name as string,
    description: row.description as string || '',
    cards: (row.cards as string[]) || [],
    iconCodePoint: row.icon_code_point as number || 0xf005,
    iconFontFamily: row.icon_font_family as string || 'FontAwesomeIcons',
    iconFontPackage: row.icon_font_package as string | undefined,
    colorValue: row.color_value as number || 0xFF9C27B0,
    colorName: row.color_name as string | undefined,
    colorHex: row.color_hex as string | undefined,
    imageUrl: row.image_url as string | null,
    isPremium: row.is_premium as boolean || false,
    premiumOnly: row.premium_only as boolean || false,
    isActive: row.is_active as boolean ?? true,
    country: row.country as string | undefined,
    countries: (row.countries as string[]) || ['UNIVERSAL'],
    tags: (row.tags as string[]) || [],
    priority: row.priority as number || 0,
    playCount: row.play_count as number || 0,
    hasDifficultyModes: row.has_difficulty_modes as boolean || false,
    cardsByDifficulty: row.cards_by_difficulty as DeckData['cardsByDifficulty'],
    generatedByAI: row.generated_by_ai as boolean,
    automatedGeneration: row.automated_generation as boolean,
    researchBased: row.research_based as boolean,
    generationTopic: row.generation_topic as string,
    generationCategory: row.generation_category as string,
    baseTopic: row.base_topic as string,
    research: row.research as Record<string, unknown>,
    translations: row.translations as Record<string, unknown>,
    // Fresh data columns
    usedFreshData: (row.used_fresh_data as boolean) ?? false,
    freshDataRetrievedAt: (row.fresh_data_retrieved_at as string | null) ?? null,
    createdAt: row.created_at as string,
    updatedAt: row.updated_at as string,
  };
}

/**
 * Convert DailyDeckData to snake_case for Supabase
 */
function dailyDeckToSnakeCase(data: DailyDeckData): Record<string, unknown> {
  return {
    date: data.date.toISOString().split('T')[0],
    title: data.title,
    description: data.description,
    cards: data.cards,
    color: data.color,
    icon_name: data.iconName,
    image_url: data.imageUrl,
    is_active: data.isActive,
    expires_at: data.expiresAt?.toISOString() || null,
  };
}

/**
 * Convert Supabase daily deck row to DailyDeckData
 */
function dailyDeckToCamelCase(row: Record<string, unknown>): DailyDeckData {
  return {
    id: row.id as string,
    date: new Date(row.date as string),
    title: row.title as string,
    description: row.description as string || '',
    cards: (row.cards as DailyDeckData['cards']) || [],
    color: row.color as number || 0xFF4CAF50,
    iconName: row.icon_name as string || 'calendar_today',
    imageUrl: row.image_url as string | undefined,
    isActive: row.is_active as boolean ?? true,
    createdAt: row.created_at ? new Date(row.created_at as string) : new Date(),
    expiresAt: row.expires_at ? new Date(row.expires_at as string) : null,
  };
}

// ===========================================
// Deck CRUD Operations
// ===========================================

/**
 * Get all decks from Supabase
 */
export async function getAllDecks(): Promise<DeckData[]> {
  if (!isSupabaseConfigured()) {
    console.warn('Supabase not configured, returning empty array');
    return [];
  }

  const { data, error } = await supabase
    .from('decks')
    .select('*')
    .order('priority', { ascending: true })
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching decks:', error);
    throw error;
  }

  return (data || []).map(toCamelCase);
}

/**
 * Get a single deck by ID
 */
export async function getDeckById(id: string): Promise<DeckData | null> {
  const { data, error } = await supabase
    .from('decks')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    console.error('Error fetching deck:', error);
    return null;
  }

  return data ? toCamelCase(data) : null;
}

/**
 * Create a new deck
 */
export async function createDeck(deckData: DeckData): Promise<DeckData> {
  const snakeCaseData = toSnakeCase(deckData);

  const { data, error } = await supabase
    .from('decks')
    .insert(snakeCaseData)
    .select()
    .single();

  if (error) {
    console.error('Error creating deck:', error);
    throw error;
  }

  return toCamelCase(data);
}

/**
 * Update an existing deck
 */
export async function updateDeck(id: string, deckData: Partial<DeckData>): Promise<DeckData> {
  const snakeCaseData = toSnakeCase(deckData as DeckData);

  // Remove undefined values
  const cleanData = Object.fromEntries(
    Object.entries(snakeCaseData).filter(([, v]) => v !== undefined)
  );

  const { data, error } = await supabase
    .from('decks')
    .update(cleanData)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('Error updating deck:', error);
    throw error;
  }

  return toCamelCase(data);
}

/**
 * Delete a deck
 */
export async function deleteDeck(id: string): Promise<void> {
  const { error } = await supabase
    .from('decks')
    .delete()
    .eq('id', id);

  if (error) {
    console.error('Error deleting deck:', error);
    throw error;
  }
}

/**
 * Subscribe to real-time deck changes
 */
export function subscribeToDecks(
  callback: (decks: DeckData[]) => void,
  onError?: (error: Error) => void
): RealtimeChannel {
  // Initial fetch
  getAllDecks().then(callback).catch(onError);

  // Set up real-time subscription
  const channel = supabase
    .channel('decks-changes')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'decks' },
      () => {
        // Refetch all decks on any change
        getAllDecks().then(callback).catch(onError);
      }
    )
    .subscribe();

  return channel;
}

/**
 * Unsubscribe from real-time changes
 */
export function unsubscribeFromDecks(channel: RealtimeChannel): void {
  supabase.removeChannel(channel);
}

/**
 * Get deck count by country for distribution tracking
 */
export async function getCountryDistribution(): Promise<Record<string, number>> {
  const { data, error } = await supabase
    .from('decks')
    .select('countries');

  if (error) {
    console.error('Error fetching country distribution:', error);
    return {};
  }

  const distribution: Record<string, number> = {};

  (data || []).forEach(row => {
    const countries = (row.countries as string[]) || ['UNIVERSAL'];
    countries.forEach(country => {
      distribution[country] = (distribution[country] || 0) + 1;
    });
  });

  return distribution;
}

/**
 * Increment play count for a deck
 */
export async function incrementPlayCount(id: string): Promise<void> {
  const { error } = await supabase.rpc('increment_play_count', { deck_id: id });

  if (error) {
    // Fallback to manual increment if RPC doesn't exist
    const { data: deck } = await supabase
      .from('decks')
      .select('play_count')
      .eq('id', id)
      .single();

    if (deck) {
      await supabase
        .from('decks')
        .update({ play_count: (deck.play_count || 0) + 1 })
        .eq('id', id);
    }
  }
}

// ===========================================
// Daily Deck Operations
// ===========================================

/**
 * Get all daily decks
 */
export async function getAllDailyDecks(): Promise<DailyDeckData[]> {
  const { data, error } = await supabase
    .from('daily_decks')
    .select('*')
    .order('date', { ascending: false });

  if (error) {
    console.error('Error fetching daily decks:', error);
    throw error;
  }

  return (data || []).map(dailyDeckToCamelCase);
}

/**
 * Create a new daily deck
 */
export async function createDailyDeck(deckData: DailyDeckData): Promise<DailyDeckData> {
  const snakeCaseData = dailyDeckToSnakeCase(deckData);

  const { data, error } = await supabase
    .from('daily_decks')
    .insert(snakeCaseData)
    .select()
    .single();

  if (error) {
    console.error('Error creating daily deck:', error);
    throw error;
  }

  return dailyDeckToCamelCase(data);
}

/**
 * Update a daily deck
 */
export async function updateDailyDeck(id: string, deckData: Partial<DailyDeckData>): Promise<DailyDeckData> {
  const snakeCaseData = dailyDeckToSnakeCase(deckData as DailyDeckData);

  const cleanData = Object.fromEntries(
    Object.entries(snakeCaseData).filter(([, v]) => v !== undefined)
  );

  const { data, error } = await supabase
    .from('daily_decks')
    .update(cleanData)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('Error updating daily deck:', error);
    throw error;
  }

  return dailyDeckToCamelCase(data);
}

/**
 * Delete a daily deck
 */
export async function deleteDailyDeck(id: string): Promise<void> {
  const { error } = await supabase
    .from('daily_decks')
    .delete()
    .eq('id', id);

  if (error) {
    console.error('Error deleting daily deck:', error);
    throw error;
  }
}

/**
 * Subscribe to real-time daily deck changes
 */
export function subscribeToDailyDecks(
  callback: (decks: DailyDeckData[]) => void,
  onError?: (error: Error) => void
): RealtimeChannel {
  // Initial fetch
  getAllDailyDecks().then(callback).catch(onError);

  // Set up real-time subscription
  const channel = supabase
    .channel('daily-decks-changes')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'daily_decks' },
      () => {
        getAllDailyDecks().then(callback).catch(onError);
      }
    )
    .subscribe();

  return channel;
}

// ===========================================
// Automation Stats
// ===========================================

/**
 * Get automation statistics
 */
export async function getAutomationStats(): Promise<{
  totalDecksCreated: number;
  successfulGenerations: number;
  countryDistribution: Record<string, number>;
  lastGeneratedAt?: Date;
}> {
  const { data, error } = await supabase
    .from('decks')
    .select('countries, created_at')
    .eq('automated_generation', true)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching automation stats:', error);
    return {
      totalDecksCreated: 0,
      successfulGenerations: 0,
      countryDistribution: {},
    };
  }

  const countryDistribution: Record<string, number> = {};
  let lastGeneratedAt: Date | undefined;

  (data || []).forEach((row, index) => {
    const countries = (row.countries as string[]) || ['UNIVERSAL'];
    countries.forEach(country => {
      countryDistribution[country] = (countryDistribution[country] || 0) + 1;
    });

    if (index === 0 && row.created_at) {
      lastGeneratedAt = new Date(row.created_at as string);
    }
  });

  return {
    totalDecksCreated: data?.length || 0,
    successfulGenerations: data?.length || 0,
    countryDistribution,
    lastGeneratedAt,
  };
}
