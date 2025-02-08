import React from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { Heading as Bread } from 'lucide-react';
import { useAuthStore } from '../stores/auth';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Card } from '../components/ui/Card';
import toast from 'react-hot-toast';

interface LoginForm {
  email: string;
  password: string;
}

export const Login = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { signIn } = useAuthStore();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<LoginForm>();

  const onSubmit = async (data: LoginForm) => {
    try {
      await signIn(data.email, data.password);
      navigate('/');
    } catch (error) {
      toast.error(t('auth.loginError'));
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center">
          <Bread className="h-12 w-12 text-blue-500" />
        </div>
        <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
          {t('auth.signIn')}
        </h2>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <Card>
          <Card.Body>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
              <Input
                label={t('auth.email')}
                type="email"
                error={errors.email?.message}
                {...register('email', { required: t('validation.required') })}
              />

              <Input
                label={t('auth.password')}
                type="password"
                error={errors.password?.message}
                {...register('password', { required: t('validation.required') })}
              />

              <Button
                type="submit"
                loading={isSubmitting}
                className="w-full"
              >
                {t('auth.signIn')}
              </Button>
            </form>
          </Card.Body>
        </Card>
      </div>
    </div>
  );
};