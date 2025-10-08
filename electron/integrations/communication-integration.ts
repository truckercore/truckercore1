import { ipcMain, Notification } from 'electron';
import sgMail from '@sendgrid/mail';
import twilio from 'twilio';

interface CommunicationConfig {
  twilio: {
    accountSid: string;
    authToken: string;
    phoneNumber: string;
  };
  sendgrid: {
    apiKey: string;
    fromEmail: string;
  };
}

export class CommunicationIntegration {
  private twilioClient: any;
  private config: CommunicationConfig;

  constructor(config: CommunicationConfig) {
    this.config = config;

    if (config.twilio.accountSid && config.twilio.authToken) {
      this.twilioClient = twilio(config.twilio.accountSid, config.twilio.authToken);
    }
    if (config.sendgrid.apiKey) {
      sgMail.setApiKey(config.sendgrid.apiKey);
    }
    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('comm:send-sms', async (_event, params: { to: string; message: string; priority?: 'high' | 'normal'; }) => {
      return await this.sendSMS(params);
    });

    ipcMain.handle('comm:send-email', async (_event, params: { to: string | string[]; subject: string; html: string; text?: string; attachments?: any[]; }) => {
      return await this.sendEmail(params);
    });

    ipcMain.handle('comm:send-driver-alert', async (_event, params: { driverId: string; driverPhone: string; driverEmail: string; message: string; type: 'route_change' | 'weather_alert' | 'maintenance' | 'emergency'; priority: 'high' | 'normal'; }) => {
      return await this.sendDriverAlert(params);
    });

    ipcMain.handle('comm:send-bulk-notification', async (_event, params: { recipients: Array<{ phone?: string; email?: string; name: string }>; message: string; subject: string; }) => {
      return await this.sendBulkNotification(params);
    });
  }

  private async sendSMS(params: { to: string; message: string; priority?: 'high' | 'normal'; }): Promise<{ success: boolean; messageId?: string }> {
    if (!this.twilioClient) throw new Error('Twilio not configured');
    const message = await this.twilioClient.messages.create({
      body: params.message,
      from: this.config.twilio.phoneNumber,
      to: params.to,
      statusCallback: process.env.TWILIO_WEBHOOK_URL,
    });
    return { success: true, messageId: message.sid };
  }

  private async sendEmail(params: { to: string | string[]; subject: string; html: string; text?: string; attachments?: any[]; }): Promise<{ success: boolean }> {
    if (!this.config.sendgrid.apiKey) throw new Error('SendGrid not configured');
    const msg = { to: params.to, from: this.config.sendgrid.fromEmail, subject: params.subject, html: params.html, text: params.text || '', attachments: params.attachments || [] } as any;
    await (sgMail as any).send(msg);
    return { success: true };
  }

  private async sendDriverAlert(params: { driverId: string; driverPhone: string; driverEmail: string; message: string; type: string; priority: 'high' | 'normal'; }): Promise<{ success: boolean }> {
    const tasks: Promise<any>[] = [];
    if (params.priority === 'high' && params.driverPhone && this.twilioClient) {
      tasks.push(this.sendSMS({ to: params.driverPhone, message: `🚨 URGENT: ${params.message}`, priority: 'high' }));
    }
    if (params.driverEmail && this.config.sendgrid.apiKey) {
      tasks.push(this.sendEmail({ to: params.driverEmail, subject: `${params.priority === 'high' ? '🚨 URGENT: ' : ''}${params.type.replace('_', ' ').toUpperCase()}`, html: this.generateAlertEmailHTML(params), text: params.message }));
    }

    new Notification({ title: `Alert: ${params.type}`, body: params.message, urgency: (params.priority === 'high' ? 'critical' : 'normal') as any }).show();

    await Promise.all(tasks);
    return { success: true };
  }

  private async sendBulkNotification(params: { recipients: Array<{ phone?: string; email?: string; name: string }>; message: string; subject: string; }): Promise<{ success: boolean; sent: number; failed: number }> {
    let sent = 0;
    let failed = 0;
    for (const r of params.recipients) {
      try {
        if (r.email && this.config.sendgrid.apiKey) {
          await this.sendEmail({ to: r.email, subject: params.subject, html: `<p>Hi ${r.name},</p><p>${params.message}</p>`, text: params.message });
          sent++;
        }
        if (r.phone && this.twilioClient) {
          await this.sendSMS({ to: r.phone, message: params.message });
          sent++;
        }
      } catch {
        failed++;
      }
    }
    return { success: true, sent, failed };
  }

  private generateAlertEmailHTML(params: { driverPhone: string; message: string; type: string; priority: string; }): string {
    const typeEmoji: Record<string, string> = { route_change: '🛣️', weather_alert: '⛈️', maintenance: '🔧', emergency: '🚨' };
    return `<!DOCTYPE html><html><head><style>body{font-family:Arial,sans-serif;line-height:1.6}.container{max-width:600px;margin:0 auto;padding:20px}.header{background:${params.priority==='high'?'#ef4444':'#3b82f6'};color:#fff;padding:20px;text-align:center}.content{padding:20px;background:#f9fafb}.footer{padding:20px;text-align:center;color:#6b7280;font-size:14px}</style></head><body><div class="container"><div class="header"><h1>${typeEmoji[params.type] || '📢'} ${params.priority==='high'?'URGENT ':''}ALERT</h1></div><div class="content"><p><strong>Alert Type:</strong> ${params.type.replace('_',' ').toUpperCase()}</p><p><strong>Message:</strong></p><p style="background:white;padding:15px;border-left:4px solid #3b82f6;">${params.message}</p>${params.priority==='high'?'<p style="color:#ef4444;"><strong>⚠️ This is a high-priority alert. Please take immediate action.</strong></p>':''}</div><div class="footer"><p>TruckerCore Fleet Management</p><p>If you have questions, contact dispatch immediately.</p></div></div></body></html>`;
  }
}
