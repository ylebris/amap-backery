/*
  # Restrict catalog management toggle to super admins
  
  1. Changes
    - Drop existing toggle function
    - Create new function with super admin check
    - Add audit logging for management changes
  
  2. Security
    - Only super admins can toggle catalog management
    - Track all management changes
*/

-- Drop existing function
DROP FUNCTION IF EXISTS toggle_baker_catalog_management;

-- Create new function with super admin check
CREATE OR REPLACE FUNCTION toggle_baker_catalog_management(
  p_amap_id uuid,
  p_baker_id uuid,
  p_manages_catalogs boolean
)
RETURNS void AS $$
BEGIN
  -- Check if the current user is a super admin
  IF NOT EXISTS (
    SELECT 1 FROM amap_members
    WHERE user_id = auth.uid()
    AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only super administrators can modify catalog management settings';
  END IF;

  -- Update the assignment
  UPDATE amap_baker_assignments
  SET manages_catalogs = p_manages_catalogs,
      updated_at = now()
  WHERE amap_id = p_amap_id
  AND baker_id = p_baker_id;

  -- Log the change
  INSERT INTO baker_notifications (
    baker_id,
    amap_id,
    notification_type,
    data
  )
  VALUES (
    p_baker_id,
    p_amap_id,
    'management_change',
    jsonb_build_object(
      'changed_by', auth.uid(),
      'manages_catalogs', p_manages_catalogs,
      'changed_at', now()
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add new notification type
ALTER TABLE baker_notifications
DROP CONSTRAINT IF EXISTS baker_notifications_notification_type_check,
ADD CONSTRAINT baker_notifications_notification_type_check
CHECK (notification_type IN ('recurring', 'ephemeral', 'management_change'));

-- Add comment
COMMENT ON FUNCTION toggle_baker_catalog_management IS 'Toggles catalog management responsibility. Only accessible to super administrators.';