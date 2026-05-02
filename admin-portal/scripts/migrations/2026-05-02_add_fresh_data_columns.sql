-- Migration: 2026-05-02_add_fresh_data_columns
-- Adds columns to track whether a deck was generated with live web-fetched data.

ALTER TABLE decks ADD COLUMN IF NOT EXISTS used_fresh_data BOOLEAN DEFAULT FALSE;
ALTER TABLE decks ADD COLUMN IF NOT EXISTS fresh_data_retrieved_at TIMESTAMPTZ;
