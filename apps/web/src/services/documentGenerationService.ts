import jsPDF from 'jspdf';
import { Load, Location } from '../types/freight';

export class DocumentGenerationService {
  static generateRateConfirmation(load: Load, brokerInfo: any): Blob {
    const doc = new jsPDF();
    const pageWidth = doc.internal.pageSize.getWidth();
    let yPos = 20;

    // Header
    doc.setFontSize(20);
    doc.setFont('helvetica', 'bold');
    doc.text('RATE CONFIRMATION', pageWidth / 2, yPos, { align: 'center' });
    yPos += 15;

    // Broker Information
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.text(`Broker: ${brokerInfo.name}`, 20, yPos);
    yPos += 6;
    doc.text(`MC#: ${brokerInfo.mcNumber}`, 20, yPos);
    yPos += 6;
    doc.text(`Contact: ${brokerInfo.phone}`, 20, yPos);
    yPos += 15;

    // Load Information
    doc.setFont('helvetica', 'bold');
    doc.text('LOAD DETAILS', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(`Load ID: ${load.id}`, 20, yPos);
    yPos += 6;
    doc.text(`Commodity: ${load.commodity}`, 20, yPos);
    yPos += 6;
    doc.text(`Weight: ${load.weight.toLocaleString()} lbs`, 20, yPos);
    yPos += 6;
    doc.text(`Equipment: ${load.equipmentType.replace('_', ' ').toUpperCase()}`, 20, yPos);
    yPos += 15;

    // Pickup Information
    doc.setFont('helvetica', 'bold');
    doc.text('PICKUP', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(`Date: ${new Date(load.pickupDate).toLocaleDateString()}`, 20, yPos);
    yPos += 6;
    doc.text(`Location: ${this.formatLocation(load.pickupLocation)}`, 20, yPos);
    yPos += 15;

    // Delivery Information
    doc.setFont('helvetica', 'bold');
    doc.text('DELIVERY', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(`Date: ${new Date(load.deliveryDate).toLocaleDateString()}`, 20, yPos);
    yPos += 6;
    doc.text(`Location: ${this.formatLocation(load.deliveryLocation)}`, 20, yPos);
    yPos += 15;

    // Rate Information
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text(`CARRIER RATE: $${load.carrierRate?.toLocaleString() || '0'}`, 20, yPos);
    yPos += 15;

    // Terms and Conditions
    doc.setFontSize(10);
    doc.setFont('helvetica', 'bold');
    doc.text('TERMS AND CONDITIONS', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8);
    const terms = [
      '1. Carrier agrees to provide transportation services as specified above.',
      '2. Payment terms: Net 30 days from delivery with signed POD.',
      '3. Carrier must maintain proper insurance coverage throughout transit.',
      '4. Any claims must be filed within 48 hours of delivery.',
      '5. Carrier is responsible for all loading and securing of freight.',
    ];
    terms.forEach((term) => {
      doc.text(term, 20, yPos);
      yPos += 5;
    });

    // Signature Section
    yPos += 20;
    doc.setFontSize(10);
    doc.line(20, yPos, 90, yPos);
    doc.line(120, yPos, 190, yPos);
    yPos += 5;
    doc.text('Broker Signature', 20, yPos);
    doc.text('Carrier Signature', 120, yPos);
    yPos += 5;
    doc.text(`Date: ${new Date().toLocaleDateString()}`, 20, yPos);

    return doc.output('blob');
  }

  static generateBOL(load: Load): Blob {
    const doc = new jsPDF();
    const pageWidth = doc.internal.pageSize.getWidth();
    let yPos = 20;

    // Header
    doc.setFontSize(20);
    doc.setFont('helvetica', 'bold');
    doc.text('BILL OF LADING', pageWidth / 2, yPos, { align: 'center' });
    yPos += 10;
    doc.setFontSize(10);
    doc.text(`BOL #: ${load.id}`, pageWidth / 2, yPos, { align: 'center' });
    yPos += 15;

    // Shipper Information
    doc.setFont('helvetica', 'bold');
    doc.text('SHIPPER', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(load.customerName, 20, yPos);
    yPos += 6;
    doc.text(this.formatLocation(load.pickupLocation), 20, yPos);
    yPos += 15;

    // Consignee Information
    doc.setFont('helvetica', 'bold');
    doc.text('CONSIGNEE', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(this.formatLocation(load.deliveryLocation), 20, yPos);
    yPos += 15;

    // Carrier Information
    doc.setFont('helvetica', 'bold');
    doc.text('CARRIER', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(load.carrierName || 'TBD', 20, yPos);
    yPos += 15;

    // Freight Description
    doc.setFont('helvetica', 'bold');
    doc.text('FREIGHT DESCRIPTION', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(`Commodity: ${load.commodity}`, 20, yPos);
    yPos += 6;
    doc.text(`Weight: ${load.weight.toLocaleString()} lbs`, 20, yPos);
    yPos += 6;
    doc.text(`Equipment Type: ${load.equipmentType.replace('_', ' ').toUpperCase()}`, 20, yPos);
    yPos += 15;

    if (load.specialInstructions) {
      doc.setFont('helvetica', 'bold');
      doc.text('SPECIAL INSTRUCTIONS', 20, yPos);
      yPos += 8;
      doc.setFont('helvetica', 'normal');
      const instructions = doc.splitTextToSize(load.specialInstructions, 170);
      doc.text(instructions as string[] | string, 20, yPos);
      yPos += (Array.isArray(instructions) ? instructions.length : 1) * 6 + 10;
    }

    // Signature Section
    yPos = Math.max(yPos, 220);
    doc.line(20, yPos, 90, yPos);
    doc.line(120, yPos, 190, yPos);
    yPos += 5;
    doc.text('Shipper Signature/Date', 20, yPos);
    doc.text('Driver Signature/Date', 120, yPos);

    return doc.output('blob');
  }

  static generateInvoice(load: Load, invoiceNumber: string): Blob {
    const doc = new jsPDF();
    const pageWidth = doc.internal.pageSize.getWidth();
    let yPos = 20;

    // Header
    doc.setFontSize(24);
    doc.setFont('helvetica', 'bold');
    doc.text('INVOICE', pageWidth / 2, yPos, { align: 'center' });
    yPos += 15;

    // Invoice Info
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.text(`Invoice #: ${invoiceNumber}`, 20, yPos);
    yPos += 6;
    doc.text(`Date: ${new Date().toLocaleDateString()}`, 20, yPos);
    yPos += 6;
    doc.text(`Load ID: ${load.id}`, 20, yPos);
    yPos += 15;

    // Bill To
    doc.setFont('helvetica', 'bold');
    doc.text('BILL TO:', 20, yPos);
    yPos += 8;
    doc.setFont('helvetica', 'normal');
    doc.text(load.customerName, 20, yPos);
    yPos += 20;

    // Service Details
    doc.setFont('helvetica', 'bold');
    doc.text('Description', 20, yPos);
    doc.text('Amount', 150, yPos);
    yPos += 8;
    doc.line(20, yPos, 190, yPos);
    yPos += 8;

    doc.setFont('helvetica', 'normal');
    doc.text(`Freight from ${load.pickupLocation.city}, ${load.pickupLocation.state}`, 20, yPos);
    doc.text(`$${load.customerRate.toLocaleString()}`, 150, yPos);
    yPos += 6;
    doc.text(`to ${load.deliveryLocation.city}, ${load.deliveryLocation.state}`, 20, yPos);
    yPos += 10;

    doc.line(20, yPos, 190, yPos);
    yPos += 8;

    // Total
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(12);
    doc.text('TOTAL DUE:', 120, yPos);
    doc.text(`$${load.customerRate.toLocaleString()}`, 150, yPos);
    yPos += 15;

    // Payment Terms
    doc.setFontSize(10);
    doc.setFont('helvetica', 'normal');
    doc.text('Payment Terms: Net 30 Days', 20, yPos);
    yPos += 6;
    doc.text(`Due Date: ${new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toLocaleDateString()}`, 20, yPos);

    return doc.output('blob');
  }

  private static formatLocation(location: Location): string {
    return `${location.address}, ${location.city}, ${location.state} ${location.zipCode}`;
  }
}
