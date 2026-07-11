-- Redefine set_player_avatar to not update non-existent 'updated_at' column in players table
CREATE OR REPLACE FUNCTION public.set_player_avatar(p_avatar_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.players
  set avatar_id = p_avatar_id
  where id = auth.uid()
  returning *
  into v_player;

  if not found then
    raise exception 'Oyuncu kaydi bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Avatar guncellendi.',
    'player', to_jsonb(v_player)
  );
end;
$function$;
