# Admin Portal Setup Instructions

## ✅ Current Status

The admin portal is set up and ready to use! All import issues have been fixed.

## 🚀 How to Run

1. **Start the development server:**

```bash
cd admin-portal
npm run dev
```

2. **Access the portal:**
   Open your browser and go to: http://localhost:5173

## 🔧 Fixed Issues

1. ✅ Fixed `IconType` import issue by defining it locally
2. ✅ Fixed `IconInfo` export/import with proper TypeScript type exports
3. ✅ Fixed Firebase `User` type import issue
4. ✅ Cleared Vite cache for clean build
5. ✅ Updated Firebase config with placeholder web app ID

## 📋 Features Working

- ✅ Anonymous authentication with Firebase
- ✅ Real-time deck synchronization with Firestore
- ✅ Icon picker with 150+ categorized icons
- ✅ Color selection for deck themes
- ✅ Card management (add/remove/organize)
- ✅ Deck CRUD operations (Create, Read, Update, Delete)
- ✅ Search and filter functionality
- ✅ Premium deck toggle
- ✅ AI suggestions for cards

## 🔗 Firebase Setup

The portal is configured to use your existing Firebase project:

- Project ID: `heads-up-game-48f14`
- Uses anonymous authentication by default
- Syncs with the same Firestore database as your Flutter app

## 📝 Important Notes

1. **Node.js Version Warning**: You may see a warning about Node.js version. This can be safely ignored as the app works fine with Node.js 20.18.0.

2. **Firebase Web App ID**: The portal uses a placeholder web app ID. For production, you should:

   - Go to Firebase Console
   - Add a web app to your project
   - Replace the `appId` in `src/config/firebase.ts`

3. **Icon System**: Icons selected in the admin portal are stored with metadata (codePoint and fontFamily) to ensure compatibility with the Flutter app.

## 🎨 Using the Admin Portal

1. **Create a Deck:**

   - Click "Create Deck"
   - Enter deck name and description
   - Click "Change Icon" to select from categorized icons
   - Click "Change Color" to select theme color
   - Add at least 5 cards
   - Toggle premium status if needed
   - Click "Save"

2. **Edit a Deck:**

   - Click the edit button on any deck
   - Modify any details
   - Click "Save"

3. **Delete a Deck:**

   - Click the delete button on any deck
   - Confirm deletion

4. **Search Decks:**
   - Use the search bar to find decks by name, description, or card content

## 🐛 Troubleshooting

If you encounter any issues:

1. **Clear Vite cache:**

```bash
rm -rf node_modules/.vite
npm run dev
```

2. **Reinstall dependencies:**

```bash
rm -rf node_modules
npm install
npm run dev
```

3. **Check Firebase connection:**
   - Ensure your Firebase project is active
   - Check that Firestore is enabled in Firebase Console

## ✨ Success!

The admin portal is now fully functional and ready to manage your Heads Up! game decks. All changes will sync in real-time with your Flutter app!





