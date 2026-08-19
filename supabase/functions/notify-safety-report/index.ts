import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const TO_EMAIL = "support.contact@gmail.com";

serve(async (req) => {
  try {
    const { report_id } = await req.json();

    if (!report_id) {
      return new Response(JSON.stringify({ error: "report_id is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: report, error: reportError } = await supabase
      .from("safety_reports")
      .select("*")
      .eq("id", report_id)
      .single();

    if (reportError || !report) {
      return new Response(JSON.stringify({ error: "Report not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    const emailBody = `
New Conexo Safety Report

Report ID: ${report.id}
Reporter Name: ${report.reporter_name_snapshot ?? "N/A"}
Reporter User ID: ${report.reporter_user_id}

Reported User: ${report.reported_name_snapshot ?? "N/A"}
Reported User ID: ${report.reported_user_id}

Report Type: ${report.report_type}
Description: ${report.description ?? "None"}

Created At: ${report.created_at}

Screenshot: ${report.screenshot_path ? `Attached (private bucket): ${report.screenshot_path}` : "Not attached"}
    `.trim();

    if (!RESEND_API_KEY) {
      console.error(
        JSON.stringify({
          event: "safety_report_email_skipped",
          report_id: report.id,
          error: "RESEND_API_KEY is not configured",
        })
      );
      return new Response(
        JSON.stringify({
          ok: false,
          email_sent: false,
          error: "RESEND_API_KEY is not configured",
        }),
        {
          status: 503,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "Conexo Safety <safety@conexo.app>",
        to: [TO_EMAIL],
        subject: `[Conexo Safety Report] ${report.report_type} — Report ${report.id}`,
        text: emailBody,
      }),
    });

    const emailData = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error(
        JSON.stringify({
          event: "safety_report_email_failed",
          report_id: report.id,
          status: emailResponse.status,
          response: emailData,
        })
      );
      return new Response(
        JSON.stringify({
          ok: false,
          email_sent: false,
          error: "Email delivery failed",
        }),
        {
          status: 502,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({
        ok: true,
        email_sent: true,
        email_id: emailData.id ?? null,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("notify-safety-report error:", error);
    return new Response(
      JSON.stringify({ ok: false, email_sent: false, error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
