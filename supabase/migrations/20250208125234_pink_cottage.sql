/*
  # Fix Schema Issues

  1. Enable RLS
    - Enable RLS on user_sessions
    - Enable RLS on password_reset_tokens

  2. Add Missing Indexes
    - Add indexes for all foreign key relationships
*/

-- Enable RLS on remaining tables
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- Add missing indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_amap ON ephemeral_orders(amap_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contracts_validator ON recurring_contracts(validated_by);
CREATE INDEX IF NOT EXISTS idx_recurring_contract_orders_catalog_product ON recurring_contract_orders(catalog_product_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contract_orders_user ON recurring_contract_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_baker_notifications_amap ON baker_notifications(amap_id);
CREATE INDEX IF NOT EXISTS idx_amap_delivery_settings_amap ON amap_delivery_settings(amap_id);
CREATE INDEX IF NOT EXISTS idx_contract_adjustments_creator ON contract_adjustments(created_by);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_creator ON delivery_exceptions(created_by);
CREATE INDEX IF NOT EXISTS idx_amap_delivery_days_modifier ON amap_delivery_days(modified_by);
CREATE INDEX IF NOT EXISTS idx_product_catalogs_creator ON product_catalogs(created_by);
CREATE INDEX IF NOT EXISTS idx_catalog_products_creator ON catalog_products(created_by);
CREATE INDEX IF NOT EXISTS idx_ephemeral_products_catalog ON ephemeral_products(catalog_product_id);
CREATE INDEX IF NOT EXISTS idx_ephemeral_contract_periods_amap ON ephemeral_contract_periods(amap_id);

-- Add RLS policies for user_sessions
CREATE POLICY "Users can manage their own sessions"
  ON user_sessions
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage all sessions"
  ON user_sessions
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT user_id FROM user_roles WHERE role = 'admin'
    )
  );

-- Add RLS policies for password_reset_tokens
CREATE POLICY "Users can view their own reset tokens"
  ON password_reset_tokens
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all reset tokens"
  ON password_reset_tokens
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT user_id FROM user_roles WHERE role = 'admin'
    )
  );