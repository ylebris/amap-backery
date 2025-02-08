/*
  # Add AMAP order settings

  1. New Tables
    - `amap_order_settings`
      - `id` (uuid, primary key)
      - `amap_id` (uuid, references amaps)
      - `min_order_amount` (decimal, nullable)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      - `modified_by` (uuid, references users)

  2. Changes
    - Add settings management functions
    - Add RLS policies
*/

-- Create AMAP order settings table
CREATE TABLE IF NOT EXISTS amap_order_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  min_order_amount decimal,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  modified_by uuid REFERENCES users(id) NOT NULL,
  CONSTRAINT unique_amap_settings UNIQUE (amap_id),
  CONSTRAINT valid_min_amount CHECK (min_order_amount IS NULL OR min_order_amount >= 0)
);

-- Enable RLS
ALTER TABLE amap_order_settings ENABLE ROW LEVEL SECURITY;

-- Function to update AMAP order settings
CREATE OR REPLACE FUNCTION update_amap_order_settings(
  p_amap_id uuid,
  p_min_order_amount decimal
)
RETURNS void AS $$
BEGIN
  -- Check if settings exist
  IF EXISTS (
    SELECT 1 FROM amap_order_settings
    WHERE amap_id = p_amap_id
  ) THEN
    -- Update existing settings
    UPDATE amap_order_settings
    SET min_order_amount = p_min_order_amount,
        updated_at = now(),
        modified_by = auth.uid()
    WHERE amap_id = p_amap_id;
  ELSE
    -- Create new settings
    INSERT INTO amap_order_settings (
      amap_id,
      min_order_amount,
      modified_by
    )
    VALUES (
      p_amap_id,
      p_min_order_amount,
      auth.uid()
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate order amount
CREATE OR REPLACE FUNCTION validate_order_amount(
  p_amap_id uuid,
  p_order_amount decimal
)
RETURNS boolean AS $$
DECLARE
  v_min_amount decimal;
BEGIN
  -- Get minimum order amount for AMAP
  SELECT min_order_amount INTO v_min_amount
  FROM amap_order_settings
  WHERE amap_id = p_amap_id;
  
  -- Return true if no minimum is set or amount meets minimum
  RETURN v_min_amount IS NULL OR p_order_amount >= v_min_amount;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies for order settings
CREATE POLICY "AMAP admins can manage order settings"
  ON amap_order_settings
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amap_order_settings.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Members can view order settings"
  ON amap_order_settings
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = amap_order_settings.amap_id
    )
  );

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_amap_order_settings_amap ON amap_order_settings(amap_id);
CREATE INDEX IF NOT EXISTS idx_amap_order_settings_modifier ON amap_order_settings(modified_by);

-- Add trigger for updated_at
CREATE TRIGGER update_amap_order_settings_updated_at
  BEFORE UPDATE ON amap_order_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE amap_order_settings IS 'Stores AMAP-specific order settings like minimum order amount';
COMMENT ON FUNCTION update_amap_order_settings IS 'Updates or creates AMAP order settings';
COMMENT ON FUNCTION validate_order_amount IS 'Validates if an order meets the AMAP minimum amount requirement';