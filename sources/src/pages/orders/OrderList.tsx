import React from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { formatDate, formatCurrency } from '../../i18n';

export const OrderList = () => {
  const { t } = useTranslation();

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">{t('orders.title')}</h1>
      </div>

      <Card>
        <Table>
          <Table.Head>
            <Table.Row>
              <Table.Header>{t('orders.reference')}</Table.Header>
              <Table.Header>{t('orders.customer')}</Table.Header>
              <Table.Header>{t('orders.amap')}</Table.Header>
              <Table.Header>{t('orders.deliveryDate')}</Table.Header>
              <Table.Header>{t('orders.amount')}</Table.Header>
              <Table.Header>{t('orders.status')}</Table.Header>
              <Table.Header>{t('common.actions')}</Table.Header>
            </Table.Row>
          </Table.Head>
          <Table.Body>
            {[1, 2, 3].map((_, index) => (
              <Table.Row key={index}>
                <Table.Cell className="font-medium text-gray-900">
                  #ORD-{String(index + 1).padStart(4, '0')}
                </Table.Cell>
                <Table.Cell>Marie Martin</Table.Cell>
                <Table.Cell>AMAP des Lilas</Table.Cell>
                <Table.Cell>
                  {formatDate(new Date(), t('dates.formats.short'))}
                </Table.Cell>
                <Table.Cell>{formatCurrency(42.50)}</Table.Cell>
                <Table.Cell>
                  <span className="px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                    {t('status.confirmed')}
                  </span>
                </Table.Cell>
                <Table.Cell>
                  <Link
                    to={`/orders/${index}`}
                    className="text-blue-600 hover:text-blue-800"
                  >
                    {t('common.view')}
                  </Link>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table.Body>
        </Table>
      </Card>
    </div>
  );
};