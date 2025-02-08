import React from 'react';
import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Home, Users, ShoppingBag, Settings } from 'lucide-react';

const NavItem = ({ to, icon: Icon, children }: { to: string; icon: React.ElementType; children: React.ReactNode }) => (
  <NavLink
    to={to}
    className={({ isActive }) => `
      flex items-center px-4 py-2 text-sm font-medium rounded-md
      ${isActive
        ? 'bg-blue-50 text-blue-700'
        : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
      }
    `}
  >
    <Icon className="mr-3 h-5 w-5" />
    {children}
  </NavLink>
);

export const Sidebar = () => {
  const { t } = useTranslation();

  return (
    <div className="w-64 flex-shrink-0 bg-white border-r border-gray-200">
      <div className="h-full px-3 py-4">
        <nav className="space-y-1">
          <NavItem to="/" icon={Home}>
            {t('nav.dashboard')}
          </NavItem>
          <NavItem to="/amaps" icon={Users}>
            {t('nav.amaps')}
          </NavItem>
          <NavItem to="/orders" icon={ShoppingBag}>
            {t('nav.orders')}
          </NavItem>
          <NavItem to="/profile" icon={Settings}>
            {t('nav.profile')}
          </NavItem>
        </nav>
      </div>
    </div>
  );
};