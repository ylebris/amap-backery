/*
  # Mise à jour des contrats éphémères

  1. Modifications
    - Ajout de la contrainte de 10 jours pour les commandes
    - Ajout du champ notification_sent pour les commandes
    - Ajout du champ admin_validated pour les commandes
    - Ajout de triggers pour les notifications par email

  2. Sécurité
    - Mise à jour des politiques pour inclure la validation admin
*/

-- Ajout des colonnes pour la gestion des commandes
ALTER TABLE ephemeral_orders 
ADD COLUMN IF NOT EXISTS admin_validated boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS notification_sent boolean DEFAULT false,
ADD CONSTRAINT order_deadline_check 
  CHECK (delivery_date >= CURRENT_DATE + INTERVAL '10 days');

-- Fonction pour vérifier si une commande peut être modifiée
CREATE OR REPLACE FUNCTION check_order_deadline()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.delivery_date < CURRENT_DATE + INTERVAL '10 days' THEN
    RAISE EXCEPTION 'Les commandes doivent être passées au moins 10 jours avant la livraison';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour vérifier la date limite des commandes
DO $$ BEGIN
  CREATE TRIGGER enforce_order_deadline
    BEFORE INSERT OR UPDATE ON ephemeral_orders
    FOR EACH ROW
    EXECUTE FUNCTION check_order_deadline();
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Fonction pour les notifications par email
CREATE OR REPLACE FUNCTION notify_order_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status != OLD.status THEN
    -- Notification à l'adhérent
    IF NEW.status = 'confirmed' THEN
      PERFORM net.http_post(
        url := current_setting('app.notify_url', true),
        body := json_build_object(
          'type', 'order_confirmed',
          'user_id', NEW.user_id,
          'order_id', NEW.id
        )::jsonb
      );
    END IF;

    -- Notification au boulanger (uniquement pour les commandes validées)
    IF NEW.status = 'confirmed' AND NEW.admin_validated = true THEN
      PERFORM net.http_post(
        url := current_setting('app.notify_url', true),
        body := json_build_object(
          'type', 'baker_notification',
          'order_id', NEW.id
        )::jsonb
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour les notifications
DO $$ BEGIN
  CREATE TRIGGER order_status_notification
    AFTER UPDATE OF status ON ephemeral_orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status();
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Mise à jour des politiques existantes
DROP POLICY IF EXISTS "Les utilisateurs peuvent modifier leurs propres commandes en attente" ON ephemeral_orders;
CREATE POLICY "Les utilisateurs peuvent modifier leurs propres commandes en attente"
  ON ephemeral_orders
  FOR UPDATE
  USING (
    auth.uid() = user_id 
    AND status = 'pending' 
    AND delivery_date >= CURRENT_DATE + INTERVAL '10 days'
  )
  WITH CHECK (
    auth.uid() = user_id 
    AND status = 'pending'
    AND delivery_date >= CURRENT_DATE + INTERVAL '10 days'
  );

-- Nouvelle politique pour les administrateurs
CREATE POLICY "Les administrateurs peuvent gérer toutes les commandes"
  ON ephemeral_orders
  FOR ALL
  USING (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'))
  WITH CHECK (auth.uid() IN (SELECT user_id FROM user_roles WHERE role = 'admin'));