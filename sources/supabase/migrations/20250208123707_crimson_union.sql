/*
  # Configuration des jours de livraison par AMAP

  1. Nouvelles Tables
    - `amap_delivery_days`: Configuration des jours de livraison par AMAP
      - `amap_id`: ID de l'AMAP
      - `delivery_day`: Jour de la semaine (0-6, 0 = dimanche)
      - `active`: Si le jour est actif
      - Historique des modifications

  2. Modifications
    - Ajout de contraintes pour s'assurer qu'un seul jour est actif par AMAP
    - Ajout de politiques pour la gestion des jours de livraison

  3. Sécurité
    - Seuls les admins AMAP peuvent modifier les jours de livraison
*/

-- Table des jours de livraison par AMAP
CREATE TABLE IF NOT EXISTS amap_delivery_days (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  delivery_day integer NOT NULL CHECK (delivery_day BETWEEN 0 AND 6),
  active boolean DEFAULT true,
  modified_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT unique_active_delivery_day UNIQUE (amap_id, delivery_day, active)
);

-- Fonction pour s'assurer qu'un seul jour est actif par AMAP
CREATE OR REPLACE FUNCTION ensure_single_active_delivery_day()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.active THEN
    -- Désactiver les autres jours actifs pour cette AMAP
    UPDATE amap_delivery_days
    SET active = false,
        updated_at = now(),
        modified_by = NEW.modified_by
    WHERE amap_id = NEW.amap_id
    AND id != NEW.id
    AND active = true;
  ELSE
    -- Vérifier qu'il reste au moins un jour actif
    IF NOT EXISTS (
      SELECT 1 FROM amap_delivery_days
      WHERE amap_id = NEW.amap_id
      AND active = true
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Au moins un jour de livraison doit être actif';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour gérer les jours actifs
CREATE TRIGGER ensure_single_active_delivery_day
  BEFORE INSERT OR UPDATE OF active ON amap_delivery_days
  FOR EACH ROW
  EXECUTE FUNCTION ensure_single_active_delivery_day();

-- Trigger pour la mise à jour automatique de updated_at
CREATE TRIGGER update_amap_delivery_days_updated_at
  BEFORE UPDATE ON amap_delivery_days
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Activation RLS
ALTER TABLE amap_delivery_days ENABLE ROW LEVEL SECURITY;

-- Policies pour les jours de livraison
CREATE POLICY "Les admins AMAP peuvent gérer les jours de livraison"
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

CREATE POLICY "Tout le monde peut voir les jours de livraison"
  ON amap_delivery_days
  FOR SELECT
  USING (true);

-- Fonction pour obtenir le jour de livraison actif d'une AMAP
CREATE OR REPLACE FUNCTION get_amap_delivery_day(p_amap_id uuid)
RETURNS integer AS $$
DECLARE
  v_delivery_day integer;
BEGIN
  SELECT delivery_day INTO v_delivery_day
  FROM amap_delivery_days
  WHERE amap_id = p_amap_id
  AND active = true;
  
  RETURN v_delivery_day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour valider qu'une date correspond au jour de livraison
CREATE OR REPLACE FUNCTION is_valid_delivery_date(p_amap_id uuid, p_date date)
RETURNS boolean AS $$
DECLARE
  v_delivery_day integer;
BEGIN
  SELECT delivery_day INTO v_delivery_day
  FROM amap_delivery_days
  WHERE amap_id = p_amap_id
  AND active = true;
  
  RETURN EXTRACT(DOW FROM p_date) = v_delivery_day;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_amap_delivery_days_amap ON amap_delivery_days(amap_id);
CREATE INDEX IF NOT EXISTS idx_amap_delivery_days_active ON amap_delivery_days(amap_id, active);