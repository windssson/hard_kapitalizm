drop policy if exists "Players can read accepted tenders" on public.tenders;
create policy "Players can read accepted tenders"
  on public.tenders
  for select
  using (
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.player_tenders pt
      where pt.tender_id = tenders.id
        and pt.player_id = (select auth.uid())
    )
  );
