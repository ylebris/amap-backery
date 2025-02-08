import React from 'react';
import { useTranslation } from 'react-i18next';
import { useParams } from 'react-router-dom';
import { Users, Calendar, ShoppingBag } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { formatDate, formatNumber } from '../../i18n';

export const AmapDetails = () => {
  const { t } = useTranslation();
  const { id } = useParams();

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">AMAP des Lilas</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <Card.Body>
            <div className="flex items-center">
              <Users className="w-8 h-8 text-blue-500" />
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">{t('amaps.members')}</p>
                <p className="text-2xl font-bold">{formatNumber(42)}</p>
              </div>
            </div>
          </Card.Body>
        </Card>

        <Card>
          <Card.Body>
            <div className="flex items-center">
              <Calendar className="w-8 h-8 text-green-500" />
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">{t('amaps.nextDelivery')}</p>
                <p className="text-2xl font-bold">
                  {formatDate(new Date(), t('dates.formats.short'))}
                </p>
              </div>
            </div>
          </Card.Body>
        </Card>

        <Card>
          <Card.Body>
            <div className="flex items-center">
              <ShoppingBag className="w-8 h-8 text-purple-500" />
              <div className="ml-4">
                <p className="text-sm font-medium text-gray-500">{t('amaps.activeOrders')}</p>
                <p className="text-2xl font-bold">{formatNumber(12)}</p>
              </div>
            </div>
          </Card.Body>
        </Card>
      </div>

      <Card>
        <Card.Header>
          <h2 className="text-lg font-medium text-gray-900">{t('amaps.members')}</h2>
        </Card.Header>
        <Table>
          <Table.Head>
            <Table.Row>
              <Table.Header>{t('members.name')}</Table.Header>
              <Table.Header>{t('members.email')}</Table.Header>
              <Table.Header>{t('members.role')}</Table.Header>
              <Table.Header>{t('members.joinDate')}</Table.Header>
            </Table.Row>
          </Table.Head>
          <Table.Body>
            {[1, 2, 3].map((_, index) => (
              <Table.Row key={index}>
                <Table.Cell className="font-medium text-gray-900">
                  Jean Dupont
                </Table.Cell>
                <Table.Cell>jean.dupont@example.com</Table.Cell>
                <Table.Cell>
                  <span className="px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800">
                    {t('roles.member')}
                  </span>
                </Table.Cell>
                <Table.Cell>
                  {formatDate(new Date(), t('dates.formats.short'))}
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table>
      </Card>
    </div>
  );
};