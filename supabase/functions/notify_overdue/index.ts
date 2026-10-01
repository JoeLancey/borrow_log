// supabase/functions/notify_overdue/index.ts
//
// Scans for borrowed reservations past their due date and inserts an
// "overdue" notification for each student. Idempotent per calendar day:
// running this twice in the same day won't create duplicates.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

    // Today's date at UTC midnight — used as part of the dedupe key.
    const today = new Date();
    const todayIso = today.toISOString().split('T')[0]; // yyyy-MM-dd

    // 1. Find reservations: status = borrowed, due_date < today
    const { data: overdue, error: fetchErr } = await admin
      .from('reservations')
      .select('id, student_id, due_date, equipment_types(name)')
      .eq('status', 'borrowed')
      .lt('due_date', todayIso);

    if (fetchErr) {
      return json({ error: `Fetch failed: ${fetchErr.message}` }, 500);
    }

    if (!overdue || overdue.length === 0) {
      return json({ ok: true, inserted: 0, scanned: 0 });
    }

    // 2. Build notifications, skipping any that already have this dedupe key
    const rows: Array<Record<string, unknown>> = [];

    for (const r of overdue) {
      const dedupeKey = `overdue:${r.id}:${todayIso}`;

      // Already sent today?
      const { data: existing } = await admin
        .from('notifications')
        .select('id')
        .eq('dedupe_key', dedupeKey)
        .maybeSingle();

      if (existing) continue;

      const typeName =
        (r as any).equipment_types?.name ?? 'laboratory equipment';
      const dueDate = r.due_date as string;

      rows.push({
        user_id: r.student_id,
        title: 'Equipment overdue',
        body:
          `Your borrowed ${typeName} was due on ${dueDate}. ` +
          `Please return it to the laboratory as soon as possible.`,
        kind: 'overdue',
        reservation_id: r.id,
        dedupe_key: dedupeKey,
      });
    }

    if (rows.length === 0) {
      return json({
        ok: true,
        inserted: 0,
        scanned: overdue.length,
        message: 'All overdue reservations already notified today.',
      });
    }

    // 3. Insert all at once
    const { error: insertErr } = await admin
      .from('notifications')
      .insert(rows);

    if (insertErr) {
      return json({ error: `Insert failed: ${insertErr.message}` }, 500);
    }

    return json({
      ok: true,
      inserted: rows.length,
      scanned: overdue.length,
    });
  } catch (e) {
    return json({ error: `Unexpected: ${e}` }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}