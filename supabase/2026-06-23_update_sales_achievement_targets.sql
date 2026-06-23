-- Update achievement definitions targets and descriptions
UPDATE public.achievement_definitions
SET target_count = 1000,
    description = 'Toplam 1000 urun satisi yap.',
    updated_at = timezone('utc', now())
WHERE id = 'merchant_100';

UPDATE public.achievement_definitions
SET target_count = 5000,
    description = 'Toplam 5000 urun satisi yap.',
    updated_at = timezone('utc', now())
WHERE id = 'merchant_1000';

-- Recalculate progress, is_unlocked, unlocked_at for all players for these two achievements
UPDATE public.player_achievements pa
SET 
  progress_count = LEAST(ad.target_count, COALESCE(sc.current_count, 0)),
  is_unlocked = COALESCE(sc.current_count, 0) >= ad.target_count,
  unlocked_at = CASE 
    WHEN COALESCE(sc.current_count, 0) >= ad.target_count THEN COALESCE(pa.unlocked_at, timezone('utc', now()))
    ELSE NULL
  END,
  updated_at = timezone('utc', now())
FROM public.achievement_definitions ad
CROSS JOIN (
  SELECT 
    p.id AS player_id,
    COALESCE(SUM(sdp.sold_quantity), 0)::int AS current_count
  FROM public.players p
  LEFT JOIN public.store_daily_performance sdp ON sdp.player_id = p.id
  GROUP BY p.id
) sc
WHERE pa.achievement_id = ad.id
  AND pa.player_id = sc.player_id
  AND ad.id IN ('merchant_100', 'merchant_1000');
