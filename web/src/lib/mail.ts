import nodemailer from "nodemailer";

function createTransport() {
  const port = Number(process.env.SMTP_PORT) || 465;
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

export type MailResult = { ok: boolean; error: string | null };

export async function sendMail(to: string, subject: string, text: string): Promise<MailResult> {
  try {
    const transporter = createTransport();
    await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to,
      subject,
      text,
    });
    return { ok: true, error: null };
  } catch (e) {
    console.error("[mail]", e);
    return { ok: false, error: String((e as Error).message) };
  }
}

export async function sendReportReceived(toEmail: string, reason: string): Promise<MailResult> {
  const subject = "Carp24 – Ihre Meldung ist eingegangen";
  const text =
    "Guten Tag,\n\n" +
    "vielen Dank für Ihre Meldung. Ihre Meldung ist bei uns eingegangen.\n\n" +
    "Grund der Meldung: " + reason + "\n\n" +
    "Wir prüfen Ihre Meldung und benachrichtigen Sie über die Entscheidung.\n\n" +
    "Freundliche Grüße\n" +
    "Ihr Carp24-Team";
  return sendMail(toEmail, subject, text);
}

export async function sendReportDecision(toEmail: string, decision: string, note: string): Promise<MailResult> {
  const decisionText =
    decision === "removed"
      ? "Der gemeldete Inhalt wurde entfernt."
      : "Ihre Meldung wurde abgewiesen.";
  const subject = "Carp24 – Entscheidung zu Ihrer Meldung";
  const text =
    "Guten Tag,\n\n" +
    "wir haben Ihre Meldung geprüft und eine Entscheidung getroffen.\n\n" +
    "Entscheidung: " + decisionText + "\n" +
    "Begründung: " + note + "\n\n" +
    "Hinweis: Gegen diese Entscheidung können Sie gemäß Art. 20 DSA Rechtsbehelfe einlegen (interne Beschwerde und außergerichtliche Streitbeilegung).\n\n" +
    "Freundliche Grüße\n" +
    "Ihr Carp24-Team";
  return sendMail(toEmail, subject, text);
}
