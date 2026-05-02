/**
 * freshDataService.ts
 *
 * Fetches live, current web data via the OpenAI `web_search_preview` built-in tool
 * so that meme/trending decks contain 2026-accurate cards rather than stale
 * training-cutoff content.
 *
 * The caller receives a plain string summary that can be injected verbatim into
 * the deck-generation prompt as grounding context.
 */

import { getOpenAIClient, withRetry } from './aiConfig';

export interface FreshDataResult {
  summary: string;           // Grounding text for the generation prompt
  retrievedAt: Date;         // Timestamp of the fetch
  searchQueries: string[];   // What we searched for
}

/**
 * Returns true for topics that benefit from fresh web data.
 * Extend this list freely.
 */
export const topicNeedsFreshData = (topic: string): boolean => {
  const lower = topic.toLowerCase();
  const triggers = [
    'meme', 'memes', 'viral', 'trending', 'tiktok', 'reels', 'internet',
    '2025', '2026', 'current', 'latest', 'new', 'recent',
  ];
  return triggers.some(t => lower.includes(t));
};

/**
 * Fetch fresh web data for a given deck topic using OpenAI's web_search_preview
 * built-in tool.  Returns structured grounding context.
 */
export const fetchFreshData = async (topic: string): Promise<FreshDataResult> => {
  console.log(`🌐 Fetching fresh web data for topic: "${topic}"`);

  const openai = getOpenAIClient();
  const retrievedAt = new Date();

  const queries = buildSearchQueries(topic);

  const systemPrompt = [
    'You are a research assistant helping to build a Heads Up! party game deck.',
    'Use the web_search_preview tool to look up current (2026) information about the topic.',
    'Then summarise the MOST VIRAL / TRENDING / RECOGNISABLE items in bullet form.',
    'Be specific – include real names, titles, handles, or phrases that are widely known right now.',
    'Format: one bullet per item, no headers, plain text.',
  ].join(' ');

  const userPrompt = `Research these queries about "${topic}" and list the top 30 currently trending/viral items:
${queries.map(q => `- ${q}`).join('\n')}

Return each item as a short bullet, e.g.:
- Skibidi Toilet
- NPC streaming trend
- "We did it Joe" meme
...`;

  try {
    const response = await withRetry(async () =>
      openai.responses.create({
        model: 'gpt-4.1',
        tools: [{ type: 'web_search_preview' }],
        input: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      })
    );

    // gpt-4.1 Responses API — extract output_text
    const summary = (response as any).output_text?.trim() ?? '';

    if (!summary) {
      throw new Error('Empty response from web_search_preview');
    }

    console.log(`✅ Fresh web data retrieved (${summary.split('\n').length} lines)`);
    return { summary, retrievedAt, searchQueries: queries };

  } catch (err: unknown) {
    // Fallback: generate without web search but still return a timestamp
    const msg = err instanceof Error ? err.message : String(err);
    console.warn(`⚠️ web_search_preview failed (${msg}), falling back to no-search path`);

    const fallbackSummary = [
      `Current trending items related to "${topic}" (fallback – no live search):`,
      '- Refer to AI training knowledge for recent memes and viral content.',
    ].join('\n');

    return { summary: fallbackSummary, retrievedAt, searchQueries: queries };
  }
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const buildSearchQueries = (topic: string): string[] => {
  const year = new Date().getFullYear();
  return [
    `${topic} ${year} viral trends`,
    `most popular ${topic} ${year}`,
    `top ${topic} internet culture ${year}`,
  ];
};
