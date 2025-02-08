/*
  # Gestion des dates de non-livraison et décalage des contrats

  1. Nouvelles Tables
    - `amap_delivery_settings`: Configuration des délais de modification par AMAP
    - `delivery_exceptions`: Dates de non-livraison (AMAP, boulanger, adhérent)
    - `contract_adjustments`: Historique des ajustements de dates de fin de contrat

  2. Modifications
    - Ajout de fonctions pour le calcul automatique des dates de fin de contrat
    - Ajout de politiques pour la gestion des exceptions

  3. Sécurité
    - Politiques RLS pour toutes les nouvelles tables
*/

-- Configuration des délais par AMAP
CREATE TABLE IF NOT EXISTS amap_delivery_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id) ON DELETE CASCADE,
  min_days_notice integer NOT NULL DEFAULT 7,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_min_days CHECK (min_days_notice >= 0)
);

-- Table des exceptions de livraison
CREATE TABLE IF NOT EXISTS delivery_exceptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id),
  contract_id uuid REFERENCES recurring_contracts(id),
  user_id uuid REFERENCES users(id),
  exception_date date NOT NULL,
  exception_type text NOT NULL CHECK (
    exception_type IN ('holiday', 'baker_closed', 'member_absent')
  ),
  created_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_exception_combination CHECK (
    (exception_type = 'holiday' AND amap_id IS NOT NULL AND contract_id IS NULL AND user_id IS NULL) OR
    (exception_type = 'baker_closed' AND contract_id IS NOT NULL AND amap_id IS NULL AND user_id IS NULL) OR
    (exception_type = 'member_absent' AND user_id IS NOT NULL AND contract_id IS NOT NULL AND amap_id IS NULL)
  )
);

-- Table des ajustements de contrats
CREATE TABLE IF NOT EXISTS contract_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid REFERENCES recurring_contracts(id),
  original_end_date date NOT NULL,
  new_end_date date NOT NULL,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES users(id) NOT NULL
);

-- Activation RLS
ALTER TABLE amap_delivery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_exceptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_adjustments ENABLE ROW LEVEL SECURITY;

-- Fonction pour vérifier si une exception peut être créée
CREATE OR REPLACE FUNCTION can_create_delivery_exception(
  p_amap_id uuid,
  p_exception_date date,
  p_min_days_notice integer
)
RETURNS boolean AS $$
BEGIN
  RETURN p_exception_date >= CURRENT_DATE + (p_min_days_notice || ' days')::interval;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fonction pour recalculer la date de fin d'un contrat
CREATE OR REPLACE FUNCTION recalculate_contract_end_date(p_contract_id uuid)
RETURNS date AS $$
DECLARE
  v_contract record;
  v_total_exceptions integer;
  v_new_end_date date;
BEGIN
  -- Récupération des informations du contrat
  SELECT * INTO v_contract
  FROM recurring_contracts
  WHERE id = p_contract_id;

  -- Compte des exceptions
  SELECT COUNT(*) INTO v_total_exceptions
  FROM delivery_exceptions
  WHERE contract_id = p_contract_id
  AND exception_date BETWEEN v_contract.start_date AND v_contract.end_date;

  -- Calcul de la nouvelle date de fin
  v_new_end_date := v_contract.end_date + (v_total_exceptions || ' weeks')::interval;

  -- Enregistrement de l'ajustement
  INSERT INTO contract_adjustments (
    contract_id,
    original_end_date,
    new_end_date,
    reason,
    created_by
  )
  VALUES (
    p_contract_id,
    v_contract.end_date,
    v_new_end_date,
    'Ajustement automatique pour exceptions de livraison',
    auth.uid()
  );

  -- Mise à jour du contrat
  UPDATE recurring_contracts
  SET end_date = v_new_end_date,
      updated_at = now()
  WHERE id = p_contract_id;

  RETURN v_new_end_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger pour recalculer la date de fin après une nouvelle exception
CREATE OR REPLACE FUNCTION trigger_recalculate_contract_end_date()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.contract_id IS NOT NULL THEN
    PERFORM recalculate_contract_end_date(NEW.contract_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_delivery_exception_insert
  AFTER INSERT ON delivery_exceptions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_recalculate_contract_end_date();

-- Policies pour les paramètres de livraison
CREATE POLICY "Les admins AMAP peuvent gérer les paramètres"
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

-- Policies pour les exceptions de livraison
CREATE POLICY "Les AMAP peuvent gérer les jours fériés"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'holiday' AND
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND amap_id = delivery_exceptions.amap_id
      AND role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Les boulangers peuvent gérer leurs fermetures"
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

CREATE POLICY "Les adhérents peuvent gérer leurs absences"
  ON delivery_exceptions
  FOR ALL
  USING (
    exception_type = 'member_absent' AND
    user_id = auth.uid()
  );

-- Policies pour les ajustements de contrats
CREATE POLICY "Lecture des ajustements de contrats"
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

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_date ON delivery_exceptions(exception_date);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_contract ON delivery_exceptions(contract_id);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_amap ON delivery_exceptions(amap_id);
CREATE INDEX IF NOT EXISTS idx_delivery_exceptions_user ON delivery_exceptions(user_id);
CREATE INDEX IF NOT EXISTS idx_contract_adjustments_contract ON contract_adjustments(contract_id);