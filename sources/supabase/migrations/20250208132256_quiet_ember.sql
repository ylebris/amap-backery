/*
  # Nettoyage et recréation complète de la base de données

  Cette migration nettoie complètement la base de données en supprimant tous les objets
  existants avec CASCADE, puis recrée tout dans le bon ordre.

  1. Suppression
    - Supprime toutes les vues matérialisées
    - Supprime toutes les tables avec CASCADE
    - Supprime toutes les fonctions avec CASCADE
    - Supprime tous les triggers avec CASCADE

  2. Recréation
    - Tables de base (users, roles, etc.)
    - Tables AMAP
    - Tables de contrats et produits
    - Tables de commandes
    - Fonctions et triggers
    - Vues matérialisées
    - Index et contraintes
*/

-- Suppression de tous les objets avec CASCADE
DROP MATERIALIZED VIEW IF EXISTS order_statistics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS product_usage_statistics CASCADE;
DROP MATERIALIZED VIEW IF EXISTS delivery_schedule CASCADE;

DROP TABLE IF EXISTS catalog_change_logs CASCADE;
DROP TABLE IF EXISTS catalog_validations CASCADE;
DROP TABLE IF EXISTS check_payments CASCADE;
DROP TABLE IF EXISTS amap_order_settings CASCADE;
DROP TABLE IF EXISTS delivery_exceptions CASCADE;
DROP TABLE IF EXISTS contract_adjustments CASCADE;
DROP TABLE IF EXISTS amap_delivery_days CASCADE;
DROP TABLE IF EXISTS amap_delivery_settings CASCADE;
DROP TABLE IF EXISTS baker_notifications CASCADE;
DROP TABLE IF EXISTS recurring_contract_orders CASCADE;
DROP TABLE IF EXISTS recurring_contracts CASCADE;
DROP TABLE IF EXISTS catalog_products CASCADE;
DROP TABLE IF EXISTS product_catalogs CASCADE;
DROP TABLE IF EXISTS ephemeral_order_items CASCADE;
DROP TABLE IF EXISTS ephemeral_orders CASCADE;
DROP TABLE IF EXISTS ephemeral_products CASCADE;
DROP TABLE IF EXISTS ephemeral_contract_periods CASCADE;
DROP TABLE IF EXISTS amap_baker_assignments CASCADE;
DROP TABLE IF EXISTS amap_members CASCADE;
DROP TABLE IF EXISTS amaps CASCADE;
DROP TABLE IF EXISTS mfa_backup_codes CASCADE;
DROP TABLE IF EXISTS mfa_methods CASCADE;
DROP TABLE IF EXISTS password_reset_tokens CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Suppression des fonctions
DROP FUNCTION IF EXISTS prevent_archived_catalog_modifications() CASCADE;
DROP FUNCTION IF EXISTS toggle_baker_catalog_management(uuid, uuid, boolean) CASCADE;
DROP FUNCTION IF EXISTS validate_catalog_dates() CASCADE;
DROP FUNCTION IF EXISTS get_active_catalog(uuid, date) CASCADE;
DROP FUNCTION IF EXISTS archive_expired_catalogs() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS validate_schema() CASCADE;
DROP FUNCTION IF EXISTS can_create_delivery_exception(uuid, date, integer) CASCADE;
DROP FUNCTION IF EXISTS recalculate_contract_end_date(uuid) CASCADE;
DROP FUNCTION IF EXISTS trigger_recalculate_contract_end_date() CASCADE;
DROP FUNCTION IF EXISTS ensure_single_active_delivery_day() CASCADE;
DROP FUNCTION IF EXISTS get_amap_delivery_day(uuid) CASCADE;
DROP FUNCTION IF EXISTS is_valid_delivery_date(uuid, date) CASCADE;
DROP FUNCTION IF EXISTS validate_check_payment(uuid, text, text, text) CASCADE;
DROP FUNCTION IF EXISTS update_amap_order_settings(uuid, decimal) CASCADE;
DROP FUNCTION IF EXISTS validate_order_amount(uuid, decimal) CASCADE;
DROP FUNCTION IF EXISTS log_catalog_change() CASCADE;
DROP FUNCTION IF EXISTS validate_catalog(uuid, text) CASCADE;

-- Recréation des tables de base
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  first_name text,
  last_name text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE user_roles (
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('admin', 'user', 'baker')),
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

-- Recréation des tables AMAP
CREATE TABLE amaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE amap_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('super_admin', 'amap_admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(amap_id, user_id)
);

-- Recréation des tables de contrats et produits
CREATE TABLE product_catalogs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  name text NOT NULL,
  valid_from date NOT NULL,
  valid_until date,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  created_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (
    valid_until IS NULL OR valid_from <= valid_until
  )
);

CREATE TABLE catalog_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  catalog_id uuid REFERENCES product_catalogs(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price decimal NOT NULL CHECK (price >= 0),
  category text,
  created_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Recréation des tables de commandes
CREATE TABLE ephemeral_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  amap_id uuid REFERENCES amaps(id),
  delivery_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'delivered', 'cancelled')),
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_delivery_date CHECK (delivery_date >= CURRENT_DATE)
);

CREATE TABLE ephemeral_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES ephemeral_orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES catalog_products(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  created_at timestamptz DEFAULT now()
);

-- Activation RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE amaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE amap_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_catalogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE ephemeral_order_items ENABLE ROW LEVEL SECURITY;

-- Recréation des vues matérialisées
CREATE MATERIALIZED VIEW order_statistics AS
SELECT 
  o.amap_id,
  date_trunc('month', o.created_at) as month,
  o.status,
  count(*) as order_count,
  sum(
    (SELECT sum(p.price * i.quantity)
     FROM ephemeral_order_items i
     JOIN catalog_products p ON p.id = i.product_id
     WHERE i.order_id = o.id)
  ) as total_amount
FROM ephemeral_orders o
GROUP BY o.amap_id, date_trunc('month', o.created_at), o.status;

CREATE UNIQUE INDEX idx_order_statistics_unique 
ON order_statistics(amap_id, month, status);

-- Recréation des index
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_amap_members_user ON amap_members(user_id);
CREATE INDEX idx_amap_members_amap ON amap_members(amap_id);
CREATE INDEX idx_product_catalogs_amap ON product_catalogs(amap_id);
CREATE INDEX idx_catalog_products_catalog ON catalog_products(catalog_id);
CREATE INDEX idx_ephemeral_orders_user ON ephemeral_orders(user_id);
CREATE INDEX idx_ephemeral_orders_amap ON ephemeral_orders(amap_id);
CREATE INDEX idx_ephemeral_order_items_order ON ephemeral_order_items(order_id);
CREATE INDEX idx_ephemeral_order_items_product ON ephemeral_order_items(product_id);

-- Ajout des commentaires
COMMENT ON TABLE users IS 'Table des utilisateurs';
COMMENT ON TABLE amaps IS 'Table des AMAPs';
COMMENT ON TABLE product_catalogs IS 'Catalogues de produits';
COMMENT ON TABLE ephemeral_orders IS 'Commandes éphémères';
COMMENT ON MATERIALIZED VIEW order_statistics IS 'Statistiques mensuelles des commandes par AMAP';