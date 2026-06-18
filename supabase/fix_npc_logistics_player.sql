do $$
declare
  v_id uuid;
begin
  select value_text::uuid
  into v_id
  from public.game_settings
  where key = 'npc_logistics_player_id';

  if v_id is null then
    raise exception 'npc_logistics_player_id ayari bulunamadi.';
  end if;

  if not exists (select 1 from auth.users where id = v_id) then
    insert into auth.users (
      id,
      aud,
      role,
      email,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      is_sso_user,
      is_anonymous
    ) values (
      v_id,
      'authenticated',
      'authenticated',
      'npc-logistics@hardkapitalizm.local',
      timezone('utc', now()),
      '{"provider":"email","providers":["email"],"npc":true}'::jsonb,
      '{"display_name":"NPC Lojistik"}'::jsonb,
      timezone('utc', now()),
      timezone('utc', now()),
      false,
      false
    );
  end if;

  if not exists (select 1 from public.players where id = v_id) then
    insert into public.players (
      id,
      company_name,
      avatar_id,
      level,
      experience,
      cash,
      gold,
      created_at,
      player_name,
      google_email,
      google_avatar_url
    ) values (
      v_id,
      'NPC Lojistik',
      'ae1.webp',
      1,
      0,
      0,
      0,
      timezone('utc', now()),
      'NPC Lojistik',
      null,
      null
    );
  end if;
end $$;

select id, company_name, player_name
from public.players
where id = (
  select value_text::uuid
  from public.game_settings
  where key = 'npc_logistics_player_id'
);
