import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fire-and-forget email send. Failures are swallowed.
    Future<void> sendEmail({
    required String to,
    required String subject,
    required String html,
    String? text,
  }) async {
    try {
      await _client.functions.invoke(
        'send_email',
        body: {
          'to': to,
          'subject': subject,
          'html': html,
          // ignore: use_null_aware_elements
          if (text != null) 'text': text,
        },
      );
    } catch (_) {
      // Email is best-effort; don't propagate.
    }
  }

  /// Shared HTML template for all BORROW LOG emails.
  String wrapHtml({
    required String title,
    required String bodyHtml,
    String? footer,
  }) {
    return '''
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
                <h2 style="margin:0 0 12px;color:#800000;font-size:18px;">$title</h2>
                <div style="font-size:14px;line-height:1.55;color:#333;">
                  $bodyHtml
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 24px;background:#f7f5f2;font-size:11px;color:#777;">
                ${footer ?? 'This is an automated message from BORROW LOG. Please do not reply.'}
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
  }
}