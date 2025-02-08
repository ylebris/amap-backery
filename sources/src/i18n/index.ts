import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';
import { fr } from './locales/fr';
import { en } from './locales/en';
import { format } from 'date-fns';
import { fr as dateFnsFr, enUS as dateFnsEn } from 'date-fns/locale';

// Fonction pour formater les dates selon la locale
const formatDate = (date: Date, formatStr: string = 'PP'): string => {
  const locale = i18n.language === 'fr' ? dateFnsFr : dateFnsEn;
  return format(date, formatStr, { locale });
};

// Fonction pour formater les nombres
const formatNumber = (number: number): string => {
  return new Intl.NumberFormat(i18n.language).format(number);
};

// Fonction pour formater les devises
const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat(i18n.language, {
    style: 'currency',
    currency: 'EUR',
  }).format(amount);
};

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      fr: {
        translation: fr,
      },
      en: {
        translation: en,
      },
    },
    fallbackLng: 'fr',
    interpolation: {
      escapeValue: false,
    },
  });

export { formatDate, formatNumber, formatCurrency };
export default i18n;