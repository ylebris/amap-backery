import React from 'react';
import { Shield, Heading as Bread, Users, Calendar, ShoppingCart } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { LanguageSelector } from './components/LanguageSelector';
import { Toaster } from 'react-hot-toast';
import { formatDate, formatNumber, formatCurrency } from './i18n';

// Types pour les rôles utilisateur
type UserRole = 'super_admin' | 'amap_admin' | 'member' | 'baker';

// Composant pour les cartes de statistiques
const StatCard = ({ title, value, icon: Icon }: { title: string; value: string | number; icon: React.ElementType }) => (
  <div className="bg-white rounded-lg shadow-md p-6">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-gray-500 text-sm font-medium">{title}</p>
        <p className="text-2xl font-bold mt-2">{typeof value === 'number' ? formatNumber(value) : value}</p>
      </div>
      <div className="bg-blue-50 p-3 rounded-full">
        <Icon className="w-6 h-6 text-blue-500" />
      </div>
    </div>
  </div>
);

// Composant pour les actions rapides
const QuickAction = ({ title, icon: Icon, onClick }: { title: string; icon: React.ElementType; onClick: () => void }) => (
  <button
    onClick={onClick}
    className="flex items-center space-x-3 bg-white p-4 rounded-lg shadow-sm hover:shadow-md transition-shadow w-full"
  >
    <Icon className="w-5 h-5 text-blue-500" />
    <span className="font-medium text-gray-700">{title}</span>
  </button>
);

function App() {
  const { t } = useTranslation();
  
  // Simuler un utilisateur connecté (à remplacer par l'authentification réelle)
  const userRole: UserRole = 'super_admin';
  const userName = 'Jean Dupont';

  return (
    <div className="min-h-screen bg-gray-50">
      <Toaster position="top-right" />
      
      {/* En-tête */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Bread className="w-8 h-8 text-blue-500" />
              <h1 className="text-2xl font-bold text-gray-900">AMAP Manager</h1>
            </div>
            <div className="flex items-center space-x-4">
              <LanguageSelector />
              <span className="text-sm text-gray-500">{t('common.welcome')}, {userName}</span>
              <Shield className="w-5 h-5 text-blue-500" />
            </div>
          </div>
        </div>
      </header>

      {/* Contenu principal */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Statistiques */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard title={t('stats.activeAmaps')} value={12} icon={Users} />
          <StatCard title={t('stats.currentOrders')} value={48} icon={ShoppingCart} />
          <StatCard title={t('stats.partnerBakers')} value={8} icon={Bread} />
          <StatCard title={t('stats.todayDeliveries')} value={5} icon={Calendar} />
        </div>

        {/* Actions rapides */}
        <section className="mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">{t('common.actions')}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <QuickAction
              title={t('actions.manageAmaps')}
              icon={Users}
              onClick={() => console.log('Gérer les AMAPs')}
            />
            <QuickAction
              title={t('actions.assignBaker')}
              icon={Bread}
              onClick={() => console.log('Assigner un boulanger')}
            />
            <QuickAction
              title={t('actions.viewOrders')}
              icon={ShoppingCart}
              onClick={() => console.log('Voir les commandes')}
            />
          </div>
        </section>

        {/* Tableau des dernières activités */}
        <section>
          <h2 className="text-lg font-semibold text-gray-900 mb-4">{t('common.recentActivity')}</h2>
          <div className="bg-white shadow-md rounded-lg overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {t('table.date')}
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {t('table.amap')}
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {t('table.action')}
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {t('table.status')}
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {[1, 2, 3].map((_, index) => (
                  <tr key={index} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatDate(new Date(), t('dates.formats.medium'))}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      AMAP des Lilas
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {t('actions.viewOrders')}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                        {t('status.confirmed')}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </main>
    </div>
  );
}

export default App;