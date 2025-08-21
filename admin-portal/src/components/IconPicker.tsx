import React, { useState, useEffect } from 'react';
import { X, Search } from 'lucide-react';
import { iconCategories, IconInfo } from '../data/icons';
import '../styles/IconPicker.css';

interface IconPickerProps {
    selectedIcon: IconInfo | null;
    onSelectIcon: (icon: IconInfo) => void;
    onClose: () => void;
}

export const IconPicker: React.FC<IconPickerProps> = ({
    selectedIcon,
    onSelectIcon,
    onClose,
}) => {
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedCategory, setSelectedCategory] = useState('All');
    const [previewIcon, setPreviewIcon] = useState<IconInfo | null>(selectedIcon);

    const getFilteredIcons = () => {
        let icons: IconInfo[] = [];

        if (selectedCategory === 'All') {
            icons = iconCategories.flatMap(cat => cat.icons);
        } else {
            const category = iconCategories.find(cat => cat.name === selectedCategory);
            icons = category ? category.icons : [];
        }

        if (searchQuery) {
            icons = icons.filter(icon =>
                icon.name.toLowerCase().includes(searchQuery.toLowerCase())
            );
        }

        return icons;
    };

    const handleSelectIcon = (icon: IconInfo) => {
        setPreviewIcon(icon);
    };

    const handleConfirm = () => {
        if (previewIcon) {
            onSelectIcon(previewIcon);
            onClose();
        }
    };

    useEffect(() => {
        const handleEscape = (e: KeyboardEvent) => {
            if (e.key === 'Escape') {
                onClose();
            }
        };
        document.addEventListener('keydown', handleEscape);
        return () => document.removeEventListener('keydown', handleEscape);
    }, [onClose]);

    const filteredIcons = getFilteredIcons();

    return (
        <div className="icon-picker-overlay">
            <div className="icon-picker-modal">
                <div className="icon-picker-header">
                    <h2>Choose Icon</h2>
                    <button className="close-button" onClick={onClose}>
                        <X size={24} />
                    </button>
                </div>

                <div className="icon-picker-search">
                    <Search size={20} className="search-icon" />
                    <input
                        type="text"
                        placeholder="Search icons..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="search-input"
                    />
                </div>

                <div className="icon-picker-categories">
                    <button
                        className={`category-chip ${selectedCategory === 'All' ? 'active' : ''}`}
                        onClick={() => setSelectedCategory('All')}
                    >
                        All
                    </button>
                    {iconCategories.map(category => (
                        <button
                            key={category.name}
                            className={`category-chip ${selectedCategory === category.name ? 'active' : ''}`}
                            onClick={() => setSelectedCategory(category.name)}
                        >
                            {category.name}
                        </button>
                    ))}
                </div>

                <div className="icon-picker-grid">
                    {filteredIcons.map((iconInfo, index) => {
                        const Icon = iconInfo.icon;
                        const isSelected = previewIcon?.name === iconInfo.name;

                        return (
                            <button
                                key={`${iconInfo.name}-${index}`}
                                className={`icon-item ${isSelected ? 'selected' : ''}`}
                                onClick={() => handleSelectIcon(iconInfo)}
                                title={iconInfo.name}
                            >
                                <Icon size={24} />
                            </button>
                        );
                    })}
                </div>

                <div className="icon-picker-footer">
                    <div className="preview-section">
                        <div className="preview-icon-container">
                            {previewIcon && React.createElement(previewIcon.icon, { size: 32 })}
                        </div>
                        <div className="preview-info">
                            <span className="preview-label">Selected Icon</span>
                            <span className="preview-name">{previewIcon?.name || 'None'}</span>
                        </div>
                    </div>
                    <div className="action-buttons">
                        <button className="cancel-button" onClick={onClose}>
                            Cancel
                        </button>
                        <button
                            className="select-button"
                            onClick={handleConfirm}
                            disabled={!previewIcon}
                        >
                            Select Icon
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};
