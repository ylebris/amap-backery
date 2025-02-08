import React from 'react';
import { useTranslation } from 'react-i18next';
import { Languages } from 'lucide-react';
import toast from 'react-hot-toast';

export const LanguageSelector = () => {
  const { t, i18n } = useTranslation();

  const changeLanguage = (lng: string) => {
    i18n.changeLanguage(lng);
    toast.success(t('language.select'));
  };

  return (
    <div className="relative group">
      <button 
        className="flex items-center space-x-2 text-gray-600 hover:text-gray-900 rounded-md px-3 py-2 hover:bg-gray-100"
        aria-label={t('language.select')}
      >
        <Languages className="w-5 h-5" />
        <span className="text-sm font-medium">{i18n.language === 'fr' ? 'FR' : 'EN'}</span>
      </button>
      <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 hidden group-hover:block ring-1 ring-black ring-opacity-5">
        <button
          onClick={() => changeLanguage('fr')}
          className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 w-full text-left"
          aria-current={i18n.language === 'fr' ? 'true' : undefined}
        >
          {t('language.fr')}
        </button>
        <button
          onClick={() => changeLanguage('en')}
          className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 w-full text-left"
          aria-current={i18n.language === 'en' ? 'true' : undefined}
        >
          {t('language.en')}
        </button>
      </div>
    </div>
  );
};