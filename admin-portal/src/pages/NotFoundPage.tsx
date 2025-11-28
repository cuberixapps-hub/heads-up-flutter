import { Link } from 'react-router-dom';
import '../styles/NotFoundPage.css';

export function NotFoundPage() {
  return (
    <div className="not-found-container">
      <div className="not-found-content">
        <h1 className="not-found-title">404</h1>
        <h2 className="not-found-subtitle">Page Not Found</h2>
        <p className="not-found-message">
          Oops! The page you're looking for doesn't exist.
        </p>
        <Link to="/" className="not-found-button">
          <span className="button-icon">🏠</span>
          Back to Home
        </Link>
      </div>
    </div>
  );
}

