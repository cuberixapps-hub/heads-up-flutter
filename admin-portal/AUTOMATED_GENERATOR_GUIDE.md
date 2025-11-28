# Automated Deck Generator - Setup Guide

## Overview

The **Automated Deck Generator** is a fully autonomous system that creates game decks without human intervention. It intelligently distributes content across countries and automatically selects topics, generates content using AI, and publishes decks to Firebase.

## Features

### 🤖 Fully Automated Process
- **Zero Human Intervention**: Once started, the system runs continuously until stopped
- **Toggle Control**: Simple start/stop button to control automation
- **Smart Delays**: Configurable delays between generations to avoid rate limits

### 🌍 Intelligent Country Distribution
- **56 Countries Supported**: Expanded from basic set to 56 countries across all continents
- **Equal Distribution**: Automatically selects countries with the lowest deck count
- **Regional Coverage**: 
  - North America (3 countries)
  - Europe (21 countries)
  - Asia (16 countries)
  - Oceania (2 countries)
  - South America (5 countries)
  - Africa (5 countries)
  - Universal (global content)

### 🎯 Diverse Topic Selection
- **156+ Topics**: Across 13 categories
- **Categories Include**:
  - Movies & TV (12 topics)
  - Food & Drink (12 topics)
  - Music (12 topics)
  - Animals & Nature (12 topics)
  - Sports & Fitness (12 topics)
  - Travel & Places (12 topics)
  - Science & Technology (12 topics)
  - Arts & Culture (12 topics)
  - Celebrities & Pop Culture (12 topics)
  - Games & Hobbies (12 topics)
  - History & Events (12 topics)
  - Kids & Family (12 topics)
  - Holidays & Celebrations (12 topics)

### 📊 Real-Time Statistics
- **Total Decks Created**: Track all automated generations
- **Country Coverage**: See how many countries have content
- **Success Rate**: Monitor generation success
- **Distribution Charts**: Visual representation of deck distribution
- **Live Activity Log**: Real-time updates of all operations

### 🎨 Modern UI
- Beautiful gradient designs
- Responsive layout for all screen sizes
- Real-time progress indicators
- Color-coded activity logs
- Interactive statistics dashboard

## Setup Instructions

### Prerequisites

1. **Node.js** (v16 or higher)
2. **Firebase Project** with Firestore enabled
3. **API Keys**:
   - Anthropic API Key (for content generation)
   - OpenAI API Key (optional, for image generation)

### Environment Variables

Create a `.env.local` file in the `admin-portal` directory:

```env
VITE_ANTHROPIC_API_KEY=your_anthropic_api_key_here
VITE_OPENAI_API_KEY=your_openai_api_key_here
```

### Installation

1. Navigate to the admin portal directory:
```bash
cd admin-portal
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm run dev
```

4. Open your browser to `http://localhost:5173`

## How to Use

### Starting Automation

1. Click on the **🤖 Automated** tab in the navigation
2. Verify that there are no API key warnings
3. (Optional) Adjust the delay between generations (default: 10 seconds)
4. Click the **"Start Automation"** button (green with play icon)
5. Watch as the system automatically:
   - Selects the optimal country
   - Chooses a random topic
   - Generates deck content with AI
   - Creates deck image (if available)
   - Publishes to Firebase
   - Repeats continuously

### Stopping Automation

1. Click the **"Stop Automation"** button (red with pause icon)
2. The current generation will complete
3. No new generations will start

### Monitoring Progress

- **Current Generation Status**: Shows real-time progress of the current deck being created
- **Statistics Dashboard**: 4 key metrics displayed prominently
- **Country Distribution**: Top 10 countries with visual progress bars
- **Activity Log**: Scrollable log of all operations with timestamps

## Configuration Options

### Delay Between Generations

- **Default**: 10 seconds
- **Range**: 5-300 seconds
- **Purpose**: Prevents API rate limits and allows time for each generation to complete

### Future Configuration Options (Easy to Add)

You can extend the `AutomationConfig` interface in `automationService.ts` to add:

- **Preferred Regions**: Focus on specific geographic regions
- **Skip Countries**: Exclude certain countries from automation
- **Max Concurrent Generations**: Run multiple generations simultaneously
- **Topic Categories**: Focus on specific topic categories
- **Premium Content**: Toggle premium vs. free content generation

## Architecture

### Key Files

1. **`src/components/AutomatedDeckGenerator.tsx`**
   - Main React component
   - UI and user interactions
   - State management for automation

2. **`src/services/automationService.ts`**
   - Core automation logic
   - Country selection algorithm
   - Statistics calculation
   - Deck generation orchestration

3. **`src/data/countries.ts`**
   - 56 countries with flags and regions
   - Country lookup utilities
   - Regional filtering

4. **`src/data/topics.ts`**
   - 156+ topics across 13 categories
   - Random topic selection
   - Topic filtering by category

5. **`src/styles/AutomatedDeckGenerator.css`**
   - Modern, responsive styling
   - Gradient designs
   - Animation effects

### Data Flow

```
User Clicks "Start"
    ↓
Automation Loop Begins
    ↓
Select Country (lowest deck count)
    ↓
Select Random Topic
    ↓
Generate Content (AI - Claude)
    ↓
Generate Image (AI - DALL-E)
    ↓
Save to Firebase
    ↓
Update Statistics
    ↓
Wait (configurable delay)
    ↓
Repeat Until Stopped
```

### Country Selection Algorithm

1. **Fetch Current Distribution**: Get deck counts for all countries from Firebase
2. **Filter Available Countries**: Apply any regional or skip filters
3. **Find Minimum Count**: Identify countries with the fewest decks
4. **Random Selection**: Randomly pick from countries with minimum count
5. **Result**: Ensures equal distribution across all countries over time

## Statistics

### What's Tracked

- **Total Automated Decks**: Count of all decks created by automation
- **Country Distribution**: Breakdown of decks per country
- **Last Generation Time**: When the most recent deck was created
- **Success Rate**: Percentage of successful generations

### How It Works

Statistics are calculated in real-time by querying Firebase for decks with the `automatedGeneration: true` flag. The country distribution is visualized with progress bars showing relative percentages.

## Troubleshooting

### "Missing API keys" Error

**Solution**: Add your Anthropic API key to `.env.local`:
```env
VITE_ANTHROPIC_API_KEY=your_key_here
```

### Automation Stops Unexpectedly

**Possible Causes**:
1. API rate limit reached
2. Network connectivity issues
3. Invalid API key

**Solution**: 
- Check the activity log for error messages
- Verify API key is valid
- Increase delay between generations
- Restart automation

### Image Generation Fails

**Note**: The system continues without images if generation fails. This is expected behavior when:
- OpenAI API key is missing
- Rate limits are reached
- Image generation service is unavailable

**Solution**: Add OpenAI API key to `.env.local` if you want images

### Firebase Permission Denied

**Solution**: Ensure your Firebase security rules allow writes to the `decks` collection

## Best Practices

### Recommended Settings

- **Delay**: 10-30 seconds for reliable operation
- **API Keys**: Use both Anthropic and OpenAI for full features
- **Monitoring**: Check activity log regularly for errors
- **Database**: Ensure sufficient Firebase storage quota

### Production Use

1. **Use Production API Keys**: Not development/test keys
2. **Monitor Costs**: AI API calls incur costs per generation
3. **Set Rate Limits**: Configure delays to stay within API quotas
4. **Backup Database**: Regular backups of Firebase data
5. **Monitor Logs**: Set up Firebase monitoring for errors

## Future Enhancements

### Potential Features

1. **Scheduling**: Run automation at specific times
2. **Batch Processing**: Generate multiple decks at once
3. **Quality Control**: AI review of generated content
4. **A/B Testing**: Generate variants for testing
5. **Analytics Integration**: Track deck performance
6. **Custom Prompts**: Template system for content generation
7. **Multi-Language**: Generate decks in different languages
8. **Content Moderation**: Automatic filtering of inappropriate content

### Performance Optimizations

1. **Caching**: Cache AI responses for similar topics
2. **Parallel Generation**: Multiple concurrent generations
3. **Smart Queuing**: Priority-based generation queue
4. **Incremental Updates**: Update stats less frequently

## Support

### Common Questions

**Q: How long does each generation take?**
A: Typically 10-30 seconds depending on AI response time

**Q: Can I run this 24/7?**
A: Yes, but monitor API costs and rate limits

**Q: What happens if I close the browser?**
A: Automation stops. It only runs while the page is open

**Q: Can I edit auto-generated decks?**
A: Yes, they appear in the regular decks list and can be edited

**Q: How many countries are supported?**
A: 56 countries plus Universal (global) content

**Q: How many topics are available?**
A: 156+ topics across 13 categories

## Credits

- **AI Content Generation**: Anthropic Claude
- **AI Image Generation**: OpenAI DALL-E 3
- **Database**: Google Firebase Firestore
- **UI Icons**: Lucide React
- **Framework**: React + TypeScript + Vite

---

## Quick Start Checklist

- [ ] Install dependencies (`npm install`)
- [ ] Add API keys to `.env.local`
- [ ] Start dev server (`npm run dev`)
- [ ] Navigate to Automated tab
- [ ] Click "Start Automation"
- [ ] Monitor the activity log
- [ ] Watch statistics grow!

---

**Built with ❤️ for Heads Up! Game**

