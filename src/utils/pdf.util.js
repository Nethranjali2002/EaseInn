import PDFDocument from 'pdfkit';

export const generateBookingReportPdf = (res, { bookings, property, startDate, endDate }) => {
  const doc = new PDFDocument({ margin: 40, size: 'A4' });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=booking-report-${Date.now()}.pdf`);
  doc.pipe(res);

  doc.fontSize(20).font('Helvetica-Bold').text('EaseInn - Booking Report', { align: 'center' });
  doc.moveDown(0.3);
  doc.fontSize(11).font('Helvetica').text(`Property: ${property?.name || 'All'}`, { align: 'center' });
  if (startDate || endDate) {
    doc.text(`Period: ${startDate || 'Start'} to ${endDate || 'End'}`, { align: 'center' });
  }
  doc.moveDown(0.3);
  doc.text(`Generated: ${new Date().toLocaleDateString()}`, { align: 'center' });
  doc.moveDown(1);

  doc.fontSize(14).font('Helvetica-Bold').text('Booking Summary');
  doc.moveDown(0.3);
  doc.fontSize(10).font('Helvetica');
  doc.text(`Total Bookings: ${bookings.length}`);
  const totalRevenue = bookings.reduce((sum, b) => sum + (b.pricing?.totalAmount || 0), 0);
  doc.text(`Total Revenue: LKR ${totalRevenue.toLocaleString()}`);
  const checkedIn = bookings.filter(b => b.bookingStatus === 'checked-in').length;
  const confirmed = bookings.filter(b => b.bookingStatus === 'confirmed').length;
  doc.text(`Checked In: ${checkedIn} | Confirmed: ${confirmed}`);
  doc.moveDown(1);

  doc.fontSize(14).font('Helvetica-Bold').text('Booking Details');
  doc.moveDown(0.3);

  const tableTop = doc.y;
  const colWidths = [80, 60, 65, 65, 50, 70, 60];
  const headers = ['Guest', 'Room', 'Check-In', 'Check-Out', 'Guests', 'Total', 'Status'];

  doc.fontSize(8).font('Helvetica-Bold');
  let x = 40;
  headers.forEach((h, i) => {
    doc.text(h, x, tableTop, { width: colWidths[i] });
    x += colWidths[i];
  });

  doc.moveDown(0.5);
  doc.font('Helvetica').fontSize(8);

  bookings.slice(0, 40).forEach((b, idx) => {
    if (doc.y > 750) {
      doc.addPage();
    }
    const y = doc.y;
    let cx = 40;
    const row = [
      b.guest?.name?.substring(0, 12) || '-',
      b.room?.roomNumber || '-',
      new Date(b.checkIn).toLocaleDateString(),
      new Date(b.checkOut).toLocaleDateString(),
      String(b.numberOfGuests),
      `LKR ${(b.pricing?.totalAmount || 0).toLocaleString()}`,
      b.bookingStatus,
    ];
    row.forEach((cell, i) => {
      doc.text(cell, cx, y, { width: colWidths[i] });
      cx += colWidths[i];
    });
    doc.moveDown(0.5);

    if (idx < bookings.length - 1) {
      doc.moveTo(40, doc.y).lineTo(570, doc.y).strokeColor('#cccccc').lineWidth(0.5).stroke();
      doc.moveDown(0.3);
    }
  });

  doc.end();
};

export const generatePaymentReportPdf = (res, { payments, property }) => {
  const doc = new PDFDocument({ margin: 40, size: 'A4' });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=payment-report-${Date.now()}.pdf`);
  doc.pipe(res);

  doc.fontSize(20).font('Helvetica-Bold').text('EaseInn - Payment Report', { align: 'center' });
  doc.moveDown(0.3);
  doc.fontSize(11).font('Helvetica').text(`Property: ${property?.name || 'All'}`, { align: 'center' });
  doc.text(`Generated: ${new Date().toLocaleDateString()}`, { align: 'center' });
  doc.moveDown(1);

  const totalAmount = payments.reduce((sum, p) => sum + (p.amount || 0), 0);
  const completed = payments.filter(p => p.status === 'completed').length;
  doc.fontSize(14).font('Helvetica-Bold').text('Payment Summary');
  doc.moveDown(0.3);
  doc.fontSize(10).font('Helvetica');
  doc.text(`Total Payments: ${payments.length}`);
  doc.text(`Completed: ${completed} | Total: LKR ${totalAmount.toLocaleString()}`);
  doc.moveDown(1);

  doc.fontSize(14).font('Helvetica-Bold').text('Payment Details');
  doc.moveDown(0.3);

  const tableTop = doc.y;
  const colWidths = [90, 80, 70, 60, 70, 60, 70];
  const headers = ['Invoice', 'Guest', 'Amount', 'Method', 'Type', 'Status', 'Date'];

  doc.fontSize(8).font('Helvetica-Bold');
  let x = 40;
  headers.forEach((h, i) => {
    doc.text(h, x, tableTop, { width: colWidths[i] });
    x += colWidths[i];
  });

  doc.moveDown(0.5);
  doc.font('Helvetica').fontSize(8);

  payments.forEach((p, idx) => {
    if (doc.y > 750) doc.addPage();
    const y = doc.y;
    let cx = 40;
    const row = [
      p.invoiceNumber || '-',
      p.booking?.guest?.name?.substring(0, 12) || '-',
      `LKR ${(p.amount || 0).toLocaleString()}`,
      p.method || '-',
      p.type || '-',
      p.status,
      p.paidAt ? new Date(p.paidAt).toLocaleDateString() : 'N/A',
    ];
    row.forEach((cell, i) => {
      doc.text(cell, cx, y, { width: colWidths[i] });
      cx += colWidths[i];
    });
    doc.moveDown(0.5);
    if (idx < payments.length - 1) {
      doc.moveTo(40, doc.y).lineTo(570, doc.y).strokeColor('#cccccc').lineWidth(0.5).stroke();
      doc.moveDown(0.3);
    }
  });

  doc.end();
};
