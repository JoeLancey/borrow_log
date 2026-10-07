// supabase/functions/notify_overdue/index.ts
//
// Scans for borrowed reservations past their due date and:
//   1. Inserts an in-app notification
//   2. Sends an email via Brevo
//
// Idempotent per calendar day: running twice in the same day
// will NOT create duplicates.

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
    const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
    const BREVO_SENDER_EMAIL = Deno.env.get('BREVO_SENDER_EMAIL');
    const BREVO_SENDER_NAME =
      Deno.env.get('BREVO_SENDER_NAME') ?? 'BORROW LOG';

    if (!BREVO_API_KEY || !BREVO_SENDER_EMAIL) {
      return json({ error: 'Missing Brevo configuration' }, 500);
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE);

    const today = new Date();
    const todayIso = today.toISOString().split('T')[0];

    // 1. Find overdue reservations (no join here — avoids FK name issues)
    const { data: overdue, error: fetchErr } = await admin
      .from('reservations')
      .select('id, student_id, due_date, equipment_types(name)')
      .eq('status', 'borrowed')
      .lt('due_date', todayIso);

    if (fetchErr) {
      return json({ error: `Fetch failed: ${fetchErr.message}` }, 500);
    }

    if (!overdue || overdue.length === 0) {
      return json({
        ok: true,
        inserted: 0,
        emailsSent: 0,
        scanned: 0,
      });
    }

    // 2. Build notification rows + email jobs
    const rows: Array<Record<string, unknown>> = [];
    const emailJobs: Array<{
      to: string;
      studentName: string;
      typeName: string;
      dueDate: string;
    }> = [];

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

      // Fetch the student's profile separately (no embedded join)
      const { data: profile } = await admin
        .from('profiles')
        .select('email, full_name')
        .eq('id', r.student_id)
        .maybeSingle();

      const studentEmail = profile?.email as string | undefined;
      const studentName = (profile?.full_name as string | undefined) ?? 'Student';

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

      if (studentEmail) {
        emailJobs.push({
          to: studentEmail,
          studentName,
          typeName,
          dueDate,
        });
      }
    }

    if (rows.length === 0) {
      return json({
        ok: true,
        inserted: 0,
        emailsSent: 0,
        scanned: overdue.length,
        message: 'All overdue reservations already notified today.',
      });
    }

    // 3. Insert notifications
    const { error: insertErr } = await admin
      .from('notifications')
      .insert(rows);

    if (insertErr) {
      return json({ error: `Insert failed: ${insertErr.message}` }, 500);
    }

    // 4. Send emails (best-effort)
    let emailsSent = 0;
    const emailErrors: string[] = [];

    for (const job of emailJobs) {
      try {
        const html = overdueEmailHtml({
          studentName: job.studentName,
          typeName: job.typeName,
          dueDate: job.dueDate,
        });

        const res = await fetch('https://api.brevo.com/v3/smtp/email', {
          method: 'POST',
          headers: {
            'accept': 'application/json',
            'api-key': BREVO_API_KEY,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            sender: {
              name: BREVO_SENDER_NAME,
              email: BREVO_SENDER_EMAIL,
            },
            to: [{ email: job.to }],
            subject: 'BORROW LOG: Equipment overdue',
            htmlContent: html,
          }),
        });

        if (res.ok) {
          emailsSent += 1;
        } else {
          const errText = await res.text();
          emailErrors.push(`[${job.to}] ${res.status}: ${errText}`);
        }
      } catch (e) {
        emailErrors.push(`[${job.to}] ${e}`);
      }
    }

    return json({
      ok: true,
      inserted: rows.length,
      emailsSent,
      emailsAttempted: emailJobs.length,
      scanned: overdue.length,
      emailErrors: emailErrors.length ? emailErrors : undefined,
    });
  } catch (e) {
    return json({ error: `Unexpected: ${e}` }, 500);
  }
});

function overdueEmailHtml({
  studentName,
  typeName,
  dueDate,
}: {
  studentName: string;
  typeName: string;
  dueDate: string;
}): string {
  return `
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
  </head>
  <body style="margin:0;padding:0;background:#FAF9F6;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#222;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#FAF9F6;padding:24px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <tr>
              <td style="background:#800000;color:#ffffff;padding:20px 24px;">
                <div style="font-size:22px;font-weight:700;letter-spacing:1.5px;">BORROW LOG</div>
                <div style="font-size:12px;color:#FFCC00;margin-top:2px;">Laboratory Equipment Borrowing System</div>
              </td>
            </tr>
            <tr>
              <td style="padding:24px;">
                <h2 style="margin:0 0 12px;color:#C62828;font-size:18px;">Equipment overdue</h2>
                <div style="font-size:14px;line-height:1.55;color:#333;">
                  <p>Hi ${escapeHtml(studentName)},</p>
                  <p>
                    Our records show that your borrowed
                    <strong>${escapeHtml(typeName)}</strong>
                    was due on <strong>${escapeHtml(dueDate)}</strong>
                    and has not yet been returned.
                  </p>
                  <p>
                    Please return it to the laboratory as soon as possible.
                    If you have already returned it, you can ignore this message.
                  </p>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f7f5f2;font-size:11px;color:#777;">
                This is an automated message from BORROW LOG. Please do not reply.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}