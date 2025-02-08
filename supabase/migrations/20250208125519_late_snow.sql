/*
  # Schema Updates and Policy Refinements
  
  This migration:
  1. Updates existing constraints and policies
  2. Adds missing indexes
  3. Ensures RLS is enabled on all tables
  4. Adds missing policies
*/

-- Update existing constraints
ALTER TABLE ephemeral_orders
DROP CONSTRAINT IF EXISTS valid_delivery_date,
ADD CONSTRAINT valid_delivery_date 
  CHECK (delivery_date >= CURRENT_DATE);

ALTER TABLE ephemeral_contract_periods
DROP CONSTRAINT IF EXISTS valid_period_dates,
ADD CONSTRAINT valid_period_dates 
  CHECK (start_date <= end_date);

-- Ensure RLS is enabled on all tables
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

-- Add or update missing indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_amap_members_amap ON amap_members(amap_id);
CREATE INDEX IF NOT EXISTS idx_amap_members_user ON amap_members(user_id);
CREATE INDEX IF NOT EXISTS idx_product_catalogs_amap ON product_catalogs(amap_id);
CREATE INDEX IF NOT EXISTS idx_product_catalogs_status ON product_catalogs(status);
CREATE INDEX IF NOT EXISTS idx_catalog_products_catalog ON catalog_products(catalog_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contracts_amap ON recurring_contracts(amap_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contracts_baker ON recurring_contracts(baker_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contract_orders_contract ON recurring_contract_orders(contract_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contract_orders_user ON recurring_contract_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_contract_periods_amap ON ephemeral_contract_periods(amap_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_products_period ON ephemeral_products(period_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_period ON ephemeral_orders(period_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_amap ON ephemeral_orders(amap_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_user ON ephemeral_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_order_items_order ON ephemeral_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_order_items_product ON ephemeral_order_items(product_id);

-- Add or update RLS policies
DROP POLICY IF EXISTS "Users can view their own data" ON users;
CREATE POLICY "Users can view their own data" ON users
  FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can manage their own sessions" ON user_sessions;
CREATE POLICY "Users can manage their own sessions" ON user_sessions
  FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can view their own reset tokens" ON password_reset_tokens;
CREATE POLICY "Users can view their own reset tokens" ON password_reset_tokens
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can manage their own MFA methods" ON mfa_methods;
CREATE POLICY "Users can manage their own MFA methods" ON mfa_methods
  FOR ALL USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can manage their own backup codes" ON mfa_backup_codes;
CREATE POLICY "Users can manage their own backup codes" ON mfa_backup_codes
  FOR ALL USING (user_id = auth.uid());

-- Add AMAP-specific policies
DROP POLICY IF EXISTS "AMAP members can view their AMAP" ON amaps;
CREATE POLICY "AMAP members can view their AMAP" ON amaps
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amaps.id
    )
  );

DROP POLICY IF EXISTS "AMAP admins can manage their AMAP" ON amaps;
CREATE POLICY "AMAP admins can manage their AMAP" ON amaps
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amaps.id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Add order management policies
DROP POLICY IF EXISTS "Users can manage their own orders" ON ephemeral_orders;
CREATE POLICY "Users can manage their own orders" ON ephemeral_orders
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "AMAP admins can view all orders" ON ephemeral_orders;
CREATE POLICY "AMAP admins can view all orders" ON ephemeral_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = ephemeral_orders.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Add baker-specific policies
DROP POLICY IF EXISTS "Bakers can view assigned AMAP orders" ON ephemeral_orders;
CREATE POLICY "Bakers can view assigned AMAP orders" ON ephemeral_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_baker_assignments
      WHERE baker_id = auth.uid()
      AND amap_id = ephemeral_orders.amap_id
    )
  );

-- Update comments for clarity
COMMENT ON TABLE users IS 'User accounts and profile information';
COMMENT ON TABLE amaps IS 'AMAP organizations';
COMMENT ON TABLE amap_members IS 'AMAP membership and roles';
COMMENT ON TABLE ephemeral_orders IS 'Short-term orders with delivery tracking';
COMMENT ON TABLE ephemeral_products IS 'Products available during specific periods';
COMMENT ON TABLE amap_baker_assignments IS 'Baker assignments to AMAPs with management privileges';