import { createClient } from '@supabase/supabase-js';

// Supabase configuration
// Can be overridden by .env.local:
// VITE_SUPABASE_URL=https://your-project.supabase.co
// VITE_SUPABASE_ANON_KEY=your-anon-key

const DEFAULT_SUPABASE_URL = 'https://ybrtwonwgvangibcvrpx.supabase.co';
const DEFAULT_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlicnR3b253Z3ZhbmdpYmN2cnB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3NTU0MzEsImV4cCI6MjA4NDMzMTQzMX0.MYTzmqBXoLgq3kmpEii7d8R81-328NfK-1lSDnSg_F8';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || DEFAULT_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || DEFAULT_SUPABASE_ANON_KEY;

// Create Supabase client
export const supabase = createClient(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      persistSession: false, // We're using Firebase for auth
    },
    realtime: {
      params: {
        eventsPerSecond: 10,
      },
    },
  }
);

// Export storage bucket name for consistency
export const DECK_IMAGES_BUCKET = 'deck-images';

// Check if Supabase is properly configured
export const isSupabaseConfigured = (): boolean => {
  return !!(supabaseUrl && supabaseAnonKey && !supabaseUrl.includes('placeholder'));
};
