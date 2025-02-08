-- Suppression de la contrainte de délai minimum pour les commandes
ALTER TABLE amap_delivery_settings
DROP COLUMN IF EXISTS min_days_notice;

-- Ajout d'une contrainte pour un seul boulanger par AMAP
ALTER TABLE amap_baker_assignments
ADD CONSTRAINT single_baker_per_amap UNIQUE (amap_id);

-- Mise à jour des politiques pour les admin AMAP
DROP POLICY IF EXISTS "AMAP admins can manage members" ON amap_members;
CREATE POLICY "AMAP admins can manage non-baker members"
  ON amap_members
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members am
      WHERE am.user_id = auth.uid()
      AND am.amap_id = amap_members.amap_id
      AND am.role = 'amap_admin'
    )
    AND amap_members.role NOT IN ('baker', 'super_admin')
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM amap_members am
      WHERE am.user_id = auth.uid()
      AND am.amap_id = amap_members.amap_id
      AND am.role = 'amap_admin'
    )
    AND amap_members.role NOT IN ('baker', 'super_admin')
  );

-- Mise à jour des politiques pour les assignations de boulangers
DROP POLICY IF EXISTS "AMAP admins can manage baker assignments" ON amap_baker_assignments;
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

-- Ajout de commentaires
COMMENT ON CONSTRAINT single_baker_per_amap ON amap_baker_assignments IS 'Ensures only one baker can be assigned to an AMAP';
COMMENT ON POLICY "AMAP admins can manage non-baker members" ON amap_members IS 'AMAP admins can only manage regular members, not bakers or super admins';
COMMENT ON POLICY "Only super admins can manage baker assignments" ON amap_baker_assignments IS 'Only super administrators can assign or remove bakers from AMAPs';