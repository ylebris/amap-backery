/*
  # Schéma pour les contrats éphémères

  1. Nouvelles Tables
    - `user_roles` : Gestion des rôles utilisateurs
    - `ephemeral_contract_periods` : Périodes de contrats éphémères
    - `ephemeral_products` : Produits disponibles pendant les périodes
    - `ephemeral_orders` : Commandes des utilisateurs
    - `ephemeral_order_items` : Items des commandes

  2. Sécurité
    - RLS activé sur toutes les tables
    - Politiques pour la gestion des accès administrateurs et utilisateurs
*/

-- Table des rôles utilisateurs
CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin', 'user')),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

-- Table des périodes de contrats éphémères
CREATE TABLE IF NOT EXISTS ephemeral_contract_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  delivery_type text NOT NULL CHECK (delivery_type IN ('fixed', 'flexible')),
  fixed_delivery_date date,
  flexible_start_date date,
  flexible_end_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (
    (delivery_type = 'fixed' AND fixed_delivery_date IS NOT NULL) OR
    (delivery_type = 'flexible' AND flexible_start_date IS NOT NULL AND flexible_end_date IS NOT NULL)
  )
);

-- Table des produits éphémères
CREATE TABLE IF NOT EXISTS ephemeral_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid REFERENCES ephemeral_contract_periods(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price decimal NOT NULL CHECK (price >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des commandes éphémères
CREATE TABLE IF NOT EXISTS ephemeral_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid REFERENCES ephemeral_contract_periods(id),
  user_id uuid REFERENCES auth.users(id),
  delivery_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'delivered', 'cancelled')),
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des items de commande éphémères
CREATE TABLE IF NOT EXISTS ephemeral_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES ephemeral_orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES ephemeral_products(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  created_at timestamptz DEFAULT now()
);

-- Activation de la RLS
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_contract_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_order_items ENABLE ROW LEVEL SECURITY;

-- Policies pour les rôles utilisateurs
CREATE POLICY "Les administrateurs peuvent gérer les rôles"
  ON user_roles
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'))
  WITH CHECK (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'));

-- Policies pour les périodes de contrats éphémères
CREATE POLICY "Tout le monde peut voir les périodes actives"
  ON ephemeral_contract_periods
  FOR SELECT
  USING (end_date >= CURRENT_DATE);

CREATE POLICY "Seuls les administrateurs peuvent gérer les périodes"
  ON ephemeral_contract_periods
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'))
  WITH CHECK (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'));

-- Policies pour les produits éphémères
CREATE POLICY "Tout le monde peut voir les produits des périodes actives"
  ON ephemeral_products
  FOR SELECT
  USING (period_id IN (
    SELECT id FROM ephemeral_contract_periods 
    WHERE end_date >= CURRENT_DATE
  ));

CREATE POLICY "Seuls les administrateurs peuvent gérer les produits"
  ON ephemeral_products
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'))
  WITH CHECK (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'));

-- Policies pour les commandes
CREATE POLICY "Les utilisateurs peuvent voir leurs propres commandes"
  ON ephemeral_orders
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Les utilisateurs peuvent créer leurs propres commandes"
  ON ephemeral_orders
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Les utilisateurs peuvent modifier leurs propres commandes en attente"
  ON ephemeral_orders
  FOR UPDATE
  USING (auth.uid() = user_id AND status = 'pending')
  WITH CHECK (auth.uid() = user_id AND status = 'pending');

-- Policies pour les items de commande
CREATE POLICY "Les utilisateurs peuvent voir leurs propres items de commande"
  ON ephemeral_order_items
  FOR SELECT
  USING (order_id IN (
    SELECT id FROM ephemeral_orders WHERE user_id = auth.uid()
  ));

CREATE POLICY "Les utilisateurs peuvent gérer leurs propres items de commande"
  ON ephemeral_order_items
  FOR ALL
  USING (order_id IN (
    SELECT id FROM ephemeral_orders 
    WHERE user_id = auth.uid() AND status = 'pending'
  ))
  WITH CHECK (order_id IN (
    SELECT id FROM ephemeral_orders 
    WHERE user_id = auth.uid() AND status = 'pending'
  ));