import React from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { Plus, Users } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Table } from '../../components/ui/Table';
import { Button } from '../../components/ui/Button';
import { formatDate } from '../../i18n';

export const AmapList = () => {
  const { t } = useTranslation();

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-900">{t('amaps.title')}</h1>
        <Button>
          <Plus className="w-4 h-4 mr-2" />
          {t('amaps.create')}
        </Button>
      </div>

      <Card>
        <Table>
          <Table.Head>
            <Table.Row>
              <Table.Header>{t('amaps.name')}</Table.Header>
              <Table.Header>{t('amaps.members')}</Table.Header>
              <Table.Header>{t('amaps.baker')}</Table.Header>
              <Table.Header>{t('amaps.lastDelivery')}</Table.Header>
              <Table.Header>{t('common.actions')}</Table.Header>
            </Table.Row>
          </Table.Head>
          <Table.Body>
            {[1, 2, 3].map((_, index) => (
              <Table.Row key={index}>
                <Table.Cell className="font-medium text-gray-900">
                  AMAP des Lilas
                </Table.Cell>
                <Table.Cell>
                  <div className="flex items-center">
                    <Users className="w-4 h-4 mr-2 text-gray-400" />
                    42
                  </div>
                </Table.Cell>
                <Table.Cell>Jean Boulanger</Table.Cell>
                <Table.Cell>
                  {formatDate(new Date(), t('dates.formats.short'))}
                </Table.Cell>
                <Table.Cell>
                  <Link
                    to={`/amaps/${index}`}
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