-- Table des assignations de boulangers
CREATE TABLE IF NOT EXISTS amap_baker_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  baker_id uuid REFERENCES users(id) ON DELETE CASCADE,
  manages_catalogs boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT single_baker_per_amap UNIQUE (amap_id)
);

-- Table des périodes de livraison
CREATE TABLE IF NOT EXISTS delivery_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  start_date date NOT NULL,
  end_date date NOT NULL,
  delivery_day integer NOT NULL CHECK (delivery_day BETWEEN 0 AND 6),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_period_dates CHECK (start_date <= end_date)
);

-- Table des exceptions de livraison
CREATE TABLE IF NOT EXISTS delivery_exceptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id),
  exception_date date NOT NULL,
  reason text NOT NULL,
  created_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE amap_baker_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_exceptions ENABLE ROW LEVEL SECURITY;

-- Policies for users
CREATE POLICY "Users can view their own data"
  ON users
  FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Super admins can manage all users"
  ON users
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- Policies for AMAP members
CREATE POLICY "AMAP admins can manage their members"
  ON amap_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members am
      WHERE am.user_id = auth.uid()
      AND am.amap_id = amap_members.amap_id
      AND am.role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Members can view their AMAP memberships"
  ON amap_members
  FOR SELECT
  USING (user_id = auth.uid());

-- Policies for baker assignments
CREATE POLICY "Only super admins can manage baker assignments"
  ON amap_baker_assignments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

CREATE POLICY "Bakers can view their assignments"
  ON amap_baker_assignments
  FOR SELECT
  USING (baker_id = auth.uid());

-- Policies for catalogs
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

CREATE POLICY "Bakers can manage catalogs when assigned"
  ON product_catalogs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_baker_assignments
      WHERE baker_id = auth.uid()
      AND amap_id = product_catalogs.amap_id
      AND manages_catalogs = true
    )
  );

-- Policies for catalog products
CREATE POLICY "Catalog managers can manage products"
  ON catalog_products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM product_catalogs pc
      WHERE pc.id = catalog_products.catalog_id
      AND (
        EXISTS (
          SELECT 1 FROM amap_members
          WHERE user_id = auth.uid()
          AND amap_id = pc.amap_id
          AND role IN ('amap_admin', 'super_admin')
        )
        OR
        EXISTS (
          SELECT 1 FROM amap_baker_assignments
          WHERE baker_id = auth.uid()
          AND amap_id = pc.amap_id
          AND manages_catalogs = true
        )
      )
    )
  );

-- Policies for orders
CREATE POLICY "Members can manage their pending orders"
  ON ephemeral_orders
  FOR ALL
  USING (
    user_id = auth.uid()
    AND status = 'pending'
  )
  WITH CHECK (
    user_id = auth.uid()
    AND status = 'pending'
  );

CREATE POLICY "Members can view their confirmed orders"
  ON ephemeral_orders
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND status != 'pending'
  );

CREATE POLICY "AMAP admins can manage all orders"
  ON ephemeral_orders
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = ephemeral_orders.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Policies for order items
CREATE POLICY "Users can manage their order items"
  ON ephemeral_order_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM ephemeral_orders
      WHERE id = ephemeral_order_items.order_id
      AND user_id = auth.uid()
    )
  );

-- Policies for delivery periods
CREATE POLICY "AMAP admins can manage delivery periods"
  ON delivery_periods
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = delivery_periods.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Policies for delivery exceptions
CREATE POLICY "AMAP admins can manage delivery exceptions"
  ON delivery_exceptions
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = delivery_exceptions.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Add indexes
CREATE INDEX idx_baker_assignments_baker ON amap_baker_assignments(baker_id);
CREATE INDEX idx_baker_assignments_amap ON amap_baker_assignments(amap_id);
CREATE INDEX idx_delivery_periods_amap ON delivery_periods(amap_id);
CREATE INDEX idx_delivery_exceptions_amap ON delivery_exceptions(amap_id);
CREATE INDEX idx_delivery_exceptions_date ON delivery_exceptions(exception_date);

-- Add comments
COMMENT ON TABLE amap_baker_assignments IS 'Assignation des boulangers aux AMAPs';
COMMENT ON TABLE delivery_periods IS 'Périodes de livraison pour chaque AMAP';
COMMENT ON TABLE delivery_exceptions IS 'Exceptions aux livraisons (jours fériés, etc.)';