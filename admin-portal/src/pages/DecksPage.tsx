import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { DeckList } from '../components/DeckList';
import { DeckForm } from '../components/DeckForm';

interface Deck {
  id?: string;
  name: string;
  description: string;
  cards: string[];
  iconCodePoint: number;
  iconFontFamily: string;
  iconFontPackage?: string;
  colorValue: number;
  imageUrl?: string;
  isPremium: boolean;
  country?: string;
  tags?: string[];
  priority?: number;
  isActive?: boolean;
  createdAt?: any;
  updatedAt?: any;
  translations?: {
    [languageCode: string]: {
      name: string;
      description: string;
      cards?: string[];
    };
  };
}

export function DecksPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [editingDeck, setEditingDeck] = useState<Deck | undefined>(undefined);
  
  // Check if we're in edit mode based on URL params
  const isEditing = searchParams.get('mode') === 'edit';
  const isCreating = searchParams.get('mode') === 'create';
  const showForm = isEditing || isCreating;

  const handleEdit = (deck: Deck) => {
    setEditingDeck(deck);
    navigate('?mode=edit');
  };

  const handleCreate = () => {
    setEditingDeck(undefined);
    navigate('?mode=create');
  };

  const handleSave = () => {
    setEditingDeck(undefined);
    navigate('/');
  };

  const handleCancel = () => {
    setEditingDeck(undefined);
    navigate('/');
  };

  return (
    <>
      {showForm ? (
        <DeckForm
          deck={editingDeck}
          onSave={handleSave}
          onCancel={handleCancel}
        />
      ) : (
        <DeckList onEdit={handleEdit} onCreate={handleCreate} />
      )}
    </>
  );
}

