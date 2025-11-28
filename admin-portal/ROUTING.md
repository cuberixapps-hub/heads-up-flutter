# Admin Portal Routing

This admin portal uses React Router v6 for client-side routing. All routes are configured in `src/App.tsx`.

## Available Routes

### Main Routes

| Route | Component | Description |
|-------|-----------|-------------|
| `/` | DecksPage | Main deck management page - view, create, and edit regular game decks |
| `/daily` | DailyPage | Daily Heads Up deck management |
| `/ai-generator` | AIGeneratorPage | AI-powered deck generator using Claude/GPT |
| `/automated` | AutomatedPage | Automated deck generation with batch processing |
| `/image-test` | ImageTestPage | Test image generation APIs |
| `*` (404) | NotFoundPage | Fallback page for invalid routes |

## Project Structure

```
src/
├── App.tsx                    # Main app component with routing configuration
├── main.tsx                   # App entry point
├── components/
│   ├── Layout.tsx            # Shared layout with header and navigation
│   ├── DeckList.tsx          # Deck listing component
│   ├── DeckForm.tsx          # Deck creation/editing form
│   ├── DailyDeckManager.tsx  # Daily deck management
│   ├── AIDeckGenerator.tsx   # AI deck generation interface
│   ├── AutomatedDeckGenerator.tsx # Automated generation interface
│   └── ImageGeneratorTest.tsx # Image generation testing tool
├── pages/
│   ├── DecksPage.tsx         # Regular decks page
│   ├── DailyPage.tsx         # Daily decks page
│   ├── AIGeneratorPage.tsx   # AI generator page
│   ├── AutomatedPage.tsx     # Automated generation page
│   ├── ImageTestPage.tsx     # Image testing page
│   └── NotFoundPage.tsx      # 404 error page
├── services/                  # Business logic and API calls
├── styles/                    # Component styles
└── types/                     # TypeScript type definitions
```

## Navigation

The navigation is handled through the `Layout` component which wraps all routes. It provides:

- **Header**: Logo, app title, and Firebase connection status
- **Navigation Tabs**: Links to all main pages
- **Content Area**: Renders the active route component

Navigation uses `NavLink` components from React Router, which automatically apply the `active` class to the current route for visual indication.

## Route Features

### DecksPage (`/`)
- List view of all decks with search and filtering
- Create new deck button
- Edit existing decks (uses query params: `?mode=edit` or `?mode=create`)
- Form view for deck creation/editing
- Integrated with Firebase for real-time updates

### DailyPage (`/daily`)
- Manage daily featured decks
- Schedule future daily decks
- View historical daily deck performance
- Priority and date management

### AIGeneratorPage (`/ai-generator`)
- Generate deck content using AI (Claude or GPT)
- Topic selection and customization
- Country-specific content generation
- Image generation with DALL-E
- Real-time preview of generated content

### AutomatedPage (`/automated`)
- Batch deck generation
- Automated scheduling
- Multiple country support
- Progress tracking
- Research mode for topic validation

### ImageTestPage (`/image-test`)
- Test image generation APIs
- Preview generated images
- Debug image prompts
- Quality testing

## URL State Management

The `DecksPage` uses URL query parameters to manage form visibility:
- `?mode=create` - Shows the creation form
- `?mode=edit` - Shows the edit form with selected deck

This allows for:
- Direct linking to forms
- Browser back/forward navigation
- Bookmarkable states

## Adding New Routes

To add a new route:

1. Create a new page component in `src/pages/`:
```tsx
import React from 'react';

export const NewPage: React.FC = () => {
  return <div>New Page Content</div>;
};
```

2. Add the route in `src/App.tsx`:
```tsx
<Route path="new-page" element={<NewPage />} />
```

3. Add a navigation link in `src/components/Layout.tsx`:
```tsx
<NavLink to="/new-page" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
  <span className="tab-icon">🆕</span>
  New Page
</NavLink>
```

4. Export the page from `src/pages/index.ts`:
```tsx
export { NewPage } from './NewPage';
```

## Router Configuration

The app uses `BrowserRouter` for clean URLs without hash fragments. This requires server configuration for production deployments:

### Vite Dev Server
Already configured in `vite.config.ts` to handle SPA routing.

### Production Deployment
Server must redirect all requests to `index.html` to enable client-side routing.

**Firebase Hosting** (`firebase.json`):
```json
{
  "rewrites": [
    {
      "source": "**",
      "destination": "/index.html"
    }
  ]
}
```

**Nginx**:
```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

**Apache** (`.htaccess`):
```apache
RewriteEngine On
RewriteBase /
RewriteRule ^index\.html$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.html [L]
```

## Programmatic Navigation

Use the `useNavigate` hook to navigate programmatically:

```tsx
import { useNavigate } from 'react-router-dom';

function MyComponent() {
  const navigate = useNavigate();

  const handleClick = () => {
    navigate('/ai-generator');
  };

  return <button onClick={handleClick}>Go to AI Generator</button>;
}
```

## Link Components

Use `Link` or `NavLink` for navigation:

```tsx
import { Link, NavLink } from 'react-router-dom';

// Regular link
<Link to="/daily">Daily Decks</Link>

// Navigation link with active state
<NavLink 
  to="/ai-generator" 
  className={({ isActive }) => isActive ? 'active' : ''}
>
  AI Generator
</NavLink>
```

## Route Parameters

To add dynamic routes with parameters:

```tsx
// In App.tsx
<Route path="deck/:id" element={<DeckDetailPage />} />

// In component
import { useParams } from 'react-router-dom';

function DeckDetailPage() {
  const { id } = useParams();
  return <div>Deck ID: {id}</div>;
}
```

## Protected Routes

To add authentication guards:

```tsx
function ProtectedRoute({ children }) {
  const { user } = useAuth();
  
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  
  return children;
}

// In App.tsx
<Route path="admin" element={
  <ProtectedRoute>
    <AdminPage />
  </ProtectedRoute>
} />
```

## Development

Run the dev server:
```bash
npm run dev
```

The app will be available at `http://localhost:5173` (or next available port).

## Build

Build for production:
```bash
npm run build
```

Preview production build:
```bash
npm run preview
```




