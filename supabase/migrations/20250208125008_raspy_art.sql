/*
  # Fix Database Schema

  1. Changes
    - Add missing constraints
    - Enable RLS on all tables
    - Add missing indexes
    - Fix notification types
    - Add updated_at triggers
  
  2. Security
    - Ensure RLS is enabled on all tables
    - Add missing policies
*/

-- Enable RLS on all tables that might have been missed
DO $$ 
DECLARE 
  t text;
BEGIN
  FOR t IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
  END LOOP;
END $$;

-- Add updated_at trigger to all tables with updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ 
DECLARE 
  t record;
BEGIN
  FOR t IN 
    SELECT table_name 
    FROM information_schema.columns 
    WHERE column_name = 'updated_at' 
    AND table_schema = 'public'
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS update_%I_updated_at ON %I;
      CREATE TRIGGER update_%I_updated_at
        BEFORE UPDATE ON %I
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    ', t.table_name, t.table_name, t.table_name, t.table_name);
  END LOOP;
END $$;

-- Add missing indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_ephemeral_products_period ON ephemeral_products(period_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_user ON ephemeral_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_period ON ephemeral_orders(period_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_order_items_order ON ephemeral_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_order_items_product ON ephemeral_order_items(product_id);

-- Add missing constraints
ALTER TABLE ephemeral_orders
ADD CONSTRAINT valid_delivery_date 
  CHECK (delivery_date >= CURRENT_DATE);

ALTER TABLE ephemeral_contract_periods
ADD CONSTRAINT valid_period_dates 
  CHECK (start_date <= end_date);

-- Update notification types to be consistent
UPDATE baker_notifications
SET notification_type = 'management_change'
WHERE notification_type NOT IN ('recurring', 'ephemeral', 'management_change');

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Everyone can view active products" ON ephemeral_products;

-- Create new policy
CREATE POLICY "Everyone can view active products"
  ON ephemeral_products
  FOR SELECT
  USING (
    period_id IN (
      SELECT id FROM ephemeral_contract_periods
      WHERE end_date >= CURRENT_DATE
    )
  );

-- Add function to validate schema
CREATE OR REPLACE FUNCTION validate_schema()
RETURNS boolean AS $$
DECLARE
  missing_rls boolean;
  missing_triggers boolean;
BEGIN
  -- Check for tables without RLS
  SELECT EXISTS (
    SELECT 1 
    FROM pg_tables 
    WHERE schemaname = 'public'
    AND NOT EXISTS (
      SELECT 1 
      FROM pg_policies 
      WHERE schemaname = 'public' 
      AND tablename = pg_tables.tablename
    )
  ) INTO missing_rls;

  -- Check for tables with updated_at but no trigger
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns c
    WHERE c.column_name = 'updated_at'
    AND c.table_schema = 'public'
    AND NOT EXISTS (
      SELECT 1 
      FROM pg_trigger t
      JOIN pg_class cl ON cl.oid = t.tgrelid
      WHERE cl.relname = c.table_name
      AND t.tgname = 'update_' || c.table_name || '_updated_at'
    )
  ) INTO missing_triggers;

  RETURN NOT (missing_rls OR missing_triggers);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_schema() IS 'Validates that all tables have RLS enabled and proper updated_at triggers';