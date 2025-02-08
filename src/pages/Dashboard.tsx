import React from 'react';
import { useTranslation } from 'react-i18next';
import { Shield, Heading as Bread, Users, Calendar, ShoppingCart } from 'lucide-react';
import { Card } from '../components/ui/Card';
import { Table } from '../components/ui/Table';
import { formatDate, formatNumber } from '../i18n';

const StatCard = ({ title, value, icon: Icon }: { title: string; value: string | number; icon: React.ElementType }) => (
  <Card className="bg-white">
    <Card.Body>
      <div className="flex items-center justify-between">
        <div>
          <p className="text-gray-500 text-sm font-medium">{title}</p>
          <p className="text-2xl font-bold mt-2">{typeof value === 'number' ? formatNumber(value) : value}</p>
        </div>
        <div className="bg-blue-50 p-3 rounded-full">
          <Icon className="w-6 h-6 text-blue-500" />
        </div>
      </div>
    </Card.Body>
  </Card>
);

export const Dashboard = () => {
  const { t } = useTranslation();

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title={t('stats.activeAmaps')} value={12} icon={Users} />
        <StatCard title={t('stats.currentOrders')} value={48} icon={ShoppingCart} />
        <StatCard title={t('stats.partnerBakers')} value={8} icon={Bread} />
        <StatCard title={t('stats.todayDeliveries')} value={5} icon={Calendar} />
      </div>

      <Card>
        <Card.Header>
          <h2 className="text-lg font-medium text-gray-900">{t('common.recentActivity')}</h2>
        </Card.Header>
        <Table>
          <Table.Head>
            <Table.Row>
              <Table.Header>{t('table.date')}</Table.Header>
              <Table.Header>{t('table.amap')}</Table.Header>
              <Table.Header>{t('table.action')}</Table.Header>
              <Table.Header>{t('table.status')}</Table.Header>
            </Table.Row>
          </Table.Head>
          <Table.Body>
            {[1, 2, 3].map((_, index) => (
              <Table.Row key={index}>
                <Table.Cell>
                  {formatDate(new Date(), t('dates.formats.medium'))}
                </Table.Cell>
                <Table.Cell className="font-medium text-gray-900">
                  AMAP des Lilas
                </Table.Cell>
                <Table.Cell>
                  {t('actions.viewOrders')}
                </Table.Cell>
                <Table.Cell>
                  <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                    {t('status.confirmed')}
                  </span>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table>
      </Card>
    </div>
  );
};