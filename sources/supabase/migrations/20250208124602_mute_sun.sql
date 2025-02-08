/*
  # Add protection for archived catalogs

  1. Changes
    - Add trigger to prevent modifications of archived catalogs
    - Add trigger to prevent modifications of products in archived catalogs
    - Update policies to enforce these restrictions

  2. Security
    - Ensure archived catalogs are read-only
    - Ensure products in archived catalogs are read-only
*/

-- Function to prevent modifications of archived catalogs
CREATE OR REPLACE FUNCTION prevent_archived_catalog_modifications()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM product_catalogs
    WHERE id = COALESCE(OLD.id, NEW.catalog_id)
    AND status = 'archived'
  ) THEN
    RAISE EXCEPTION 'Cannot modify archived catalogs or their products';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to protect archived catalogs and their products
CREATE TRIGGER prevent_archived_catalog_update
  BEFORE UPDATE OR DELETE ON product_catalogs
  FOR EACH ROW
  WHEN (OLD.status = 'archived')
  EXECUTE FUNCTION prevent_archived_catalog_modifications();

CREATE TRIGGER prevent_archived_catalog_products_modification
  BEFORE INSERT OR UPDATE OR DELETE ON catalog_products
  FOR EACH ROW
  EXECUTE FUNCTION prevent_archived_catalog_modifications();

-- Update policies to explicitly prevent modifications of archived catalogs
DROP POLICY IF EXISTS "AMAP admins can manage catalogs" ON product_catalogs;
CREATE POLICY "AMAP admins can manage non-archived catalogs"
  ON product_catalogs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = product_catalogs.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
    AND (
      status != 'archived' OR
      CURRENT_SETTING('app.bypass_rls', TRUE)::boolean
    )
  );

-- Add comments for clarity
COMMENT ON FUNCTION prevent_archived_catalog_modifications() IS 'Prevents any modifications to archived catalogs and their products';