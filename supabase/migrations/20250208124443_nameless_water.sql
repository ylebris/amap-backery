/*
  # Add product catalog versioning

  1. New Tables
    - `product_catalogs`: Stores catalog versions with validity periods
      - `id` (uuid, primary key)
      - `amap_id` (uuid, reference to amaps)
      - `name` (text)
      - `valid_from` (date)
      - `valid_until` (date)
      - `status` (text: draft, active, archived)
      - Timestamps and audit fields

    - `catalog_products`: Stores products for each catalog version
      - `id` (uuid, primary key)
      - `catalog_id` (uuid, reference to product_catalogs)
      - `name` (text)
      - `description` (text)
      - `price` (decimal)
      - `category` (text)
      - Timestamps and audit fields

  2. Security
    - Enable RLS on both tables
    - Add policies for AMAP admins and bakers
    - Add policies for read access

  3. Functions
    - Get active catalog for a given date
    - Validate catalog dates
    - Manage catalog status transitions
*/

-- Product catalogs table
CREATE TABLE IF NOT EXISTS product_catalogs (
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

-- Catalog products table
CREATE TABLE IF NOT EXISTS catalog_products (
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

-- Enable RLS
ALTER TABLE product_catalogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_products ENABLE ROW LEVEL SECURITY;

-- Function to validate catalog dates
CREATE OR REPLACE FUNCTION validate_catalog_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Check for overlapping active catalogs
  IF NEW.status = 'active' AND EXISTS (
    SELECT 1 FROM product_catalogs
    WHERE amap_id = NEW.amap_id
    AND status = 'active'
    AND id != NEW.id
    AND (
      (NEW.valid_from BETWEEN valid_from AND COALESCE(valid_until, 'infinity'::date))
      OR (COALESCE(NEW.valid_until, 'infinity'::date) BETWEEN valid_from AND COALESCE(valid_until, 'infinity'::date))
    )
  ) THEN
    RAISE EXCEPTION 'Cannot have overlapping active catalogs for the same AMAP';
  END IF;

  -- Ensure valid_from is not in the past for new catalogs
  IF TG_OP = 'INSERT' AND NEW.valid_from < CURRENT_DATE THEN
    RAISE EXCEPTION 'Cannot create catalog with start date in the past';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for catalog date validation
CREATE TRIGGER validate_catalog_dates
  BEFORE INSERT OR UPDATE ON product_catalogs
  FOR EACH ROW
  EXECUTE FUNCTION validate_catalog_dates();

-- Function to get active catalog
CREATE OR REPLACE FUNCTION get_active_catalog(p_amap_id uuid, p_date date DEFAULT CURRENT_DATE)
RETURNS uuid AS $$
DECLARE
  v_catalog_id uuid;
BEGIN
  SELECT id INTO v_catalog_id
  FROM product_catalogs
  WHERE amap_id = p_amap_id
  AND status = 'active'
  AND valid_from <= p_date
  AND (valid_until IS NULL OR valid_until >= p_date);
  
  RETURN v_catalog_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to archive old catalogs
CREATE OR REPLACE FUNCTION archive_expired_catalogs()
RETURNS void AS $$
BEGIN
  UPDATE product_catalogs
  SET status = 'archived'
  WHERE status = 'active'
  AND valid_until < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies for product catalogs
CREATE POLICY "AMAP admins can manage catalogs"
  ON product_catalogs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = product_catalogs.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Bakers can view catalogs for their AMAPs"
  ON product_catalogs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_baker_assignments
      WHERE baker_id = auth.uid()
      AND amap_id = product_catalogs.amap_id
    )
  );

CREATE POLICY "Members can view active catalogs"
  ON product_catalogs
  FOR SELECT
  USING (
    status = 'active' AND
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = product_catalogs.amap_id
    )
  );

-- Policies for catalog products
CREATE POLICY "AMAP admins can manage catalog products"
  ON catalog_products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM product_catalogs pc
      JOIN amap_members am ON am.amap_id = pc.amap_id
      WHERE pc.id = catalog_products.catalog_id
      AND am.user_id = auth.uid()
      AND am.role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Everyone can view products of active catalogs"
  ON catalog_products
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM product_catalogs
      WHERE id = catalog_products.catalog_id
      AND status = 'active'
    )
  );

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_catalogs_amap ON product_catalogs(amap_id);
CREATE INDEX IF NOT EXISTS idx_product_catalogs_status ON product_catalogs(status);
CREATE INDEX IF NOT EXISTS idx_product_catalogs_dates ON product_catalogs(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_catalog_products_catalog ON catalog_products(catalog_id);

-- Update existing tables to reference catalog products
ALTER TABLE ephemeral_products
ADD COLUMN IF NOT EXISTS catalog_product_id uuid REFERENCES catalog_products(id);

ALTER TABLE recurring_contract_orders
ADD COLUMN IF NOT EXISTS catalog_product_id uuid REFERENCES catalog_products(id),
DROP CONSTRAINT IF EXISTS recurring_contract_orders_product_id_fkey,
ADD CONSTRAINT recurring_contract_orders_product_reference CHECK (
  (product_id IS NOT NULL AND catalog_product_id IS NULL) OR
  (product_id IS NULL AND catalog_product_id IS NOT NULL)
);

COMMENT ON TABLE product_catalogs IS 'Stores versioned product catalogs with validity periods';
COMMENT ON TABLE catalog_products IS 'Stores products associated with specific catalog versions';