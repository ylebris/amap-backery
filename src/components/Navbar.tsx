import React from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Heading as Bread, User, LogOut } from 'lucide-react';
import { useAuthStore } from '../stores/auth';
import { LanguageSelector } from './LanguageSelector';

export const Navbar = () => {
  const { t } = useTranslation();
  const { user, signOut } = useAuthStore();

  return (
    <nav className="bg-white shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <Link to="/" className="flex items-center">
              <Bread className="h-8 w-8 text-blue-500" />
              <span className="ml-2 text-xl font-bold text-gray-900">AMAP Manager</span>
            </Link>
          </div>

          <div className="flex items-center space-x-4">
            <LanguageSelector />
            
            <Link to="/profile" className="flex items-center text-gray-700 hover:text-gray-900">
              <User className="h-5 w-5" />
              <span className="ml-2 text-sm">{user?.email}</span>
            </Link>

            <button
              onClick={() => signOut()}
              className="flex items-center text-gray-700 hover:text-gray-900"
            >
              <LogOut className="h-5 w-5" />
              <span className="ml-2 text-sm">{t('common.logout')}</span>
            </button>
          </div>
        </div>
      </div>
    </nav>
  );
};