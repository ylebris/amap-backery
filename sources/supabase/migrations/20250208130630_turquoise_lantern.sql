/*
  # Add check payment validation

  1. New Tables
    - `check_payments`
      - `id` (uuid, primary key)
      - `order_id` (uuid, references ephemeral_orders)
      - `issuer_name` (text)
      - `check_number` (text)
      - `bank_name` (text)
      - `validated_at` (timestamptz)
      - `validated_by` (uuid, references users)
      - `created_at` (timestamptz)

  2. Changes
    - Add payment validation requirement to ephemeral_orders
    - Update policies to require payment validation
    - Add validation functions and triggers
*/

-- Create check payments table
CREATE TABLE IF NOT EXISTS check_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES ephemeral_orders(id) ON DELETE CASCADE,
  issuer_name text NOT NULL,
  check_number text NOT NULL,
  bank_name text NOT NULL,
  validated_at timestamptz,
  validated_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  CONSTRAINT unique_check_number_per_bank UNIQUE (check_number, bank_name)
);

-- Enable RLS
ALTER TABLE check_payments ENABLE ROW LEVEL SECURITY;

-- Add payment validation requirement to orders
ALTER TABLE ephemeral_orders
ADD COLUMN IF NOT EXISTS payment_validated boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS payment_validated_at timestamptz,
ADD COLUMN IF NOT EXISTS payment_validated_by uuid REFERENCES users(id);

-- Function to validate check payment
CREATE OR REPLACE FUNCTION validate_check_payment(
  p_order_id uuid,
  p_issuer_name text,
  p_check_number text,
  p_bank_name text
)
RETURNS void AS $$
BEGIN
  -- Verify admin rights
  IF NOT EXISTS (
    SELECT 1 FROM ephemeral_orders eo
    JOIN amap_members am ON am.amap_id = eo.amap_id
    WHERE eo.id = p_order_id
    AND am.user_id = auth.uid()
    AND am.role IN ('amap_admin', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'Only AMAP administrators can validate payments';
  END IF;

  -- Create check payment record
  INSERT INTO check_payments (
    order_id,
    issuer_name,
    check_number,
    bank_name,
    validated_at,
    validated_by
  )
  VALUES (
    p_order_id,
    p_issuer_name,
    p_check_number,
    p_bank_name,
    now(),
    auth.uid()
  );

  -- Update order status
  UPDATE ephemeral_orders
  SET payment_validated = true,
      payment_validated_at = now(),
      payment_validated_by = auth.uid(),
      status = 'confirmed'
  WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies for check payments
CREATE POLICY "AMAP admins can manage check payments"
  ON check_payments
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM ephemeral_orders eo
      JOIN amap_members am ON am.amap_id = eo.amap_id
      WHERE eo.id = check_payments.order_id
      AND am.user_id = auth.uid()
      AND am.role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Members can view their check payments"
  ON check_payments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM ephemeral_orders
      WHERE id = check_payments.order_id
      AND user_id = auth.uid()
    )
  );

-- Update order policies
DROP POLICY IF EXISTS "Members can manage their pending orders" ON ephemeral_orders;
CREATE POLICY "Members can manage their pending orders"
  ON ephemeral_orders
  FOR ALL
  USING (
    user_id = auth.uid() 
    AND status = 'pending'
    AND NOT payment_validated
  )
  WITH CHECK (
    user_id = auth.uid() 
    AND status = 'pending'
    AND NOT payment_validated
  );

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_check_payments_order ON check_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_check_payments_validator ON check_payments(validated_by);
CREATE INDEX IF NOT EXISTS idx_ephemeral_orders_payment_validator ON ephemeral_orders(payment_validated_by);

COMMENT ON TABLE check_payments IS 'Stores check payment information and validation status';
COMMENT ON FUNCTION validate_check_payment IS 'Validates a check payment for an order and updates order status';