-- ===========================================
-- Supabase Schema for Heads Up Game
-- ===========================================
-- Run this in Supabase SQL Editor to create tables

-- ===========================================
-- 1. DECKS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    cards TEXT[] NOT NULL DEFAULT '{}',
    
    -- Icon configuration
    icon_code_point INTEGER DEFAULT 63495, -- 0xf005 (star icon)
    icon_font_family TEXT DEFAULT 'FontAwesomeIcons',
    icon_font_package TEXT,
    
    -- Appearance
    color_value INTEGER DEFAULT 4288423856, -- 0xFF9C27B0 (purple)
    color_name TEXT,
    color_hex TEXT,
    image_url TEXT,
    
    -- Deck properties
    is_premium BOOLEAN DEFAULT FALSE,
    premium_only BOOLEAN DEFAULT FALSE, -- If true, ads cannot unlock this deck - purchase only
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0,
    play_count INTEGER DEFAULT 0,
    
    -- Country/Region targeting
    country TEXT, -- Legacy single country field
    countries TEXT[] DEFAULT ARRAY['UNIVERSAL'],
    tags TEXT[] DEFAULT '{}',
    
    -- Difficulty modes
    has_difficulty_modes BOOLEAN DEFAULT FALSE,
    cards_by_difficulty JSONB, -- { "easy": [...], "medium": [...], "hard": [...] }
    
    -- AI generation metadata
    generated_by_ai BOOLEAN DEFAULT FALSE,
    automated_generation BOOLEAN DEFAULT FALSE,
    research_based BOOLEAN DEFAULT FALSE,
    generation_topic TEXT,
    generation_category TEXT,
    base_topic TEXT,
    research JSONB, -- Research metadata for AI-generated decks
    
    -- Translations
    translations JSONB, -- { "es": { "name": "...", "description": "...", "cards": [...] } }
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- 2. DAILY DECKS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS daily_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    
    -- Cards stored as JSONB array: [{ "word": "...", "category": "...", "difficulty": 1 }]
    cards JSONB NOT NULL DEFAULT '[]',
    
    -- Appearance
    color INTEGER DEFAULT 4283215696, -- 0xFF4CAF50 (green)
    icon_name TEXT DEFAULT 'calendar_today',
    image_url TEXT,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- ===========================================
-- 3. INDEXES FOR PERFORMANCE
-- ===========================================

-- Decks indexes
CREATE INDEX IF NOT EXISTS idx_decks_is_active ON decks(is_active);
CREATE INDEX IF NOT EXISTS idx_decks_priority ON decks(priority);
CREATE INDEX IF NOT EXISTS idx_decks_countries ON decks USING GIN(countries);
CREATE INDEX IF NOT EXISTS idx_decks_country ON decks(country);
CREATE INDEX IF NOT EXISTS idx_decks_is_premium ON decks(is_premium);
CREATE INDEX IF NOT EXISTS idx_decks_premium_only ON decks(premium_only);
CREATE INDEX IF NOT EXISTS idx_decks_created_at ON decks(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_decks_play_count ON decks(play_count DESC);

-- Daily decks indexes
CREATE INDEX IF NOT EXISTS idx_daily_decks_date ON daily_decks(date);
CREATE INDEX IF NOT EXISTS idx_daily_decks_is_active ON daily_decks(is_active);
CREATE INDEX IF NOT EXISTS idx_daily_decks_date_active ON daily_decks(date, is_active);

-- ===========================================
-- 4. AUTO-UPDATE TRIGGER FOR updated_at
-- ===========================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for decks table
DROP TRIGGER IF EXISTS update_decks_updated_at ON decks;
CREATE TRIGGER update_decks_updated_at
    BEFORE UPDATE ON decks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ===========================================

-- Enable RLS on tables
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_decks ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read decks
CREATE POLICY "Allow public read access on decks"
    ON decks FOR SELECT
    USING (true);

-- Policy: Anyone can insert/update/delete decks (for admin portal)
-- In production, you may want to restrict this to authenticated users
CREATE POLICY "Allow public insert on decks"
    ON decks FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public update on decks"
    ON decks FOR UPDATE
    USING (true);

CREATE POLICY "Allow public delete on decks"
    ON decks FOR DELETE
    USING (true);

-- Policy: Anyone can read daily_decks
CREATE POLICY "Allow public read access on daily_decks"
    ON daily_decks FOR SELECT
    USING (true);

-- Policy: Anyone can insert/update/delete daily_decks (for admin portal)
CREATE POLICY "Allow public insert on daily_decks"
    ON daily_decks FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public update on daily_decks"
    ON daily_decks FOR UPDATE
    USING (true);

CREATE POLICY "Allow public delete on daily_decks"
    ON daily_decks FOR DELETE
    USING (true);

-- ===========================================
-- 6. USER DECK FEEDBACK TABLE
-- ===========================================
-- Stores user preferences and feedback about deck types they want

CREATE TABLE IF NOT EXISTS user_deck_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User identification (Firebase UID or device ID for anonymous users)
    user_id TEXT NOT NULL,
    device_id TEXT,
    
    -- Feedback type: 'interest', 'suggestion', 'rating', 'category_request'
    feedback_type TEXT NOT NULL DEFAULT 'interest',
    
    -- Selected interests/categories (array of category IDs)
    selected_categories TEXT[] DEFAULT '{}',
    
    -- Free-form deck suggestions from users
    deck_suggestion TEXT,
    suggestion_category TEXT,
    
    -- User-provided context
    user_message TEXT,
    
    -- Rating for specific content (1-5)
    rating INTEGER,
    related_deck_id UUID,
    
    -- User demographic/context (optional)
    user_country TEXT,
    user_language TEXT,
    user_age_group TEXT,
    
    -- Metadata
    platform TEXT, -- 'ios', 'android', 'web'
    app_version TEXT,
    
    -- Status for admin review
    status TEXT DEFAULT 'pending', -- 'pending', 'reviewed', 'implemented', 'rejected'
    admin_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for user_deck_feedback
CREATE INDEX IF NOT EXISTS idx_user_deck_feedback_user_id ON user_deck_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_user_deck_feedback_type ON user_deck_feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_user_deck_feedback_status ON user_deck_feedback(status);
CREATE INDEX IF NOT EXISTS idx_user_deck_feedback_categories ON user_deck_feedback USING GIN(selected_categories);
CREATE INDEX IF NOT EXISTS idx_user_deck_feedback_created_at ON user_deck_feedback(created_at DESC);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_user_deck_feedback_updated_at ON user_deck_feedback;
CREATE TRIGGER update_user_deck_feedback_updated_at
    BEFORE UPDATE ON user_deck_feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE user_deck_feedback ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert feedback (users can submit their preferences)
CREATE POLICY "Allow public insert on user_deck_feedback"
    ON user_deck_feedback FOR INSERT
    WITH CHECK (true);

-- Policy: Users can read their own feedback
CREATE POLICY "Allow users to read own feedback"
    ON user_deck_feedback FOR SELECT
    USING (true);

-- Policy: Users can update their own feedback
CREATE POLICY "Allow users to update own feedback"
    ON user_deck_feedback FOR UPDATE
    USING (true);

-- ===========================================
-- 7. APP CONFIG TABLE
-- ===========================================
-- Stores configurable app settings (like max feedback count)

CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast key lookup
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_app_config_updated_at ON app_config;
CREATE TRIGGER update_app_config_updated_at
    BEFORE UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read config
CREATE POLICY "Allow public read access on app_config"
    ON app_config FOR SELECT
    USING (true);

-- Insert default config values
INSERT INTO app_config (key, value, description) VALUES
    ('max_deck_feedback_count', '5', 'Maximum number of deck feedback submissions allowed per user (3-10 recommended)')
ON CONFLICT (key) DO NOTHING;

-- ===========================================
-- 8. STORAGE BUCKET POLICIES
-- ===========================================
-- Run these after creating the 'deck-images' bucket in Supabase Dashboard

-- Note: Storage policies are created via Dashboard or using the storage API
-- The bucket should be set to "public" for read access
-- 
-- Alternatively, run this after creating the bucket:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('deck-images', 'deck-images', true);

-- ===========================================
-- 9. USEFUL QUERIES (for reference)
-- ===========================================

-- Get decks by country (matches if country is in the countries array)
-- SELECT * FROM decks WHERE 'US' = ANY(countries) OR 'UNIVERSAL' = ANY(countries);

-- Get active decks sorted by priority
-- SELECT * FROM decks WHERE is_active = true ORDER BY priority ASC, created_at DESC;

-- Get today's daily deck
-- SELECT * FROM daily_decks WHERE date = CURRENT_DATE AND is_active = true LIMIT 1;

-- Get deck count by country
-- SELECT unnest(countries) as country, COUNT(*) FROM decks GROUP BY country;

-- ===========================================
-- SUCCESS MESSAGE
-- ===========================================
-- If you see this, the schema was created successfully!
SELECT 'Schema created successfully!' as status, 
       (SELECT COUNT(*) FROM decks) as deck_count,
       (SELECT COUNT(*) FROM daily_decks) as daily_deck_count;
