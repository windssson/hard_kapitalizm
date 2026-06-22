do $do$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid)
    into v_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'build_player_attention_notifications';

  if v_def is null then
    raise exception 'Function public.build_player_attention_notifications not found';
  end if;

  v_def := replace(
    v_def,
    $from$field' then 'Tarlada Hammadde Eksik'$from$,
    $to$field' then 'Ciftlikte Hammadde Eksik'$to$
  );
  v_def := replace(
    v_def,
    $from$else 'Ciftlikte Hammadde Eksik'$from$,
    $to$else 'Tarlada Hammadde Eksik'$to$
  );

  execute v_def;
end
$do$;

update public.player_notifications
set title = case
    when entity_kind = 'field' and title = 'Tarlada Hammadde Eksik' then 'Ciftlikte Hammadde Eksik'
    when entity_kind = 'farm' and title = 'Ciftlikte Hammadde Eksik' then 'Tarlada Hammadde Eksik'
    else title
  end,
  updated_at = timezone('utc', now())
where category = 'production_blocked'
  and (
    (entity_kind = 'field' and title = 'Tarlada Hammadde Eksik')
    or (entity_kind = 'farm' and title = 'Ciftlikte Hammadde Eksik')
  );
