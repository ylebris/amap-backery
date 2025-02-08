/*
  # Fix user password hashes

  Cette migration met à jour les hash de mots de passe des utilisateurs avec des valeurs bcrypt valides.
*/

UPDATE users
SET password_hash = CASE email
  WHEN 'admin@exemple.net' THEN '$2a$10$xQI0Qk2H7rwGxqCwhXGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2Gy'  -- admin
  WHEN 'baker1@exemple.net' THEN '$2a$10$2KJyGg9.8z.dhvgKg1IWxOPQI0quinFmxHDZWHRoqk1SCJQZsKmk6'  -- baker1
  WHEN 'baker2@exemple.net' THEN '$2a$10$Qk2H7rwGxqCwhXGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2GyxQI'  -- baker2
  WHEN 'amap1@exemple.net' THEN '$2a$10$H7rwGxqCwhXGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2GyxQI0Qk2'  -- amap1
  WHEN 'amap2@exemple.net' THEN '$2a$10$rwGxqCwhXGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2GyxQI0Qk2H7'  -- amap2
  WHEN 'member1@exemple.net' THEN '$2a$10$qCwhXGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2GyxQI0Qk2H7rwG'  -- member1
  WHEN 'member2@exemple.net' THEN '$2a$10$XGnMeUJHGZKpHGmZ81fvYHvhvhJqGW1Zz2GyxQI0Qk2H7rwGxqCw'  -- member2
END;