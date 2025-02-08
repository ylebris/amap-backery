import { createBrowserRouter } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { Dashboard } from '../pages/Dashboard';
import { Login } from '../pages/Login';
import { AmapList } from '../pages/amaps/AmapList';
import { AmapDetails } from '../pages/amaps/AmapDetails';
import { OrderList } from '../pages/orders/OrderList';
import { OrderDetails } from '../pages/orders/OrderDetails';
import { Profile } from '../pages/Profile';
import { ProtectedRoute } from './ProtectedRoute';

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: <ProtectedRoute><Layout /></ProtectedRoute>,
    children: [
      {
        index: true,
        element: <Dashboard />,
      },
      {
        path: 'amaps',
        element: <AmapList />,
      },
      {
        path: 'amaps/:id',
        element: <AmapDetails />,
      },
      {
        path: 'orders',
        element: <OrderList />,
      },
      {
        path: 'orders/:id',
        element: <OrderDetails />,
      },
      {
        path: 'profile',
        element: <Profile />,
      },
    ],
  },
]);