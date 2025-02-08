/*
  # Mise à jour des politiques pour les adhérents

  1. Restrictions
    - Vue limitée aux propres commandes
    - Vue limitée aux propres contrats
    - Modification limitée aux commandes non validées
  
  2. Sécurité
    - Ajout de politiques RLS spécifiques
    - Mise à jour des contraintes temporelles
*/

-- Mise à jour des politiques pour les commandes éphémères
DROP POLICY IF EXISTS "Users can manage their own orders" ON ephemeral_orders;
CREATE POLICY "Members can manage their pending orders"
  ON ephemeral_orders
  FOR ALL
  USING (
    user_id = auth.uid() 
    AND status = 'pending'
    AND NOT admin_validated
  )
  WITH CHECK (
    user_id = auth.uid() 
    AND status = 'pending'
    AND NOT admin_validated
  );

CREATE POLICY "Members can view their confirmed orders"
  ON ephemeral_orders
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND status != 'pending'
  );

-- Mise à jour des politiques pour les contrats récurrents
DROP POLICY IF EXISTS "Users can manage their own recurring orders" ON recurring_contract_orders;
CREATE POLICY "Members can manage their recurring orders"
  ON recurring_contract_orders
  FOR ALL
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM recurring_contracts rc
      WHERE rc.id = contract_id
      AND NOT rc.validated
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM recurring_contracts rc
      WHERE rc.id = contract_id
      AND NOT rc.validated
    )
  );

CREATE POLICY "Members can view their validated recurring orders"
  ON recurring_contract_orders
  FOR SELECT
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM recurring_contracts rc
      WHERE rc.id = contract_id
      AND rc.validated
    )
  );

-- Mise à jour des politiques pour les absences
DROP POLICY IF EXISTS "Members can manage their absences" ON delivery_exceptions;
CREATE POLICY "Members can manage their absences"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'member_absent'
    AND user_id = auth.uid()
    AND exception_date >= CURRENT_DATE + INTERVAL '10 days'
  )
  WITH CHECK (
    exception_type = 'member_absent'
    AND user_id = auth.uid()
    AND exception_date >= CURRENT_DATE + INTERVAL '10 days'
  );

-- Ajout de commentaires
COMMENT ON POLICY "Members can manage their pending orders" ON ephemeral_orders IS 'Les adhérents peuvent gérer leurs commandes en attente uniquement';
COMMENT ON POLICY "Members can view their confirmed orders" ON ephemeral_orders IS 'Les adhérents peuvent voir leurs commandes confirmées';
COMMENT ON POLICY "Members can manage their recurring orders" ON recurring_contract_orders IS 'Les adhérents peuvent gérer leurs commandes récurrentes non validées';
COMMENT ON POLICY "Members can view their validated recurring orders" ON recurring_contract_orders IS 'Les adhérents peuvent voir leurs commandes récurrentes validées';
COMMENT ON POLICY "Members can manage their absences" ON delivery_exceptions IS 'Les adhérents peuvent gérer leurs absences avec un préavis de 10 jours';