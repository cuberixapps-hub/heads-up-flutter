# Supabase Setup Guide

## 1. Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign up/login
2. Click "New Project"
3. Fill in:
   - **Project name**: `heads-up-game`
   - **Database Password**: Generate a strong password (save it!)
   - **Region**: Choose closest to your users
4. Wait for the project to be created (~2 minutes)

## 2. Get API Credentials

1. Go to **Settings** > **API**
2. Copy these values:
   - **Project URL**: `https://your-project-id.supabase.co`
   - **anon public key**: `eyJhbGc...` (long JWT token)

## 3. Configure Environment Variables

### Admin Portal (.env.local)

Create/update `admin-portal/.env.local`:

```env
# Supabase Configuration
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here

# Keep existing OpenAI key
VITE_OPENAI_API_KEY=your-openai-key
```

### Flutter App

The Supabase credentials will be configured in `lib/services/supabase_service.dart`.

## 4. Run Database Schema

1. Go to **SQL Editor** in Supabase Dashboard
2. Click "New Query"
3. Copy and paste the contents of `admin-portal/scripts/supabase-schema.sql`
4. Click "Run" to execute

## 5. Create Storage Bucket

1. Go to **Storage** in Supabase Dashboard
2. Click "New bucket"
3. Name: `deck-images`
4. Check "Public bucket" (allows public read access)
5. Click "Create bucket"

## 6. Verify Setup

After setup, you should have:
- ✅ `decks` table in Database
- ✅ `daily_decks` table in Database
- ✅ `deck-images` bucket in Storage
- ✅ Environment variables configured

## Troubleshooting

### "Invalid API key" error
- Ensure you're using the **anon** key, not the service role key
- Check for extra spaces in the key

### "Permission denied" error
- Run the RLS policies from the schema SQL
- Ensure the storage bucket is set to public

### Images not loading
- Verify the bucket is public
- Check the image URL format: `https://project.supabase.co/storage/v1/object/public/deck-images/...`
