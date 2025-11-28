# Heads Up! Admin Portal

A React TypeScript admin dashboard for managing game decks in the Heads Up! Flutter app. This portal provides a web interface to create, edit, and manage decks that sync in real-time with the mobile app through Firebase Firestore.

## Features

### 🎯 Core Features

- **Real-time Sync**: All changes sync instantly with the Flutter app via Firebase
- **Icon Selection**: Choose from 150+ categorized icons for each deck
- **Color Customization**: Select from predefined colors for deck themes
- **Card Management**: Add, remove, and organize cards within decks
- **AI Suggestions**: Get AI-powered card suggestions for your decks
- **Search & Filter**: Quickly find decks with powerful search functionality
- **Premium Decks**: Mark decks as premium for in-app purchases
- **Multi-Page Navigation**: Clean routing with React Router for seamless navigation

### 📄 Available Pages

The admin portal includes multiple pages accessible through the navigation bar:

- **Regular Decks** (`/`) - Manage game decks (create, edit, delete)
- **Daily Heads Up** (`/daily`) - Schedule and manage daily featured decks
- **AI Generator** (`/ai-generator`) - Generate decks using AI (Claude/GPT)
- **Automated** (`/automated`) - Batch generation and automated scheduling
- **Image Test** (`/image-test`) - Test and preview image generation APIs

See [ROUTING.md](./ROUTING.md) for detailed routing documentation.

### 🎨 Icon Categories

The icon picker includes icons organized into categories:

- Games (dice, gamepad, chess, puzzles)
- Sports (football, basketball, tennis, golf)
- Entertainment (music, movies, TV, theater)
- Food (burger, pizza, coffee, restaurant)
- Animals (dog, cat, pets, wildlife)
- Nature (trees, weather, elements)
- Objects (stars, hearts, trophies, medals)
- Tech (devices, gadgets, connectivity)
- Education (books, science, learning)
- Travel (vehicles, transportation)
- Miscellaneous (flags, art, magic)

## Setup

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Firebase project with Firestore enabled
- Same Firebase project as the Flutter app

### Installation

1. Install dependencies:

```bash
npm install
```

2. Configure Firebase:

   - Go to Firebase Console
   - Add a web app to your project
   - Copy the web app configuration
   - Update `src/config/firebase.ts` with your config

3. Run the development server:

```bash
npm run dev
```

The portal will be available at `http://localhost:5173`

## Usage

### Navigation

The admin portal uses a tabbed navigation system at the top:

- **Regular Decks** - Main deck management page
- **Daily Heads Up** - Schedule daily featured decks
- **AI Generator** - Generate decks using AI
- **Automated** - Batch generation tools
- **Image Test** - Test image generation

Click any tab to navigate to that page. The active tab is highlighted in purple.

### Creating a Deck

1. Go to the **Regular Decks** page (home)
2. Click the "Create Deck" button
3. Enter deck information:
   - **Name**: Unique deck name
   - **Description**: Optional deck description
   - **Premium**: Toggle for premium status
   - **Country**: Select target country (optional)
4. Customize appearance:
   - Click "Change Icon" to open the icon picker
   - Click "Change Color" to select a theme color
5. Add cards:
   - Type card text and press Enter or click +
   - Use "AI Suggestions" for inspiration
   - Minimum 5 cards required
6. Click "Save" to create the deck

### Using AI Generator

1. Navigate to **AI Generator** tab
2. Select a topic or enter a custom one
3. Choose target country
4. Click "Generate Deck" to create AI-powered content
5. Review and edit generated cards
6. Save to Firebase when satisfied

### Automated Generation

1. Navigate to **Automated** tab
2. Configure batch generation settings
3. Select multiple topics and countries
4. Run automated generation
5. Review and publish generated decks

### Icon Selection

When creating or editing a deck:

1. Click "Change Icon" button
2. Browse icons by category or search
3. Click an icon to preview
4. Click "Select Icon" to confirm

The selected icon will:

- Display in the deck list
- Show in the Flutter app
- Be stored with proper font family and code point for cross-platform compatibility

### Managing Existing Decks

- **Edit**: Click the edit button to modify deck details
- **Duplicate**: Create a copy of an existing deck
- **Delete**: Remove a deck (with confirmation)
- **Search**: Use the search bar to find specific decks

## Firebase Structure

The admin portal uses the same Firestore structure as the Flutter app:

```
firestore/
├── decks/                    # Default game decks
│   └── {deckId}/
│       ├── name              # Deck name
│       ├── description       # Deck description
│       ├── iconCodePoint     # Icon code point (e.g., 0xf005)
│       ├── iconFontFamily    # Font family (e.g., 'FontAwesomeIcons')
│       ├── iconFontPackage   # Optional font package
│       ├── colorValue        # Color as integer (e.g., 0xFF9C27B0)
│       ├── isPremium         # Premium status
│       ├── cards[]           # Array of card strings
│       ├── createdAt         # Creation timestamp
│       └── updatedAt         # Last update timestamp
```

## Icon System

The icon system is designed to work seamlessly between the React admin portal and Flutter app:

### Admin Portal (React)

- Uses `react-icons` library
- Icons are displayed using React components
- Stores icon metadata (codePoint, fontFamily) in Firestore

### Flutter App

- Uses `font_awesome_flutter` and Material Icons
- Reconstructs icons from metadata:
  ```dart
  IconData(
    iconCodePoint,
    fontFamily: iconFontFamily,
    fontPackage: iconFontPackage
  )
  ```

### Supported Icon Libraries

- FontAwesome icons (mapped to `FontAwesomeIcons`)
- Material icons (mapped to `MaterialIcons`)

## Development

### Project Structure

```
admin-portal/
├── src/
│   ├── pages/                # Page components (routes)
│   │   ├── DecksPage.tsx     # Regular decks management
│   │   ├── DailyPage.tsx     # Daily deck scheduling
│   │   ├── AIGeneratorPage.tsx  # AI deck generator
│   │   ├── AutomatedPage.tsx # Automated generation
│   │   ├── ImageTestPage.tsx # Image testing
│   │   └── NotFoundPage.tsx  # 404 error page
│   ├── components/
│   │   ├── Layout.tsx        # Shared layout with navigation
│   │   ├── DeckList.tsx      # Deck list view
│   │   ├── DeckForm.tsx      # Create/edit deck form
│   │   ├── DailyDeckManager.tsx  # Daily deck management
│   │   ├── AIDeckGenerator.tsx   # AI generation interface
│   │   ├── AutomatedDeckGenerator.tsx  # Automation interface
│   │   └── IconPicker.tsx    # Icon selection modal
│   ├── config/
│   │   └── firebase.ts       # Firebase configuration
│   ├── data/
│   │   └── icons.ts          # Icon categories and mappings
│   ├── services/             # Business logic and API calls
│   │   ├── aiContentService.ts   # AI content generation
│   │   ├── aiImageService.ts     # AI image generation
│   │   └── automationService.ts  # Automation logic
│   ├── styles/               # Component styles
│   │   ├── Layout.css        # Layout styles
│   │   ├── DeckList.css      # Deck list styles
│   │   └── ...
│   └── App.tsx               # Main application with routing
├── ROUTING.md                # Routing documentation
└── ROUTING_IMPLEMENTATION_SUMMARY.md  # Implementation details
```

### Building for Production

```bash
npm run build
```

The built files will be in the `dist/` directory.

### Deployment

You can deploy the admin portal to:

- Firebase Hosting (recommended)
- Vercel
- Netlify
- Any static hosting service

#### Firebase Hosting Deployment

The project is configured for Firebase Hosting with proper routing support:

```bash
npm install -g firebase-tools
firebase init hosting
# Select your project
# Set public directory to: dist
# Configure as single-page app: Yes
# Set up automatic builds with GitHub: Optional
firebase deploy
```

The `firebase.json` configuration already includes the necessary rewrite rules for client-side routing:

```json
{
  "hosting": {
    "public": "dist",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

This ensures all routes (like `/ai-generator`, `/daily`) work correctly when deployed.

#### Other Hosting Services

For Vercel/Netlify, the app works out of the box as they automatically handle SPA routing.

## Security

- The portal uses Firebase anonymous authentication by default
- For production, implement proper authentication:
  - Email/password authentication
  - Google Sign-In
  - Role-based access control
- Add Firebase Security Rules to protect your data

## Troubleshooting

### Icons not showing in Flutter app

- Ensure iconCodePoint and iconFontFamily are correctly stored
- Verify the Flutter app has the required icon packages installed
- Check that font families match between platforms

### Firebase connection issues

- Verify Firebase configuration in `src/config/firebase.ts`
- Check Firebase project settings
- Ensure Firestore is enabled in Firebase Console

### Real-time sync not working

- Check network connectivity
- Verify Firebase rules allow read/write access
- Ensure both admin portal and Flutter app use the same Firebase project

## Future Enhancements

- [ ] Bulk import/export of decks
- [ ] Deck analytics and usage statistics
- [ ] Image upload for custom deck covers
- [ ] Multi-language support
- [ ] Deck categories and tags
- [ ] Version history and rollback
- [ ] Collaborative deck editing
- [ ] Advanced AI integration for card generation

## License

This admin portal is part of the Heads Up! game project.
