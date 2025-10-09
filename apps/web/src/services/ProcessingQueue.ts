export interface QueueJob {
  fileId: string;
  fileName: string;
  fileType: string;
  size: number;
}

export type JobStatus = 'queued' | 'processing' | 'completed' | 'failed';

export class ProcessingQueue {
  private jobs: Map<string, { job: QueueJob; status: JobStatus; error?: string }>; 
  private counter = 0;

  constructor() {
    this.jobs = new Map();
  }

  public async addJob(job: QueueJob): Promise<string> {
    const jobId = `job_${Date.now()}_${++this.counter}`;
    this.jobs.set(jobId, { job, status: 'queued' });
    // Simulate async processing
    setTimeout(() => this.process(jobId), 10);
    return jobId;
  }

  public getStatus(jobId: string): JobStatus | undefined {
    return this.jobs.get(jobId)?.status;
  }

  private async process(jobId: string) {
    const entry = this.jobs.get(jobId);
    if (!entry) return;
    entry.status = 'processing';

    try {
      // simulate work time based on size
      const time = Math.min(2000, Math.max(20, Math.floor(entry.job.size / 1024)));
      await new Promise((r) => setTimeout(r, time));
      entry.status = 'completed';
    } catch (e: any) {
      entry.status = 'failed';
      entry.error = e?.message || 'Unknown error';
    }
  }
}

export default ProcessingQueue;
