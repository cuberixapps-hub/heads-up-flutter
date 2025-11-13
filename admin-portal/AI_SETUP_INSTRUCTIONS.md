# AI Setup Instructions for Admin Portal

## 1. Create Environment File

Since `.env.local` files are protected, you'll need to manually create it:

1. Navigate to the `admin-portal` directory
2. Create a new file named `.env.local`
3. Add the following content:

```env
# AI Service API Keys
VITE_OPENAI_API_KEY=your_actual_openai_api_key
VITE_ANTHROPIC_API_KEY=your_actual_anthropic_api_key

# AI Configuration
VITE_AI_IMAGE_PROVIDER=openai
```

## 2. Get API Keys

### OpenAI API Key (for DALL-E 3 image generation):
1. Go to https://platform.openai.com/api-keys
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the key and replace `your_actual_openai_api_key` in `.env.local`

### Anthropic API Key (for Claude content generation):
1. Go to https://console.anthropic.com/
2. Sign in or create an account
3. Navigate to API keys section
4. Create a new key
5. Copy the key and replace `your_actual_anthropic_api_key` in `.env.local`

## 3. Test the Integration

1. Start the admin portal:
   ```bash
   cd admin-portal
   npm run dev
   ```

2. Open http://localhost:5173 in your browser

3. Test AI features:
   - **AI Generator Tab**: Enter a topic and generate a complete deck
   - **Manual Deck Creation**: Use AI Assist button for card suggestions and image generation

## 4. Features Available

### AI Generator Tab
- Enter any topic (e.g., "80s Movies", "Italian Cuisine", "Superheroes")
- AI generates:
  - Deck name and description
  - 10-20 relevant cards
  - Custom cover image using DALL-E 3
  - Appropriate tags and metadata
- Preview the deck before saving
- Edit generated content if needed

### AI Assist in Deck Form
- **AI Suggestions Button**: Generates card suggestions using Claude
- **AI Generate Button** (in image section): Creates custom deck image
- Fallback to hardcoded suggestions if AI is unavailable

## 5. Troubleshooting

### If you see API key warnings:
- Double-check your `.env.local` file exists and contains valid keys
- Restart the dev server after adding keys
- Make sure keys are not surrounded by quotes

### If AI generation fails:
- Check browser console for specific error messages
- Verify API keys are valid and have sufficient credits
- The system will fallback to default behavior if AI is unavailable

## 6. Cost Considerations

- **OpenAI (DALL-E 3)**: ~$0.04-0.08 per image
- **Anthropic (Claude)**: ~$0.01-0.02 per deck content generation

Consider implementing rate limiting or usage tracking for production use.

## 7. Security Note

For production deployment:
- Never commit `.env.local` to git
- Consider using a backend API to proxy AI requests
- Implement proper authentication and rate limiting
- Store API keys securely (e.g., environment variables on server)

