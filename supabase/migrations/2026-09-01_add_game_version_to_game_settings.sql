-- Add game version to game_settings
INSERT INTO public.game_settings (key, value_text, description, updated_at)
VALUES (
  'game_version',
  '1.0.0',
  'Oyunun mevcut surum numarasi (pubspec.yaml ile senkronize tutulmalidir)',
  now()
)
ON CONFLICT (key) DO UPDATE
  SET value_text = EXCLUDED.value_text,
      description = EXCLUDED.description,
      updated_at = now();
