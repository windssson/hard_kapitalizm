alter table public.players
  add column if not exists google_email text,
  add column if not exists google_avatar_url text;

create or replace function public.sync_player_google_profile(
  p_player_name text default null,
  p_google_email text default null,
  p_google_avatar_url text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_player_id uuid := auth.uid();
  v_trimmed_player_name text := nullif(trim(coalesce(p_player_name, '')), '');
  v_trimmed_google_email text := nullif(trim(coalesce(p_google_email, '')), '');
  v_trimmed_google_avatar_url text := nullif(trim(coalesce(p_google_avatar_url, '')), '');
begin
  if v_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  update public.players
  set
    player_name = coalesce(v_trimmed_player_name, player_name),
    google_email = coalesce(v_trimmed_google_email, google_email),
    google_avatar_url = coalesce(v_trimmed_google_avatar_url, google_avatar_url)
  where id = v_player_id;

  perform public.refresh_player_leaderboard_stats(v_player_id);

  return jsonb_build_object(
    'success', true,
    'player_id', v_player_id,
    'player_name', v_trimmed_player_name,
    'google_email', v_trimmed_google_email,
    'google_avatar_url', v_trimmed_google_avatar_url
  );
end;
$function$;

revoke all on function public.sync_player_google_profile(text, text, text) from public;
grant execute on function public.sync_player_google_profile(text, text, text) to authenticated;
grant execute on function public.sync_player_google_profile(text, text, text) to service_role;
