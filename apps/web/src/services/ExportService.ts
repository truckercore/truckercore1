import { Parser } from '@json2csv/plainjs';

export interface ExportOptions {
  format: 'pdf' | 'csv' | 'excel' | 'json';
  filename?: string;
  data: any[];
  columns?: string[];
  title?: string;
  includeTimestamp?: boolean;
  customStyles?: Record<string, any>;
}

export interface PDFExportOptions extends ExportOptions {
  format: 'pdf';
  orientation?: 'portrait' | 'landscape';
  pageSize?: 'A4' | 'letter' | 'legal';
  includeCharts?: boolean;
  headerText?: string;
  footerText?: string;
}

export interface CSVExportOptions extends ExportOptions {
  format: 'csv';
  delimiter?: string;
  includeHeaders?: boolean;
  encoding?: string;
}

class ExportService {
  async exportToCSV(options: CSVExportOptions): Promise<Blob> {
    const { data, columns, delimiter = ',', includeHeaders = true, filename = 'export.csv' } = options;
    try {
      const fields = columns || (data.length > 0 ? Object.keys(data[0]) : []);
      const parser = new Parser({ fields, delimiter, header: includeHeaders });
      const csv = parser.parse(data);
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      this.downloadBlob(blob, filename);
      return blob;
    } catch (error) {
      console.error('CSV export failed:', error);
      throw new Error('Failed to export to CSV');
    }
  }

  async exportToPDF(options: PDFExportOptions): Promise<Blob> {
    const {
      data,
      columns,
      title = 'Export Report',
      orientation = 'portrait',
      pageSize = 'A4',
      headerText,
      footerText,
      filename = 'export.pdf',
      includeTimestamp = true,
    } = options;

    try {
      const jsPDF = (await import('jspdf')).default;
      const autoTable = (await import('jspdf-autotable')).default;

      const doc = new jsPDF({ orientation, unit: 'mm', format: pageSize });
      doc.setFontSize(18);
      doc.text(title, 14, 20);

      if (includeTimestamp) {
        doc.setFontSize(10);
        doc.text(`Generated: ${new Date().toLocaleString()}`, 14, 28);
      }
      if (headerText) {
        doc.setFontSize(10);
        doc.text(headerText, 14, includeTimestamp ? 35 : 28);
      }

      const tableColumns = columns || (data.length > 0 ? Object.keys(data[0]) : []);
      const tableRows = data.map((item) => tableColumns.map((col) => this.formatCellValue(item[col])));

      autoTable(doc, {
        head: [tableColumns],
        body: tableRows,
        startY: includeTimestamp ? (headerText ? 42 : 35) : headerText ? 35 : 28,
        theme: 'grid',
        headStyles: { fillColor: [66, 139, 202], textColor: [255, 255, 255], fontStyle: 'bold' },
        styles: { fontSize: 9, cellPadding: 3 },
        alternateRowStyles: { fillColor: [245, 245, 245] },
      });

      const blob = doc.output('blob');
      this.downloadBlob(blob, filename);
      return blob as Blob;
    } catch (error) {
      console.error('PDF export failed:', error);
      throw new Error('Failed to export to PDF');
    }
  }

  async exportToExcel(options: ExportOptions): Promise<Blob> {
    const { data, columns, title = 'Export', filename = 'export.xlsx' } = options;
    try {
      const XLSX: any = await import('xlsx');
      const fields = columns || (data.length > 0 ? Object.keys(data[0]) : []);
      const worksheetData = [fields, ...data.map((item) => fields.map((field) => item[field]))];
      const wb = XLSX.utils.book_new();
      const ws = XLSX.utils.aoa_to_sheet(worksheetData);
      const colWidths = fields.map((field) => ({ wch: Math.max(field.length, 10) }));
      ws['!cols'] = colWidths;
      XLSX.utils.book_append_sheet(wb, ws, title);
      const excelBuffer = XLSX.write(wb, { bookType: 'xlsx', type: 'array' });
      const blob = new Blob([excelBuffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
      this.downloadBlob(blob, filename);
      return blob;
    } catch (error) {
      console.error('Excel export failed:', error);
      throw new Error('Failed to export to Excel');
    }
  }

  async exportToJSON(options: ExportOptions): Promise<Blob> {
    const { data, filename = 'export.json' } = options;
    try {
      const json = JSON.stringify(data, null, 2);
      const blob = new Blob([json], { type: 'application/json' });
      this.downloadBlob(blob, filename);
      return blob;
    } catch (error) {
      console.error('JSON export failed:', error);
      throw new Error('Failed to export to JSON');
    }
  }

  async exportDashboardToPDF(dashboardId: string, options: Partial<PDFExportOptions> = {}): Promise<Blob> {
    try {
      const element = document.getElementById(dashboardId);
      if (!element) throw new Error('Dashboard element not found');
      const html2canvas = (await import('html2canvas')).default;
      const canvas = await html2canvas(element, { scale: 2, logging: false, useCORS: true });
      const jsPDF = (await import('jspdf')).default;
      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF({ orientation: options.orientation || 'landscape', unit: 'mm', format: options.pageSize || 'A4' });
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = pdf.internal.pageSize.getHeight();
      const imgWidth = canvas.width;
      const imgHeight = canvas.height;
      const ratio = Math.min(pdfWidth / imgWidth, pdfHeight / imgHeight);
      const imgX = (pdfWidth - imgWidth * ratio) / 2;
      const imgY = 10;

      if (options.title) {
        pdf.setFontSize(16);
        pdf.text(options.title, pdfWidth / 2, 8, { align: 'center' });
      }

      pdf.addImage(imgData, 'PNG', imgX, imgY, imgWidth * ratio, imgHeight * ratio);

      if (options.includeTimestamp !== false) {
        pdf.setFontSize(8);
        pdf.text(`Generated: ${new Date().toLocaleString()}`, pdfWidth - 10, pdfHeight - 5, { align: 'right' });
      }

      const blob = pdf.output('blob');
      this.downloadBlob(blob, options.filename || 'dashboard.pdf');
      return blob as Blob;
    } catch (error) {
      console.error('Dashboard PDF export failed:', error);
      throw new Error('Failed to export dashboard to PDF');
    }
  }

  async batchExport(exports: ExportOptions[]): Promise<Blob[]> {
    const results = await Promise.allSettled(exports.map((opt) => this.export(opt)));
    return results
      .filter((r): r is PromiseFulfilledResult<Blob> => r.status === 'fulfilled')
      .map((r) => r.value);
  }

  async export(options: ExportOptions): Promise<Blob> {
    switch (options.format) {
      case 'csv':
        return this.exportToCSV(options as CSVExportOptions);
      case 'pdf':
        return this.exportToPDF(options as PDFExportOptions);
      case 'excel':
        return this.exportToExcel(options);
      case 'json':
        return this.exportToJSON(options);
      default:
        throw new Error(`Unsupported export format: ${options.format}`);
    }
  }

  private formatCellValue(value: any): string {
    if (value === null || value === undefined) return '';
    if (typeof value === 'object') return JSON.stringify(value);
    if (typeof value === 'boolean') return value ? 'Yes' : 'No';
    return String(value);
  }

  private downloadBlob(blob: Blob, filename: string): void {
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  }
}

export const exportService = new ExportService();
export type { CSVExportOptions, PDFExportOptions };
