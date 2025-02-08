/*
  # English Translation Migration

  1. Changes
    - Translates all error messages to English
    - Translates all policy names to English
    - Translates all comments to English
    - Translates all function names to English
    - Updates constraint names to English
    - Updates check constraint values to English

  2. Tables Modified
    - delivery_exceptions: Updates exception_type values
    - All policy names updated to English
    - All function names and parameters updated to English
    - All error messages updated to English

  3. Security
    - All existing RLS policies maintained
    - All security checks preserved
*/

-- Update exception types in delivery_exceptions
ALTER TABLE delivery_exceptions
DROP CONSTRAINT IF EXISTS delivery_exceptions_exception_type_check,
ADD CONSTRAINT delivery_exceptions_exception_type_check
  CHECK (exception_type IN ('public_holiday', 'baker_closed', 'member_absent'));

-- Update error messages in functions
CREATE OR REPLACE FUNCTION ensure_single_active_delivery_day()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.active THEN
    -- Deactivate other active days for this AMAP
    UPDATE amap_delivery_days
    SET active = false,
        updated_at = now(),
        modified_by = NEW.modified_by
    WHERE amap_id = NEW.amap_id
    AND id != NEW.id
    AND active = true;
  ELSE
    -- Ensure at least one active day remains
    IF NOT EXISTS (
      SELECT 1 FROM amap_delivery_days
      WHERE amap_id = NEW.amap_id
      AND active = true
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'At least one delivery day must remain active';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update contract adjustment reason to English
UPDATE contract_adjustments
SET reason = 'Automatic adjustment for delivery exceptions'
WHERE reason = 'Ajustement automatique pour exceptions de livraison';

-- Drop and recreate policies with English names
DO $$ 
BEGIN
  -- AMAP delivery settings policies
  DROP POLICY IF EXISTS "Les admins AMAP peuvent gérer les paramètres" ON amap_delivery_settings;
  DROP POLICY IF EXISTS "Les AMAP peuvent gérer les jours fériés" ON delivery_exceptions;
  DROP POLICY IF EXISTS "Les boulangers peuvent gérer leurs fermetures" ON delivery_exceptions;
  DROP POLICY IF EXISTS "Les adhérents peuvent gérer leurs absences" ON delivery_exceptions;
  DROP POLICY IF EXISTS "Lecture des ajustements de contrats" ON contract_adjustments;
  DROP POLICY IF EXISTS "Les admins AMAP peuvent gérer les jours de livraison" ON amap_delivery_days;
  DROP POLICY IF EXISTS "Tout le monde peut voir les jours de livraison" ON amap_delivery_days;
END $$;

-- Recreate policies with English names
CREATE POLICY "AMAP admins can manage delivery settings"
  ON amap_delivery_settings
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amap_delivery_settings.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "AMAP admins can manage public holidays"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'public_holiday' AND
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = delivery_exceptions.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Bakers can manage their closures"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'baker_closed' AND
    EXISTS (
      SELECT 1 FROM recurring_contracts
      WHERE id = delivery_exceptions.contract_id
      AND baker_id = auth.uid()
    )
  );

CREATE POLICY "Members can manage their absences"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'member_absent' AND
    user_id = auth.uid()
  );

CREATE POLICY "Contract adjustments can be viewed by relevant parties"
  ON contract_adjustments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM recurring_contracts rc
      LEFT JOIN amap_members am ON am.amap_id = rc.amap_id
      WHERE rc.id = contract_adjustments.contract_id
      AND (
        rc.baker_id = auth.uid() OR
        am.user_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM recurring_contract_orders rco
          WHERE rco.contract_id = rc.id
          AND rco.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "AMAP admins can manage delivery days"
  ON amap_delivery_days
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amap_delivery_days.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Everyone can view delivery days"
  ON amap_delivery_days
  FOR SELECT
  USING (true);

-- Update existing data to match new exception types
UPDATE delivery_exceptions
SET exception_type = 'public_holiday'
WHERE exception_type = 'holiday';

COMMENT ON TABLE delivery_exceptions IS 'Stores delivery exceptions including public holidays, baker closures, and member absences';
COMMENT ON TABLE amap_delivery_settings IS 'Stores AMAP-specific delivery settings and constraints';
COMMENT ON TABLE contract_adjustments IS 'Tracks changes to contract end dates due to delivery exceptions';
COMMENT ON TABLE amap_delivery_days IS 'Defines delivery days for each AMAP';