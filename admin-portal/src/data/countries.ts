// Comprehensive list of countries for deck generation
export interface Country {
  code: string;
  name: string;
  flag: string;
  region: string;
}

export const COUNTRIES: Country[] = [
  // Universal
  { code: 'UNIVERSAL', name: 'Universal', flag: '🌍', region: 'Global' },
  
  // North America
  { code: 'US', name: 'United States', flag: '🇺🇸', region: 'North America' },
  { code: 'CA', name: 'Canada', flag: '🇨🇦', region: 'North America' },
  { code: 'MX', name: 'Mexico', flag: '🇲🇽', region: 'North America' },
  
  // Europe
  { code: 'GB', name: 'United Kingdom', flag: '🇬🇧', region: 'Europe' },
  { code: 'FR', name: 'France', flag: '🇫🇷', region: 'Europe' },
  { code: 'DE', name: 'Germany', flag: '🇩🇪', region: 'Europe' },
  { code: 'ES', name: 'Spain', flag: '🇪🇸', region: 'Europe' },
  { code: 'IT', name: 'Italy', flag: '🇮🇹', region: 'Europe' },
  { code: 'PT', name: 'Portugal', flag: '🇵🇹', region: 'Europe' },
  { code: 'NL', name: 'Netherlands', flag: '🇳🇱', region: 'Europe' },
  { code: 'SE', name: 'Sweden', flag: '🇸🇪', region: 'Europe' },
  { code: 'NO', name: 'Norway', flag: '🇳🇴', region: 'Europe' },
  { code: 'DK', name: 'Denmark', flag: '🇩🇰', region: 'Europe' },
  { code: 'FI', name: 'Finland', flag: '🇫🇮', region: 'Europe' },
  { code: 'PL', name: 'Poland', flag: '🇵🇱', region: 'Europe' },
  { code: 'CH', name: 'Switzerland', flag: '🇨🇭', region: 'Europe' },
  { code: 'AT', name: 'Austria', flag: '🇦🇹', region: 'Europe' },
  { code: 'BE', name: 'Belgium', flag: '🇧🇪', region: 'Europe' },
  { code: 'GR', name: 'Greece', flag: '🇬🇷', region: 'Europe' },
  { code: 'IE', name: 'Ireland', flag: '🇮🇪', region: 'Europe' },
  
  // Asia
  { code: 'IN', name: 'India', flag: '🇮🇳', region: 'Asia' },
  { code: 'JP', name: 'Japan', flag: '🇯🇵', region: 'Asia' },
  { code: 'CN', name: 'China', flag: '🇨🇳', region: 'Asia' },
  { code: 'KR', name: 'South Korea', flag: '🇰🇷', region: 'Asia' },
  { code: 'TH', name: 'Thailand', flag: '🇹🇭', region: 'Asia' },
  { code: 'VN', name: 'Vietnam', flag: '🇻🇳', region: 'Asia' },
  { code: 'ID', name: 'Indonesia', flag: '🇮🇩', region: 'Asia' },
  { code: 'MY', name: 'Malaysia', flag: '🇲🇾', region: 'Asia' },
  { code: 'SG', name: 'Singapore', flag: '🇸🇬', region: 'Asia' },
  { code: 'PH', name: 'Philippines', flag: '🇵🇭', region: 'Asia' },
  { code: 'PK', name: 'Pakistan', flag: '🇵🇰', region: 'Asia' },
  { code: 'BD', name: 'Bangladesh', flag: '🇧🇩', region: 'Asia' },
  { code: 'TR', name: 'Turkey', flag: '🇹🇷', region: 'Asia' },
  { code: 'IL', name: 'Israel', flag: '🇮🇱', region: 'Asia' },
  { code: 'AE', name: 'UAE', flag: '🇦🇪', region: 'Asia' },
  { code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦', region: 'Asia' },
  
  // Oceania
  { code: 'AU', name: 'Australia', flag: '🇦🇺', region: 'Oceania' },
  { code: 'NZ', name: 'New Zealand', flag: '🇳🇿', region: 'Oceania' },
  
  // South America
  { code: 'BR', name: 'Brazil', flag: '🇧🇷', region: 'South America' },
  { code: 'AR', name: 'Argentina', flag: '🇦🇷', region: 'South America' },
  { code: 'CL', name: 'Chile', flag: '🇨🇱', region: 'South America' },
  { code: 'CO', name: 'Colombia', flag: '🇨🇴', region: 'South America' },
  { code: 'PE', name: 'Peru', flag: '🇵🇪', region: 'South America' },
  
  // Africa
  { code: 'ZA', name: 'South Africa', flag: '🇿🇦', region: 'Africa' },
  { code: 'NG', name: 'Nigeria', flag: '🇳🇬', region: 'Africa' },
  { code: 'KE', name: 'Kenya', flag: '🇰🇪', region: 'Africa' },
  { code: 'EG', name: 'Egypt', flag: '🇪🇬', region: 'Africa' },
  { code: 'MA', name: 'Morocco', flag: '🇲🇦', region: 'Africa' },
];

export const getCountryByCode = (code: string): Country | undefined => {
  return COUNTRIES.find(c => c.code === code);
};

export const getCountriesByRegion = (region: string): Country[] => {
  return COUNTRIES.filter(c => c.region === region);
};

export const getAllRegions = (): string[] => {
  return Array.from(new Set(COUNTRIES.map(c => c.region)));
};

