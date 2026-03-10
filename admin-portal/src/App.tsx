import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { DecksPage } from './pages/DecksPage';
import { DailyPage } from './pages/DailyPage';
import { AIGeneratorPage } from './pages/AIGeneratorPage';
import { AutomatedPage } from './pages/AutomatedPage';
import { ImageTestPage } from './pages/ImageTestPage';
import { InitialDecksPage } from './pages/InitialDecksPage';
import { NotFoundPage } from './pages/NotFoundPage';
import './App.css';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<DecksPage />} />
          <Route path="daily" element={<DailyPage />} />
          <Route path="ai-generator" element={<AIGeneratorPage />} />
          <Route path="automated" element={<AutomatedPage />} />
          <Route path="initial-decks" element={<InitialDecksPage />} />
          <Route path="image-test" element={<ImageTestPage />} />
          <Route path="*" element={<NotFoundPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
