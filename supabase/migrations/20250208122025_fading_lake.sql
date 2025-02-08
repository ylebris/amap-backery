/*
  # Structure Multi-AMAP

  1. Nouvelles Tables
    - `amaps`: Stocke les informations des AMAPs
    - `amap_members`: Associe les utilisateurs aux AMAPs avec leurs rôles
    - `amap_baker_assignments`: Associe les boulangers aux AMAPs

  2. Sécurité
    - Politiques RLS pour chaque table
    - Gestion des accès par rôle
*/

-- Table des AMAPs
CREATE TABLE IF NOT EXISTS amaps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des membres d'AMAP
CREATE TABLE IF NOT EXISTS amap_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('super_admin', 'amap_admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(amap_id, user_id)
);

-- Table d'association AMAP-Boulanger
CREATE TABLE IF NOT EXISTS amap_baker_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  baker_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(amap_id, baker_id)
);

-- Activation RLS
ALTER TABLE amaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE amap_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE amap_baker_assignments ENABLE ROW LEVEL SECURITY;

-- Mise à jour des tables existantes
ALTER TABLE ephemeral_contract_periods 
ADD COLUMN IF NOT EXISTS amap_id uuid REFERENCES amaps(id);

ALTER TABLE ephemeral_orders 
ADD COLUMN IF NOT EXISTS amap_id uuid REFERENCES amaps(id);

-- Fonctions utilitaires
CREATE OR REPLACE FUNCTION get_user_amaps(p_user_id uuid)
RETURNS TABLE (amap_id uuid, role text) AS $$
BEGIN
  RETURN QUERY
  SELECT am.amap_id, am.role
  FROM amap_members am
  WHERE am.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_super_admin(p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM amap_members 
    WHERE user_id = p_user_id AND role = 'super_admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policies pour les AMAPs
CREATE POLICY "Les super-admins peuvent tout faire"
  ON amaps
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT user_id 
      FROM amap_members 
      WHERE role = 'super_admin'
    )
  );

CREATE POLICY "Tout le monde peut voir les AMAPs"
  ON amaps
  FOR SELECT
  USING (true);

-- Policies pour les membres d'AMAP
CREATE POLICY "Les super-admins gèrent tous les membres"
  ON amap_members
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT user_id 
      FROM amap_members 
      WHERE role = 'super_admin'
    )
  );

CREATE POLICY "Les admins d'AMAP gèrent leurs membres"
  ON amap_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 
      FROM amap_members am 
      WHERE am.user_id = auth.uid() 
      AND am.role = 'amap_admin'
      AND am.amap_id = amap_members.amap_id
    )
  );

-- Policies pour les assignations de boulangers
CREATE POLICY "Les super-admins gèrent les assignations"
  ON amap_baker_assignments
  FOR ALL
  USING (
    auth.uid() IN (
      SELECT user_id 
      FROM amap_members 
      WHERE role = 'super_admin'
    )
  );

-- Mise à jour des policies existantes pour les contrats éphémères
CREATE POLICY "Les admins d'AMAP gèrent leurs contrats"
  ON ephemeral_contract_periods
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 
      FROM amap_members am 
      WHERE am.user_id = auth.uid() 
      AND am.role IN ('amap_admin', 'super_admin')
      AND am.amap_id = ephemeral_contract_periods.amap_id
    )
  );

CREATE POLICY "Les boulangers gèrent les contrats de leurs AMAPs"
  ON ephemeral_contract_periods
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 
      FROM amap_baker_assignments aba 
      WHERE aba.baker_id = auth.uid() 
      AND aba.amap_id = ephemeral_contract_periods.amap_id
    )
  );