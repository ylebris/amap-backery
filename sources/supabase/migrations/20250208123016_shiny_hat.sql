/*
  # Gestion des contrats récurrents et validations

  1. Nouvelles Tables
    - `recurring_contracts`: Contrats récurrents avec statut de validation
    - `recurring_contract_orders`: Commandes liées aux contrats récurrents
    - `baker_notifications`: Historique des notifications envoyées aux boulangers

  2. Modifications
    - Ajout de fonctions pour l'envoi hebdomadaire des commandes
    - Ajout de politiques pour les admins AMAP en tant que clients

  3. Sécurité
    - Politiques RLS pour toutes les nouvelles tables
    - Mise à jour des politiques existantes
*/

-- Table des contrats récurrents
CREATE TABLE IF NOT EXISTS recurring_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amap_id uuid REFERENCES amaps(id),
  baker_id uuid REFERENCES users(id),
  start_date date NOT NULL,
  end_date date NOT NULL,
  validated boolean DEFAULT false,
  validation_date timestamptz,
  validated_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des commandes de contrats récurrents
CREATE TABLE IF NOT EXISTS recurring_contract_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid REFERENCES recurring_contracts(id),
  user_id uuid REFERENCES users(id),
  product_id uuid REFERENCES ephemeral_products(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  created_at timestamptz DEFAULT now()
);

-- Table de l'historique des notifications aux boulangers
CREATE TABLE IF NOT EXISTS baker_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  baker_id uuid REFERENCES users(id),
  amap_id uuid REFERENCES amaps(id),
  sent_at timestamptz DEFAULT now(),
  notification_type text NOT NULL CHECK (notification_type IN ('recurring', 'ephemeral')),
  data jsonb
);

-- Activation RLS
ALTER TABLE recurring_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_contract_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE baker_notifications ENABLE ROW LEVEL SECURITY;

-- Fonction pour l'envoi hebdomadaire des commandes aux boulangers
CREATE OR REPLACE FUNCTION send_weekly_baker_notifications()
RETURNS void AS $$
DECLARE
  v_baker record;
  v_data jsonb;
BEGIN
  -- Pour chaque boulanger
  FOR v_baker IN 
    SELECT DISTINCT u.id, u.email
    FROM users u
    JOIN amap_baker_assignments aba ON aba.baker_id = u.id
  LOOP
    -- Récupération des commandes éphémères validées
    SELECT jsonb_build_object(
      'ephemeral_orders',
      jsonb_agg(
        jsonb_build_object(
          'order_id', eo.id,
          'amap_id', eo.amap_id,
          'delivery_date', eo.delivery_date,
          'items', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'product_name', ep.name,
                'quantity', eoi.quantity
              )
            )
            FROM ephemeral_order_items eoi
            JOIN ephemeral_products ep ON ep.id = eoi.product_id
            WHERE eoi.order_id = eo.id
          )
        )
      )
    )
    INTO v_data
    FROM ephemeral_orders eo
    WHERE eo.admin_validated = true
    AND NOT EXISTS (
      SELECT 1 FROM baker_notifications bn
      WHERE bn.baker_id = v_baker.id
      AND bn.notification_type = 'ephemeral'
      AND bn.sent_at > now() - interval '7 days'
      AND (bn.data->>'order_id')::uuid = eo.id
    );

    -- Ajout des contrats récurrents validés
    SELECT v_data || jsonb_build_object(
      'recurring_contracts',
      jsonb_agg(
        jsonb_build_object(
          'contract_id', rc.id,
          'amap_id', rc.amap_id,
          'orders', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'product_name', ep.name,
                'quantity', rco.quantity
              )
            )
            FROM recurring_contract_orders rco
            JOIN ephemeral_products ep ON ep.id = rco.product_id
            WHERE rco.contract_id = rc.id
          )
        )
      )
    )
    INTO v_data
    FROM recurring_contracts rc
    WHERE rc.baker_id = v_baker.id
    AND rc.validated = true;

    -- Enregistrement de la notification
    IF v_data IS NOT NULL THEN
      INSERT INTO baker_notifications (baker_id, notification_type, data)
      VALUES (v_baker.id, 'weekly', v_data);

      -- Ici, vous pouvez ajouter la logique d'envoi d'email
      -- PERFORM send_email(v_baker.email, 'Récapitulatif hebdomadaire des commandes', v_data);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Création d'un trigger pour la mise à jour automatique du champ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_recurring_contracts_updated_at
  BEFORE UPDATE ON recurring_contracts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Policies pour les contrats récurrents
CREATE POLICY "Les admins AMAP peuvent gérer les contrats récurrents"
  ON recurring_contracts
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM amap_members am
      WHERE am.user_id = auth.uid()
      AND am.amap_id = recurring_contracts.amap_id
      AND am.role IN ('amap_admin', 'super_admin')
    )
  );

CREATE POLICY "Les boulangers peuvent voir leurs contrats récurrents"
  ON recurring_contracts
  FOR SELECT
  USING (baker_id = auth.uid());

-- Policies pour les commandes de contrats récurrents
CREATE POLICY "Les utilisateurs peuvent gérer leurs commandes récurrentes"
  ON recurring_contract_orders
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Les admins AMAP peuvent voir toutes les commandes récurrentes"
  ON recurring_contract_orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members am
      JOIN recurring_contracts rc ON rc.amap_id = am.amap_id
      WHERE am.user_id = auth.uid()
      AND am.role IN ('amap_admin', 'super_admin')
      AND rc.id = recurring_contract_orders.contract_id
    )
  );

-- Policies pour les notifications aux boulangers
CREATE POLICY "Les boulangers peuvent voir leurs notifications"
  ON baker_notifications
  FOR SELECT
  USING (baker_id = auth.uid());

CREATE POLICY "Les admins peuvent voir toutes les notifications"
  ON baker_notifications
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM amap_members
      WHERE user_id = auth.uid()
      AND role IN ('amap_admin', 'super_admin')
    )
  );

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_recurring_contracts_amap ON recurring_contracts(amap_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contracts_baker ON recurring_contracts(baker_id);
CREATE INDEX IF NOT EXISTS idx_recurring_contract_orders_contract ON recurring_contract_orders(contract_id);
CREATE INDEX IF NOT EXISTS idx_baker_notifications_baker ON baker_notifications(baker_id);
CREATE INDEX IF NOT EXISTS idx_baker_notifications_sent_at ON baker_notifications(sent_at);