-- Fix performance warnings by ensuring auth.uid() is queried using a subquery (InitPlan optimization)

-- 1. Fix player_cash_ledger policy
DROP POLICY IF EXISTS "Oyuncu kendi nakit akisini gorebilir" ON public.player_cash_ledger;
CREATE POLICY "Oyuncu kendi nakit akisini gorebilir" ON public.player_cash_ledger
    FOR SELECT USING ((SELECT auth.uid()) = player_id);

-- 2. Fix player_taxes policy
DROP POLICY IF EXISTS "Allow individual read access" ON public.player_taxes;
CREATE POLICY "Allow individual read access" ON public.player_taxes
    FOR SELECT USING ((SELECT auth.uid()) = player_id);
