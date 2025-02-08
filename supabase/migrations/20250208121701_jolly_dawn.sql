/*
  # Ajout du rôle boulanger

  1. Modifications
    - Ajout du rôle 'baker' dans les user_roles
    - Ajout des politiques spécifiques pour le boulanger
    - Modification des contraintes de rôle

  2. Sécurité
    - Politiques RLS pour le boulanger
*/

-- Mise à jour de la contrainte de rôle pour inclure le boulanger
ALTER TABLE user_roles 
DROP CONSTRAINT IF EXISTS user_roles_role_check,
ADD CONSTRAINT user_roles_role_check 
  CHECK (role IN ('admin', 'user', 'baker'));

-- Politiques pour le boulanger sur les périodes de contrats
CREATE POLICY "Le boulanger peut gérer les périodes de contrats"
  ON ephemeral_contract_periods
  FOR ALL
  USING (
    auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'baker')
    OR auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  )
  WITH CHECK (
    auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'baker')
    OR auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  );

-- Politiques pour le boulanger sur les produits
CREATE POLICY "Le boulanger peut gérer les produits"
  ON ephemeral_products
  FOR ALL
  USING (
    auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'baker')
    OR auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  )
  WITH CHECK (
    auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'baker')
    OR auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin')
  );

-- Politiques pour le boulanger sur les commandes (lecture seule)
CREATE POLICY "Le boulanger peut voir toutes les commandes"
  ON ephemeral_orders
  FOR SELECT
  USING (
    auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'baker')
  );

-- Fonction pour vérifier si l'utilisateur est un boulanger
CREATE OR REPLACE FUNCTION is_baker(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM user_roles 
    WHERE user_id = $1 AND role = 'baker'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;