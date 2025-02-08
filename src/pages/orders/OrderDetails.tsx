import React from 'react';
import { useTranslation } from 'react-i18next';
import { useParams } from 'react-router-dom';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { formatDate, formatCurrency } from '../../i18n';

export const OrderDetails = () => {
  const { t } = useTranslation();
  const { id } = useParams();

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">
          {t('orders.details')} #ORD-{String(id).padStart(4, '0')}
        </h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <Card.Header>
            <h2 className="text-lg font-medium text-gray-900">{t('orders.customerInfo')}</h2>
          </Card.Header>
          <Card.Body>
            <dl className="grid grid-cols-1 gap-4">
              <div>
                <dt className="text-sm font-medium text-gray-500">{t('orders.customer')}</dt>
                <dd className="mt-1 text-sm text-gray-900">Marie Martin</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">{t('orders.email')}</dt>
                <dd className="mt-1 text-sm text-gray-900">marie.martin@example.com</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">{t('orders.amap')}</dt>
                <dd className="mt-1 text-sm text-gray-900">AMAP des Lilas</dd>
              </div>
            </dl>
          </Card.Body>
        </Card>

        <Card>
          <Card.Header>
            <h2 className="text-lg font-medium text-gray-900">{t('orders.deliveryInfo')}</h2>
          </Card.Header>
          <Card.Body>
            <dl className="grid grid-cols-1 gap-4">
              <div>
                <dt className="text-sm font-medium text-gray-500">{t('orders.deliveryDate')}</dt>
                <dd className="mt-1 text-sm text-gray-900">
                  {formatDate(new Date(), t('dates.formats.long'))}
                </dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">{t('orders.status')}</dt>
                <dd className="mt-1">
                  <span className="px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                    {t('status.confirmed')}
                  </span>
                </dd>
              </div>
            </dl>
          </Card.Body>
        </Card>
      </div>

      <Card>
        <Card.Header>
          <h2 className="text-lg font-medium text-gray-900">{t('orders.items')}</h2>
        </Card.Header>
        <Table>
          <Table.Head>
            <Table.Row>
              <Table.Header>{t('orders.product')}</Table.Header>
              <Table.Header>{t('orders.quantity')}</Table.Header>
              <Table.Header>{t('orders.unitPrice')}</Table.Header>
              <Table.Header>{t('orders.total')}</Table.Header>
            </Table.Row>
          </Table.Head>
          <Table.Body>
            {[1, 2].map((_, index) => (
              <Table.Row key={index}>
                <Table.Cell className="font-medium text-gray-900">
                  Pain au levain
                </Table.Cell>
                <Table.Cell>2</Table.Cell>
                <Table.Cell>{formatCurrency(3.50)}</Table.Cell>
                <Table.Cell>{formatCurrency(7.00)}</Table.Cell>
              </Table.Row>
            ))}
            <Table.Row>
              <Table.Cell colSpan={3} className="text-right font-medium">
                {t('orders.total')}
              </Table.Cell>
              <Table.Cell className="font-bold">
                {formatCurrency(42.50)}
              </Table.Cell>
            </Table.Row>
          </Table.Body>
        </Table>
      </Card>
    </div>
  );
};