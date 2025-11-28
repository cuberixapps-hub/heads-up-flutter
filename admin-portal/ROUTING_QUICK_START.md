# Quick Start Guide - Routing System

This guide will help you quickly get started with the new routing system in the Heads Up Admin Portal.

## 🚀 What's New?

The admin portal now uses **React Router v6** for navigation. This means:

✅ Clean URLs (e.g., `/ai-generator` instead of tab states)  
✅ Browser back/forward buttons work  
✅ Bookmarkable pages  
✅ Direct links to specific sections  
✅ Better SEO potential  

## 📍 Available Routes

| URL | Page | What You Can Do |
|-----|------|-----------------|
| `/` | Regular Decks | View, create, edit, and delete game decks |
| `/daily` | Daily Heads Up | Schedule daily featured decks |
| `/ai-generator` | AI Generator | Generate decks using Claude or GPT |
| `/automated` | Automated | Batch generation and automation |
| `/image-test` | Image Test | Test image generation APIs |

## 🎯 Getting Started

### 1. Start the Dev Server

```bash
cd admin-portal
npm install  # if first time
npm run dev
```

The app will open at `http://localhost:5173`

### 2. Navigate the Portal

Click any tab at the top to navigate between pages:

```
🎮 Regular Decks  |  📅 Daily Heads Up  |  ✨ AI Generator  |  🤖 Automated  |  🧪 Image Test
```

The active tab is highlighted in purple gradient.

### 3. Use URLs Directly

You can now navigate directly to any page:

- `http://localhost:5173/` - Home (Regular Decks)
- `http://localhost:5173/ai-generator` - AI Generator
- `http://localhost:5173/daily` - Daily Decks

Copy and share these URLs with your team!

## 💡 Key Features

### Deep Linking
The Regular Decks page uses URL parameters for forms:

- `/?mode=create` - Create new deck form
- `/?mode=edit` - Edit existing deck form
- `/` - List view (default)

This means you can bookmark or share direct links to forms.

### Browser Navigation
- ⬅️ **Back button** - Goes to previous page
- ➡️ **Forward button** - Goes to next page
- 🔄 **Refresh** - Page stays on same route

### 404 Error Page
If you navigate to an invalid URL (like `/nonexistent`), you'll see a friendly 404 page with a "Back to Home" button.

## 🛠️ For Developers

### Adding a New Page

Want to add a new page? Here's the quick version:

1. **Create page component** in `src/pages/`:

```tsx
// src/pages/MyNewPage.tsx
export function MyNewPage() {
  return <div>My New Page Content</div>;
}
```

2. **Add route** in `src/App.tsx`:

```tsx
import { MyNewPage } from './pages/MyNewPage';

// In Routes:
<Route path="my-new-page" element={<MyNewPage />} />
```

3. **Add navigation link** in `src/components/Layout.tsx`:

```tsx
<NavLink to="/my-new-page" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
  <span className="tab-icon">🆕</span>
  My New Page
</NavLink>
```

Done! Your new page is accessible at `/my-new-page`.

### Using Router Hooks

**Navigate programmatically:**
```tsx
import { useNavigate } from 'react-router-dom';

function MyComponent() {
  const navigate = useNavigate();
  
  const goToAI = () => {
    navigate('/ai-generator');
  };
  
  return <button onClick={goToAI}>Go to AI Generator</button>;
}
```

**Read URL parameters:**
```tsx
import { useSearchParams } from 'react-router-dom';

function MyComponent() {
  const [searchParams] = useSearchParams();
  const mode = searchParams.get('mode'); // Get ?mode=create
  
  return <div>Mode: {mode}</div>;
}
```

**Create links:**
```tsx
import { Link } from 'react-router-dom';

<Link to="/daily">Go to Daily Decks</Link>
```

## 📱 Responsive Navigation

The navigation is fully responsive:

- **Desktop**: Horizontal tabs across the top
- **Tablet**: Wrapping tabs (2-3 per row)
- **Mobile**: Vertical stacked tabs

Try resizing your browser to see it in action!

## 🚢 Deployment

### Firebase Hosting

The app is ready to deploy to Firebase Hosting:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy
firebase deploy --only hosting
```

The `firebase.json` file is already configured with the necessary rewrites for SPA routing.

### Other Platforms

For Vercel or Netlify, just connect your GitHub repo and deploy. They automatically handle SPA routing.

## 🐛 Troubleshooting

### "Page not found" after refresh on production

**Problem**: Routes work during development but give 404 on production after refresh.

**Solution**: Ensure your hosting provider is configured for SPA routing:
- Firebase: Already configured via `firebase.json`
- Vercel/Netlify: Automatic, no config needed
- Custom server: Add catch-all route to serve `index.html`

### Navigation not working

**Problem**: Clicking navigation doesn't change pages.

**Solution**: 
1. Check browser console for errors
2. Ensure you're using `Link` or `NavLink` from React Router (not `<a>` tags)
3. Verify routes are defined in `App.tsx`

### Styles not loading on new pages

**Problem**: New pages don't have proper styling.

**Solution**: Import the CSS file in your page component:
```tsx
import '../styles/MyPage.css';
```

## 📚 Further Reading

- [ROUTING.md](./ROUTING.md) - Complete routing documentation
- [ROUTING_IMPLEMENTATION_SUMMARY.md](./ROUTING_IMPLEMENTATION_SUMMARY.md) - Technical details
- [React Router Docs](https://reactrouter.com/en/main) - Official documentation

## ✨ Next Steps

Now that you understand routing:

1. Explore each page in the admin portal
2. Try creating and editing decks on the Regular Decks page
3. Experiment with the AI Generator
4. Set up daily featured decks
5. Test automated generation workflows

Happy deck building! 🎮




