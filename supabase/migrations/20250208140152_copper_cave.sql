-- Suppression des données existantes
DELETE FROM amap_baker_assignments;
DELETE FROM amap_members;
DELETE FROM amaps;
DELETE FROM user_roles;
DELETE FROM users;

-- Suppression des données d'authentification Supabase
DELETE FROM auth.identities;
DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;
DELETE FROM auth.mfa_amr_claims;
DELETE FROM auth.mfa_challenges;
DELETE FROM auth.mfa_factors;
DELETE FROM auth.users;

-- Activation de l'authentification par email
UPDATE auth.config 
SET enable_signup = true,
    enable_confirmations = false,
    mailer_autoconfirm = true,
    sms_autoconfirm = true;

-- Mise à jour des paramètres de sécurité
UPDATE auth.config
SET jwt_exp = 3600,
    security_update_password_require_reauthentication = false;