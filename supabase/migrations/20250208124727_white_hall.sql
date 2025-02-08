/*
  # Add baker catalog management option

  1. Changes
    - Add baker_managed_catalog column to amap_baker_assignments
    - Update policies to allow bakers to manage catalogs when enabled
    - Add function to toggle catalog management mode
    - Add validation to ensure only one party can manage catalogs

  2. Security
    - Ensure proper access control based on management mode
    - Prevent conflicts between AMAP admins and bakers
*/

-- Add baker catalog management option
ALTER TABLE amap_baker_assignments
ADD COLUMN IF NOT EXISTS manages_catalogs boolean DEFAULT false;

-- Function to toggle catalog management
CREATE OR REPLACE FUNCTION toggle_baker_catalog_management(
  p_amap_id uuid,
  p_baker_id uuid,
  p_manages_catalogs boolean
)
RETURNS void AS $$
BEGIN
  UPDATE amap_baker_assignments
  SET manages_catalogs = p_manages_catalogs
  WHERE amap_id = p_amap_id
  AND baker_id = p_baker_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update product catalogs policies
DROP POLICY IF EXISTS "AMAP admins can manage non-archived catalogs" ON product_catalogs;
DROP POLICY IF EXISTS "Bakers can view catalogs for their AMAPs" ON product_catalogs;

CREATE POLICY "Catalog management based on assignment"
  ON product_catalogs
  FOR ALL
  USING (
    (
      -- AMAP admins can manage if baker is not assigned to manage
      EXISTS (
        SELECT 1 FROM amap_members am
        WHERE am.user_id = auth.uid()
        AND am.amap_id = product_catalogs.amap_id
        AND am.role IN ('amap_admin', 'super_admin')
        AND NOT EXISTS (
          SELECT 1 FROM amap_baker_assignments aba
          WHERE aba.amap_id = product_catalogs.amap_id
          AND aba.manages_catalogs = true
        )
      )
      OR
      -- Assigned bakers can manage
      EXISTS (
        SELECT 1 FROM amap_baker_assignments aba
        WHERE aba.baker_id = auth.uid()
        AND aba.amap_id = product_catalogs.amap_id
        AND aba.manages_catalogs = true
      )
    )
    AND (
      status != 'archived' OR
      CURRENT_SETTING('app.bypass_rls', TRUE)::boolean
    )
  );

-- Update catalog products policies
DROP POLICY IF EXISTS "AMAP admins can manage catalog products" ON catalog_products;

CREATE POLICY "Products management based on catalog assignment"
  ON catalog_products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM product_catalogs pc
      WHERE pc.id = catalog_products.catalog_id
      AND (
        -- AMAP admins can manage if baker is not assigned to manage
        EXISTS (
          SELECT 1 FROM amap_members am
          WHERE am.user_id = auth.uid()
          AND am.amap_id = pc.amap_id
          AND am.role IN ('amap_admin', 'super_admin')
          AND NOT EXISTS (
            SELECT 1 FROM amap_baker_assignments aba
            WHERE aba.amap_id = pc.amap_id
            AND aba.manages_catalogs = true
          )
        )
        OR
        -- Assigned bakers can manage
        EXISTS (
          SELECT 1 FROM amap_baker_assignments aba
          WHERE aba.baker_id = auth.uid()
          AND aba.amap_id = pc.amap_id
          AND aba.manages_catalogs = true
        )
      )
      AND pc.status != 'archived'
    )
  );

-- Add function to check who manages catalogs
CREATE OR REPLACE FUNCTION get_catalog_manager(p_amap_id uuid)
RETURNS TABLE (
  manager_type text,
  manager_id uuid
) AS $$
BEGIN
  -- Check if a baker is assigned to manage catalogs
  IF EXISTS (
    SELECT 1 FROM amap_baker_assignments
    WHERE amap_id = p_amap_id
    AND manages_catalogs = true
  ) THEN
    RETURN QUERY
    SELECT 'baker'::text, baker_id
    FROM amap_baker_assignments
    WHERE amap_id = p_amap_id
    AND manages_catalogs = true;
  ELSE
    -- Return AMAP admin as manager
    RETURN QUERY
    SELECT 'amap_admin'::text, user_id
    FROM amap_members
    WHERE amap_id = p_amap_id
    AND role IN ('amap_admin', 'super_admin')
    LIMIT 1;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_amap_baker_assignments_management
ON amap_baker_assignments(amap_id, baker_id, manages_catalogs);

COMMENT ON COLUMN amap_baker_assignments.manages_catalogs IS 'Indicates if the baker manages catalogs for this AMAP';
COMMENT ON FUNCTION toggle_baker_catalog_management IS 'Toggles catalog management responsibility between AMAP admin and baker';
COMMENT ON FUNCTION get_catalog_manager IS 'Returns the current catalog manager (baker or AMAP admin) for an AMAP';