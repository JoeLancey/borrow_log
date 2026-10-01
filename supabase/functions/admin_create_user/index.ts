// supabase/functions/admin_create_user/index.ts
//
// Creates a new auth user + matching profile row.
// Only callable by a signed-in staff user.
// Sends a welcome email with the temporary password via Brevo.

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
    // -----------------------------------------------------------------
    // 1. Authenticate the caller from the Authorization header
    // -----------------------------------------------------------------
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401);
    }
    const jwt = authHeader.replace('Bearer ', '');

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
    const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
    const BREVO_SENDER_EMAIL = Deno.env.get('BREVO_SENDER_EMAIL');
    const BREVO_SENDER_NAME =
      Deno.env.get('BREVO_SENDER_NAME') ?? 'BORROW LOG';

    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    const {
      data: { user: caller },
      error: callerErr,
    } = await callerClient.auth.getUser();

    if (callerErr || !caller) {
      return json({ error: 'Invalid token' }, 401);
    }

    // -----------------------------------------------------------------
    // 2. Verify caller is staff
    // -----------------------------------------------------------------
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE);

    const { data: callerProfile, error: profileErr } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', caller.id)
      .maybeSingle();

    if (profileErr || callerProfile?.role !== 'staff') {
      return json({ error: 'Staff access required' }, 403);
    }

    // -----------------------------------------------------------------
    // 3. Parse body
    // -----------------------------------------------------------------
    const body = await req.json();
    const {
      email,
      password,
      full_name,
      role,
      student_id,
      course,
      college,
      employee_id,
      department,
    } = body ?? {};

    if (!email || !password || !full_name || !role) {
      return json(
        { error: 'Missing required fields: email, password, full_name, role' },
        400,
      );
    }
    if (role !== 'student' && role !== 'staff') {
      return json({ error: 'role must be student or staff' }, 400);
    }

    // -----------------------------------------------------------------
    // 4. Create auth user
    // -----------------------------------------------------------------
    const { data: created, error: createErr } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      });

    if (createErr || !created.user) {
      return json(
        { error: createErr?.message ?? 'Failed to create auth user' },
        400,
      );
    }

    // -----------------------------------------------------------------
    // 5. Insert profile row
    // -----------------------------------------------------------------
    const profilePayload: Record<string, unknown> = {
      id: created.user.id,
      email,
      full_name,
      role,
      must_change_password: true,
    };
    if (student_id) profilePayload.student_id = student_id;
    if (course) profilePayload.course = course;
    if (college) profilePayload.college = college;
    if (employee_id) profilePayload.employee_id = employee_id;
    if (department) profilePayload.department = department;

    const { error: insertErr } = await adminClient
      .from('profiles')
      .insert(profilePayload);

    if (insertErr) {
      // Roll back the auth user to keep things consistent
      await adminClient.auth.admin.deleteUser(created.user.id);
      return json(
        { error: `Profile insert failed: ${insertErr.message}` },
        400,
      );
    }

    // -----------------------------------------------------------------
    // 6. Send welcome email (best-effort)
    // -----------------------------------------------------------------
    let emailStatus = 'skipped';
    try {
      if (BREVO_API_KEY && BREVO_SENDER_EMAIL) {
        const roleLabel = role === 'staff' ? 'staff' : 'student';
        const safeName = escapeHtml(String(full_name));
        const safeEmail = escapeHtml(String(email));
        const safePassword = escapeHtml(String(password));
        const html = `
<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#f7f4f0;font-family:Arial,Helvetica,sans-serif;color:#252525;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f7f4f0;padding:32px 12px;">
      <tr><td align="center">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:14px;overflow:hidden;">
          <tr>
            <td style="background:#800000;color:#ffffff;padding:26px 30px;">
              <div style="font-size:24px;font-weight:700;letter-spacing:1px;">BORROW LOG</div>
              <div style="font-size:12px;color:#ffcc00;margin-top:6px;">University laboratory equipment portal</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 30px;">
              <h1 style="margin:0 0 14px;color:#800000;font-size:23px;">Your account is ready</h1>
              <div style="font-size:15px;line-height:1.65;color:#3a3a3a;">
                <p style="margin:0 0 16px;">Hello ${safeName},</p>
                <p style="margin:0 0 20px;">Your ${roleLabel} account for BorrowLog has been created. Use the details below to sign in and start managing laboratory equipment.</p>
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#fff8e5;border:1px solid #f0d98a;border-radius:10px;margin:0 0 20px;">
                  <tr><td style="padding:16px 18px;font-size:14px;line-height:1.8;">
                    <strong>Email</strong><br />${safeEmail}<br />
                    <strong>Temporary password</strong><br /><span style="font-family:monospace;font-size:16px;">${safePassword}</span>
                  </td></tr>
                </table>
                <p style="margin:0 0 12px;"><strong>Important:</strong> change this temporary password immediately after your first sign-in.</p>
                <p style="margin:0;color:#666;font-size:13px;">If you were not expecting this account, contact your laboratory administrator and do not share these credentials.</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 30px;background:#f7f5f2;font-size:11px;line-height:1.5;color:#777;">
              This is an automated message from BorrowLog. Please do not reply to this email.
            </td>
          </tr>
        </table>
      </td></tr>
    </table>
  </body>
</html>`;

        const brevoRes = await fetch(
          'https://api.brevo.com/v3/smtp/email',
          {
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
              to: [{ email }],
              subject: 'Your BorrowLog account is ready',
              htmlContent: html,
              textContent: `Hello ${full_name},

    Your ${roleLabel} BorrowLog account is ready.

    Email: ${email}
    Temporary password: ${password}

    Change this temporary password immediately after your first sign-in. If you were not expecting this account, contact your laboratory administrator.

    This is an automated message from BorrowLog. Please do not reply.`,
            }),
          },
        );

        const brevoText = await brevoRes.text();
        console.log('Brevo response:', brevoRes.status, brevoText);
        emailStatus = brevoRes.ok
          ? 'sent'
          : `failed (${brevoRes.status})`;
      } else {
        console.log('Brevo config missing; skipping welcome email');
        emailStatus = 'config_missing';
      }
    } catch (e) {
      console.log('Welcome email error:', e);
      emailStatus = 'error';
    }

    return json({
      ok: true,
      user_id: created.user.id,
      email,
      role,
      email_status: emailStatus,
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

function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/g, (character) => {
    const entities: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      "'": '&#39;',
      '"': '&quot;',
    };
    return entities[character];
  });
}