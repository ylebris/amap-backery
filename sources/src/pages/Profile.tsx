import React from 'react';
import { useTranslation } from 'react-i18next';
import { Card } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { useForm } from 'react-hook-form';
import { useAuthStore } from '../stores/auth';

interface ProfileForm {
  firstName: string;
  lastName: string;
  email: string;
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export const Profile = () => {
  const { t } = useTranslation();
  const { user } = useAuthStore();
  const { register, handleSubmit, formState: { errors } } = useForm<ProfileForm>();

  const onSubmit = (data: ProfileForm) => {
    console.log(data);
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">{t('profile.title')}</h1>

      <Card>
        <Card.Header>
          <h2 className="text-lg font-medium text-gray-900">{t('profile.personalInfo')}</h2>
        </Card.Header>
        <Card.Body>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <Input
                label={t('profile.firstName')}
                {...register('firstName', { required: t('validation.required') })}
                error={errors.firstName?.message}
              />
              <Input
                label={t('profile.lastName')}
                {...register('lastName', { required: t('validation.required') })}
                error={errors.lastName?.message}
              />
            </div>
            <Input
              label={t('profile.email')}
              type="email"
              defaultValue={user?.email}
              {...register('email', { required: t('validation.required') })}
              error={errors.email?.message}
            />
            <Button type="submit">{t('common.save')}</Button>
          </form>
        </Card.Body>
      </Card>

      <Card>
        <Card.Header>
          <h2 className="text-lg font-medium text-gray-900">{t('profile.changePassword')}</h2>
        </Card.Header>
        <Card.Body>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            <Input
              label={t('profile.currentPassword')}
              type="password"
              {...register('currentPassword', { required: t('validation.required') })}
              error={errors.currentPassword?.message}
            />
            <Input
              label={t('profile.newPassword')}
              type="password"
              {...register('newPassword', { required: t('validation.required') })}
              error={errors.newPassword?.message}
            />
            <Input
              label={t('profile.confirmPassword')}
              type="password"
              {...register('confirmPassword', { required: t('validation.required') })}
              error={errors.confirmPassword?.message}
            />
            <Button type="submit">{t('profile.updatePassword')}</Button>
          </form>
        </Card.Body>
      </Card>
    </div>
  );
};