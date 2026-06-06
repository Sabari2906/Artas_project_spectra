// server/index.js
const express = require('express');
const cors = require('cors');
const pool = require('./database');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

const PHONE_REGEX = /^[\d\s\-\+\(\)]+$/;
const PORT = process.env.PORT || 5000;

function sanitizeInput(value) {
  if (typeof value !== 'string') return '';
  return value.replace(/[<>&"']/g, (char) => {
    switch (char) {
      case '<': return '&lt;';
      case '>': return '&gt;';
      case '&': return '&amp;';
      case '"': return '&quot;';
      case "'": return '&#39;';
      default: return char;
    }
  });
}

function normalizePhone(phone) {
  return String(phone || '').replace(/\D/g, '');
}

function isValidPhone(phone) {
  const cleaned = normalizePhone(phone);
  return PHONE_REGEX.test(phone) && cleaned.length >= 10 && cleaned.length <= 15;
}

const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);

// ============================================================
//  DASHBOARD / STATS
// ============================================================
app.get('/api/dashboard/stats', async (req, res) => {
  try {
    const [[{ c: pending }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='pending'");
    const [[{ c: confirmed }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='confirmed'");
    const [[{ c: testing }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='testing'");
    const [[{ c: cleared }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='cleared'");
    const [[{ c: completed }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='completed'");
    const [[{ c: canceled }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='canceled'");
    const [[{ c: notCleared }]] = await pool.query("SELECT COUNT(*) as c FROM appointments WHERE status='not_cleared'");
    const [[{ c: totalPatients }]] = await pool.query("SELECT COUNT(*) as c FROM patients");
    const [[{ c: lowStock }]] = await pool.query("SELECT COUNT(*) as c FROM inventory WHERE quantity <= threshold");
    const [[{ c: totalItems }]] = await pool.query("SELECT COUNT(*) as c FROM inventory");

    res.json({ pending, confirmed, testing, cleared, completed, canceled, notCleared, totalPatients, lowStock, totalItems });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  NOTIFICATIONS
// ============================================================
app.get('/api/notifications', async (req, res) => {
  try {
    const [upcoming] = await pool.query(`
      SELECT 
        a.id as appointment_id, DATE_FORMAT(a.date, '%Y-%m-%d') as date, a.status,
        p.name as patient_name,
        t.name as treatment_name, t.id as treatment_id
      FROM appointments a
      JOIN patients p ON a.patient_id = p.id
      JOIN treatments t ON a.treatment_id = t.id
      WHERE a.status IN ('confirmed', 'cleared')
      ORDER BY a.date ASC
    `);

    const notifications = [];
    for (const apt of upcoming) {
      const [accessories] = await pool.query(`
        SELECT ta.quantity_required, i.item_name, i.quantity as stock, i.id as inv_id
        FROM treatment_accessories ta
        JOIN inventory i ON ta.inventory_id = i.id
        WHERE ta.treatment_id = ?
      `, [apt.treatment_id]);

      const reqList = accessories.length > 0
        ? accessories.map(a => `${a.quantity_required} ${a.item_name}`).join(', ')
        : 'None';

      notifications.push({
        type: 'upcoming_alert',
        appointment_id: apt.appointment_id,
        date: apt.date,
        patient: apt.patient_name,
        treatment: apt.treatment_name,
        message: `${apt.patient_name} comes on ${apt.date} for ${apt.treatment_name} and needs: ${reqList}.`
      });

      const lowItems = accessories.filter(a => a.stock < a.quantity_required);
      if (lowItems.length > 0) {
        const lowList = lowItems.map(a => `${a.item_name} (current: ${a.stock})`).join(', ');
        notifications.push({
          type: 'low_stock',
          appointment_id: apt.appointment_id,
          date: apt.date,
          patient: apt.patient_name,
          treatment: apt.treatment_name,
          message: `URGENT RESTOCK: ${apt.treatment_name} requires ${reqList}. Low stock: ${lowList}.`,
          lowItems: lowItems.map(l => l.item_name),
        });
      }
    }

    res.json(notifications);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  TREATMENTS
// ============================================================
app.get('/api/treatments', async (req, res) => {
  try {
    const [treatments] = await pool.query('SELECT * FROM treatments');
    const result = [];
    for (const t of treatments) {
      const [accessories] = await pool.query(`
        SELECT ta.id as mapping_id, ta.quantity_required, i.id as inventory_id, i.item_name
        FROM treatment_accessories ta
        JOIN inventory i ON ta.inventory_id = i.id
        WHERE ta.treatment_id = ?
      `, [t.id]);
      result.push({ ...t, accessories });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/treatments', async (req, res) => {
  try {
    const { name, type, price, description, accessories } = req.body;
    const [result] = await pool.query('INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)',
      [name, type || 'manual', price || 0, description || '']);
    const tId = result.insertId;

    if (accessories && accessories.length > 0) {
      for (const acc of accessories) {
        await pool.query('INSERT INTO treatment_accessories (treatment_id, inventory_id, quantity_required) VALUES (?, ?, ?)', [tId, acc.inventory_id, acc.quantity_required]);
      }
    }
    res.json({ id: tId, message: 'Treatment created' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  PATIENTS
// ============================================================
app.get('/api/patients', async (req, res) => {
  try {
    const [patients] = await pool.query('SELECT * FROM patients');
    res.json(patients);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/patients', async (req, res) => {
  try {
    const { name, phone } = req.body;
    const [result] = await pool.query('INSERT INTO patients (name, phone) VALUES (?, ?)', [name, phone]);
    res.json({ id: result.insertId, message: 'Patient created' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  APPOINTMENTS
// ============================================================
app.get('/api/appointments', async (req, res) => {
  try {
    const [appointments] = await pool.query(`
      SELECT 
        a.id, DATE_FORMAT(a.date, '%Y-%m-%d') as date, DATE_FORMAT(a.treatment_date, '%Y-%m-%d') as treatment_date, a.status, a.treatment_type, a.doctor_notes, a.lab_notes,
        p.name as patient_name, p.phone as patient_phone, p.id as patient_id, p.patient_uid,
        t.name as treatment_name, t.id as treatment_id, t.type as default_treatment_type, t.price, t.description as treatment_desc
      FROM appointments a
      JOIN patients p ON a.patient_id = p.id
      JOIN treatments t ON a.treatment_id = t.id
      ORDER BY a.date DESC
    `);

    const appointmentsWithContext = [];
    for (const apt of appointments) {
      const [accessories] = await pool.query(`
        SELECT ta.quantity_required, i.item_name, i.quantity as stock, i.id as inventory_id
        FROM treatment_accessories ta
        JOIN inventory i ON ta.inventory_id = i.id
        WHERE ta.treatment_id = ?
      `, [apt.treatment_id]);

      let allStockReady = true;
      let lowItems = [];
      accessories.forEach(acc => {
        if (acc.stock < acc.quantity_required) {
          allStockReady = false;
          lowItems.push(acc.item_name);
        }
      });

      appointmentsWithContext.push({
        ...apt,
        accessories,
        stockStatus: allStockReady ? 'Ready' : 'Low Stock',
        lowItems
      });
    }

    res.json(appointmentsWithContext);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/appointments/occupied-dates', async (req, res) => {
  try {
    const [rows] = await pool.query("SELECT DISTINCT DATE_FORMAT(date, '%Y-%m-%d') as date FROM appointments WHERE status != 'canceled'");
    res.json(rows.map(r => r.date));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/appointments', async (req, res) => {
  try {
    const { patient_id, treatment_id, date } = req.body;
    const [result] = await pool.query('INSERT INTO appointments (patient_id, treatment_id, date, status) VALUES (?, ?, ?, ?)', [patient_id, treatment_id, date, 'pending']);
    res.json({ id: result.insertId, message: 'Appointment created (pending approval)' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Step 1: Approve pending appointment → also auto-create patient card
app.put('/api/appointments/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const [apts] = await pool.query('SELECT a.status, a.patient_id FROM appointments a WHERE a.id = ?', [id]);
    if (apts.length === 0) return res.status(404).json({ error: 'Appointment not found' });
    if (apts[0].status !== 'pending') return res.status(400).json({ error: 'Only pending appointments can be approved' });

    await pool.query('UPDATE appointments SET status = ? WHERE id = ?', ['confirmed', id]);

    // Assign a unique patient ID (e.g. PID-00001) if it doesn't have one
    const patient_id = apts[0].patient_id;
    const uid = 'PID-' + patient_id.toString().padStart(5, '0');
    await pool.query('UPDATE patients SET patient_uid = ? WHERE id = ? AND patient_uid IS NULL', [uid, patient_id]);

    // Auto-create patient card if it doesn't already exist
    try {
      await pool.query(
        'INSERT IGNORE INTO patient_cards (patient_id, appointment_id) VALUES (?, ?)',
        [apts[0].patient_id, id]
      );
    } catch (e) { /* card already exists, ignore */ }

    res.json({ message: 'Appointment approved and patient card created' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Step 1.5: Reschedule appointment (Treatment date decided after cleared)
app.put('/api/appointments/:id/reschedule', async (req, res) => {
  try {
    const { id } = req.params;
    const { date } = req.body;
    if (!date) return res.status(400).json({ error: 'Date is required' });

    await pool.query('UPDATE appointments SET treatment_date = ? WHERE id = ?', [date, id]);
    res.json({ message: 'Appointment rescheduled' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Step 2: Doctor consultation done → move to testing
app.put('/api/appointments/:id/start-testing', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { id } = req.params;
    const { treatment_id, treatment_type, doctor_notes } = req.body;

    const [apts] = await conn.query('SELECT status FROM appointments WHERE id = ?', [id]);
    if (apts.length === 0) return res.status(404).json({ error: 'Appointment not found' });
    if (apts[0].status !== 'confirmed') return res.status(400).json({ error: 'Appointment must be confirmed first' });

    await conn.beginTransaction();

    let updateQuery = 'UPDATE appointments SET status = ?, treatment_type = ?, doctor_notes = ?';
    let updateParams = ['testing', treatment_type || null, doctor_notes || ''];

    if (treatment_id) {
      updateQuery += ', treatment_id = ?';
      updateParams.push(treatment_id);
    }

    updateQuery += ' WHERE id = ?';
    updateParams.push(id);

    await conn.query(updateQuery, updateParams);

    // Create lab result placeholders for all defined tests
    const [labTests] = await conn.query('SELECT id FROM lab_tests');
    for (const test of labTests) {
      await conn.query('INSERT INTO patient_lab_results (appointment_id, lab_test_id) VALUES (?, ?)', [id, test.id]);
    }

    await conn.commit();
    res.json({ message: 'Moved to testing phase. Lab test entries created.' });
  } catch (error) {
    await conn.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    conn.release();
  }
});

// Step 3: Evaluate lab results → cleared / not_cleared
app.put('/api/appointments/:id/evaluate', async (req, res) => {
  try {
    const { id } = req.params;
    const [results] = await pool.query('SELECT is_fit FROM patient_lab_results WHERE appointment_id = ?', [id]);
    if (results.length === 0) return res.status(400).json({ error: 'No lab results found' });

    const pending = results.filter(r => r.is_fit === null);
    if (pending.length > 0) return res.status(400).json({ error: `${pending.length} test(s) not yet assessed` });

    const allFit = results.every(r => r.is_fit === 1);
    const newStatus = allFit ? 'cleared' : 'not_cleared';
    const { lab_notes } = req.body;

    await pool.query('UPDATE appointments SET status = ?, lab_notes = ? WHERE id = ?',
      [newStatus, lab_notes || '', id]);

    res.json({
      status: newStatus,
      message: allFit ? 'Patient is CLEARED for treatment!' : 'Patient is NOT CLEARED. Some tests failed.',
      totalTests: results.length,
      passed: results.filter(r => r.is_fit === 1).length,
      failed: results.filter(r => r.is_fit === 0).length
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Step 4: Complete treatment (from cleared status) — deducts inventory
app.put('/api/appointments/:id/complete', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const { id } = req.params;
    const { deduction_mode, items } = req.body;
    const [apts] = await conn.query('SELECT status, treatment_id FROM appointments WHERE id = ?', [id]);
    if (apts.length === 0) return res.status(404).json({ error: 'Appointment not found' });
    const apt = apts[0];
    if (apt.status === 'completed') return res.status(400).json({ error: 'Already completed' });
    if (apt.status !== 'cleared' && apt.status !== 'confirmed') return res.status(400).json({ error: 'Patient must be cleared (or confirmed for legacy) first' });

    await conn.beginTransaction();

    let deductionItems = [];
    if (deduction_mode === 'manual') {
      if (!Array.isArray(items) || items.length === 0) {
        await conn.rollback();
        return res.status(400).json({ error: 'Manual deduction requires a list of items and quantities' });
      }
      deductionItems = items.map(item => ({
        inventory_id: item.inventory_id,
        quantity_used: parseInt(item.quantity_used) || 0
      }));
    } else {
      // Automatic deduction
      const [accessories] = await conn.query(`
        SELECT inventory_id, quantity_required FROM treatment_accessories WHERE treatment_id = ?
      `, [apt.treatment_id]);
      deductionItems = accessories.map(acc => ({
        inventory_id: acc.inventory_id,
        quantity_used: acc.quantity_required
      }));
    }

    for (const item of deductionItems) {
      if (item.quantity_used > 0) {
        await conn.query('UPDATE inventory SET quantity = GREATEST(0, quantity - ?) WHERE id = ?', [item.quantity_used, item.inventory_id]);
        await conn.query('INSERT INTO inventory_logs (appointment_id, inventory_id, quantity_used, date) VALUES (?, ?, ?, NOW())',
          [id, item.inventory_id, item.quantity_used]);
      }
    }

    await conn.query('UPDATE appointments SET status = ? WHERE id = ?', ['completed', id]);

    await conn.commit();
    res.json({ message: 'Treatment completed, inventory deducted.' });
  } catch (error) {
    await conn.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    conn.release();
  }
});

// GET usage logs for a specific appointment
app.get('/api/appointments/:id/usage-logs', async (req, res) => {
  try {
    const { id } = req.params;
    const [logs] = await pool.query(`
      SELECT il.inventory_id, il.quantity_used, i.item_name, i.quantity as stock
      FROM inventory_logs il
      JOIN inventory i ON il.inventory_id = i.id
      WHERE il.appointment_id = ?
    `, [id]);
    res.json(logs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST to restock unused items for a completed appointment
app.post('/api/appointments/:id/restock-unused', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { id } = req.params;
    const { items, reason, user_id } = req.body; // array of { inventory_id, quantity_to_restock }

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'No items to restock' });
    }

    await connection.beginTransaction();

    for (const item of items) {
      const qRestock = parseInt(item.quantity_to_restock) || 0;
      if (qRestock <= 0) continue;

      // 1. Get current inventory quantity
      const [[invItem]] = await connection.query('SELECT item_name, quantity FROM inventory WHERE id = ?', [item.inventory_id]);
      if (!invItem) continue;

      // 2. Update inventory stock
      const newQty = invItem.quantity + qRestock;
      await connection.query('UPDATE inventory SET quantity = ? WHERE id = ?', [newQty, item.inventory_id]);

      // 3. Log in inventory_audit_log (stock transaction)
      await connection.query(
        'INSERT INTO inventory_audit_log (inventory_id, old_quantity, new_quantity, quantity_change, reason, user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())',
        [item.inventory_id, invItem.quantity, newQty, qRestock, reason || `Restocked unused from Appointment #${id}`, user_id || 'system']
      );

      // 4. Update the inventory_logs usage record: subtract from quantity_used or delete if it becomes 0
      const [[logRecord]] = await connection.query('SELECT id, quantity_used FROM inventory_logs WHERE appointment_id = ? AND inventory_id = ? ORDER BY date DESC LIMIT 1', [id, item.inventory_id]);
      if (logRecord) {
        const newUsed = Math.max(0, logRecord.quantity_used - qRestock);
        if (newUsed === 0) {
          await connection.query('DELETE FROM inventory_logs WHERE id = ?', [logRecord.id]);
        } else {
          await connection.query('UPDATE inventory_logs SET quantity_used = ? WHERE id = ?', [newUsed, logRecord.id]);
        }
      }
    }

    await connection.commit();
    res.json({ message: 'Unused accessories restocked successfully.' });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.put('/api/appointments/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const [apts] = await pool.query('SELECT status FROM appointments WHERE id = ?', [id]);
    if (apts.length === 0) return res.status(404).json({ error: 'Appointment not found' });
    if (apts[0].status === 'completed') return res.status(400).json({ error: 'Cannot cancel completed appointment' });

    await pool.query('UPDATE appointments SET status = ? WHERE id = ?', ['canceled', id]);
    res.json({ message: 'Appointment canceled' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  LAB TESTS
// ============================================================
app.get('/api/lab-tests', async (req, res) => {
  try {
    const [tests] = await pool.query('SELECT * FROM lab_tests ORDER BY id ASC');
    res.json(tests);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/lab-tests', async (req, res) => {
  try {
    const { test_name, unit, normal_min, normal_max } = req.body;
    const [result] = await pool.query('INSERT INTO lab_tests (test_name, unit, normal_min, normal_max) VALUES (?, ?, ?, ?)',
      [test_name, unit || '', normal_min || null, normal_max || null]);
    res.json({ id: result.insertId, message: 'Lab test added' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  LAB RESULTS
// ============================================================


app.put('/api/lab-results/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { value, is_fit } = req.body;
    await pool.query('UPDATE patient_lab_results SET value = ?, is_fit = ?, recorded_at = NOW() WHERE id = ?',
      [value, is_fit, id]);
    res.json({ message: 'Lab result updated' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  PRESCRIPTIONS
// ============================================================
app.get('/api/prescriptions', async (req, res) => {
  try {
    const [prescriptions] = await pool.query(`
      SELECT p.*, DATE_FORMAT(a.date, '%Y-%m-%d') as appointment_date, a.treatment_type,
        pt.name as patient_name, pt.phone as patient_phone,
        t.name as treatment_name, t.price
      FROM prescriptions p
      JOIN appointments a ON p.appointment_id = a.id
      JOIN patients pt ON a.patient_id = pt.id
      JOIN treatments t ON a.treatment_id = t.id
      ORDER BY p.created_at DESC
    `);
    res.json(prescriptions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/appointments/:id/prescription', async (req, res) => {
  try {
    const { id } = req.params;
    const [prescriptions] = await pool.query(`
      SELECT p.*, DATE_FORMAT(a.date, '%Y-%m-%d') as appointment_date, a.treatment_type,
        pt.name as patient_name, pt.phone as patient_phone,
        t.name as treatment_name, t.price
      FROM prescriptions p
      JOIN appointments a ON p.appointment_id = a.id
      JOIN patients pt ON a.patient_id = pt.id
      JOIN treatments t ON a.treatment_id = t.id
      WHERE p.appointment_id = ?
    `, [id]);
    if (prescriptions.length === 0) return res.status(404).json({ error: 'No prescription found' });
    res.json(prescriptions[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/appointments/:id/prescription', async (req, res) => {
  try {
    const { id } = req.params;
    const { treatment_details, medicines, comments } = req.body;

    const [apts] = await pool.query('SELECT status FROM appointments WHERE id = ?', [id]);
    if (apts.length === 0) return res.status(404).json({ error: 'Appointment not found' });
    if (apts[0].status !== 'completed' && apts[0].status !== 'cleared') {
      return res.status(400).json({ error: 'Appointment must be cleared or completed first' });
    }

    const [existing] = await pool.query('SELECT id FROM prescriptions WHERE appointment_id = ?', [id]);
    if (existing.length > 0) {
      await pool.query('UPDATE prescriptions SET treatment_details = ?, medicines = ?, comments = ? WHERE appointment_id = ?',
        [treatment_details, medicines, comments, id]);
      res.json({ message: 'Prescription updated' });
    } else {
      const [result] = await pool.query('INSERT INTO prescriptions (appointment_id, treatment_details, medicines, comments) VALUES (?, ?, ?, ?)',
        [id, treatment_details, medicines, comments]);
      res.json({ id: result.insertId, message: 'Prescription created' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  INVENTORY
// ============================================================
app.get('/api/inventory', async (req, res) => {
  try {
    const [inventory] = await pool.query('SELECT * FROM inventory ORDER BY item_name ASC');
    res.json(inventory);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/inventory/low-stock', async (req, res) => {
  try {
    const [alerts] = await pool.query('SELECT * FROM inventory WHERE quantity <= threshold');
    res.json(alerts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/inventory', async (req, res) => {
  try {
    const { item_name, quantity, threshold, batch_no, expiry_date, supplier, category } = req.body;
    const [result] = await pool.query(
      'INSERT INTO inventory (item_name, quantity, threshold, batch_no, expiry_date, supplier, category) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [item_name, quantity, threshold || 5, batch_no || null, expiry_date || null, supplier || null, category || null]);
    res.json({ id: result.insertId, message: 'Item added' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


app.put('/api/inventory/:id/restock', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { id } = req.params;
    const { quantity, appointment_id } = req.body;
    if (!quantity || quantity <= 0) return res.status(400).json({ error: 'Invalid quantity' });

    await connection.beginTransaction();

    // 1. Update inventory stock
    await connection.query('UPDATE inventory SET quantity = quantity + ? WHERE id = ?', [quantity, id]);
    const [[item]] = await connection.query('SELECT item_name, quantity FROM inventory WHERE id = ?', [id]);

    // 2. If restocking from usage logs: update inventory_logs too
    if (appointment_id) {
      const [[logRecord]] = await connection.query(
        'SELECT id, quantity_used FROM inventory_logs WHERE appointment_id = ? AND inventory_id = ? ORDER BY date DESC LIMIT 1',
        [appointment_id, id]
      );
      if (logRecord) {
        const newUsed = Math.max(0, logRecord.quantity_used - quantity);
        if (newUsed === 0) {
          await connection.query('DELETE FROM inventory_logs WHERE id = ?', [logRecord.id]);
        } else {
          await connection.query('UPDATE inventory_logs SET quantity_used = ? WHERE id = ?', [newUsed, logRecord.id]);
        }
      }
    }

    await connection.commit();
    res.json({ message: `${quantity} unit(s) returned to stock`, item_name: item.item_name, new_quantity: item.quantity });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});



app.delete('/api/inventory/:id', async (req, res) => {
  try {
    const { id } = req.params;
    // Remove treatment_accessories links first
    await pool.query('DELETE FROM treatment_accessories WHERE inventory_id = ?', [id]);
    await pool.query('DELETE FROM inventory WHERE id = ?', [id]);
    res.json({ message: 'Item deleted' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  INVENTORY TRANSACTIONS (with audit log)
// ============================================================
app.post('/api/inventory/:id/adjust-stock', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { id } = req.params;
    const { quantity_change, reason, user_id } = req.body;
    
    if (!quantity_change || quantity_change === 0) {
      return res.status(400).json({ error: 'Invalid quantity_change' });
    }

    await connection.beginTransaction();
    
    // Get current stock
    const [[item]] = await connection.query('SELECT id, item_name, quantity FROM inventory WHERE id = ?', [id]);
    if (!item) {
      await connection.rollback();
      return res.status(404).json({ error: 'Item not found' });
    }

    const newQuantity = item.quantity + quantity_change;
    if (newQuantity < 0) {
      await connection.rollback();
      return res.status(400).json({ error: 'Insufficient stock' });
    }

    // Update stock
    await connection.query('UPDATE inventory SET quantity = ? WHERE id = ?', [newQuantity, id]);
    
    // Log the change
    await connection.query(
      'INSERT INTO inventory_audit_log (inventory_id, old_quantity, new_quantity, quantity_change, reason, user_id, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())',
      [id, item.quantity, newQuantity, quantity_change, reason || 'Manual adjustment', user_id || 'system']
    );

    await connection.commit();
    res.json({ message: `Stock adjusted by ${quantity_change}`, item_name: item.item_name, new_quantity: newQuantity });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// ============================================================
//  INVENTORY SEARCH & FILTERS
// ============================================================
app.get('/api/inventory/search', async (req, res) => {
  try {
    const { query, filter_low_stock, category, treatment_id, supplier } = req.query;
    let sql = 'SELECT * FROM inventory WHERE 1=1';
    const params = [];

    if (query) {
      sql += ' AND (item_name LIKE ? OR batch_no LIKE ? OR supplier LIKE ?)';
      params.push(`%${query}%`, `%${query}%`, `%${query}%`);
    }

    if (filter_low_stock === 'true') {
      sql += ' AND quantity <= threshold';
    }

    if (category) {
      sql += ' AND category = ?';
      params.push(category);
    }

    if (supplier) {
      sql += ' AND supplier LIKE ?';
      params.push(`%${supplier}%`);
    }

    if (treatment_id) {
      sql = `SELECT DISTINCT i.* FROM inventory i
        JOIN treatment_accessories ta ON i.id = ta.inventory_id
        WHERE ta.treatment_id = ? AND 1=1`;
      params.unshift(treatment_id);
    }

    if (query && treatment_id) {
      sql += ' AND (i.item_name LIKE ? OR i.supplier LIKE ?)';
      params.push(`%${query}%`, `%${query}%`);
    }

    sql += ' ORDER BY item_name ASC';
    const [results] = await pool.query(sql, params);
    res.json(results);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  INVENTORY AUDIT LOG
// ============================================================
app.get('/api/inventory/:id/audit-log', async (req, res) => {
  try {
    const { id } = req.params;
    const [logs] = await pool.query(
      'SELECT * FROM inventory_audit_log WHERE inventory_id = ? ORDER BY created_at DESC LIMIT 50',
      [id]
    );
    res.json(logs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  INVENTORY SOFT DELETE & UNDO
// ============================================================
app.post('/api/inventory/:id/soft-delete', async (req, res) => {
  try {
    const { id } = req.params;
    const { reason, user_id } = req.body;
    
    await pool.query(
      'UPDATE inventory SET is_deleted = true, deleted_at = NOW(), delete_reason = ?, deleted_by = ? WHERE id = ?',
      [reason || 'User action', user_id || 'system', id]
    );

    res.json({ message: 'Item soft-deleted. You can undo within 30 days.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/inventory/:id/undo-delete', async (req, res) => {
  try {
    const { id } = req.params;
    const [[item]] = await pool.query(
      'SELECT deleted_at FROM inventory WHERE id = ? AND is_deleted = true',
      [id]
    );

    if (!item) {
      return res.status(404).json({ error: 'Item not found or not deleted' });
    }

    const deletedTime = new Date(item.deleted_at);
    const now = new Date();
    const daysDiff = (now - deletedTime) / (1000 * 60 * 60 * 24);

    if (daysDiff > 30) {
      return res.status(400).json({ error: 'Undo window expired (30 days max)' });
    }

    await pool.query(
      'UPDATE inventory SET is_deleted = false, deleted_at = NULL, delete_reason = NULL, deleted_by = NULL WHERE id = ?',
      [id]
    );

    res.json({ message: 'Item restored successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  TREATMENT ACCESSORIES
// ============================================================
app.get('/api/treatment-accessories', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT ta.id, ta.treatment_id, ta.inventory_id, ta.quantity_required,
        t.name as treatment_name, i.item_name
      FROM treatment_accessories ta
      JOIN treatments t ON ta.treatment_id = t.id
      JOIN inventory i ON ta.inventory_id = i.id
      ORDER BY t.name, i.item_name
    `);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/treatment-accessories', async (req, res) => {
  try {
    const { treatment_id, inventory_id, quantity_required } = req.body;
    // Prevent duplicates
    const [existing] = await pool.query(
      'SELECT id FROM treatment_accessories WHERE treatment_id = ? AND inventory_id = ?',
      [treatment_id, inventory_id]
    );
    if (existing.length > 0) {
      await pool.query(
        'UPDATE treatment_accessories SET quantity_required = ? WHERE treatment_id = ? AND inventory_id = ?',
        [quantity_required, treatment_id, inventory_id]
      );
      return res.json({ message: 'Updated existing accessory link' });
    }
    const [result] = await pool.query(
      'INSERT INTO treatment_accessories (treatment_id, inventory_id, quantity_required) VALUES (?, ?, ?)',
      [treatment_id, inventory_id, quantity_required || 1]
    );
    res.json({ id: result.insertId, message: 'Accessory linked' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/treatment-accessories/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM treatment_accessories WHERE id = ?', [id]);
    res.json({ message: 'Accessory link removed' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  TREATMENT-ACCESSORIES MAPPING (Visual)
// ============================================================
app.get('/api/treatments/:treatment_id/accessories-visual', async (req, res) => {
  try {
    const { treatment_id } = req.params;
    const [[treatment]] = await pool.query('SELECT id, name FROM treatments WHERE id = ?', [treatment_id]);
    if (!treatment) return res.status(404).json({ error: 'Treatment not found' });

    const [accessories] = await pool.query(`
      SELECT ta.id as mapping_id, ta.quantity_required, i.id, i.item_name, i.quantity, i.threshold
      FROM treatment_accessories ta
      JOIN inventory i ON ta.inventory_id = i.id
      WHERE ta.treatment_id = ?
      ORDER BY i.item_name
    `, [treatment_id]);

    const mapping = {
      treatment: treatment,
      accessories: accessories.map(a => ({
        mapping_id: a.mapping_id,
        inventory_id: a.id,
        item_name: a.item_name,
        quantity_required: a.quantity_required,
        current_stock: a.quantity,
        threshold: a.threshold,
        stock_ok: a.quantity >= a.quantity_required,
        low_stock: a.quantity <= a.threshold
      }))
    };

    res.json(mapping);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// All treatments with their accessories mapping
app.get('/api/treatments-accessories-mapping', async (req, res) => {
  try {
    const [treatments] = await pool.query('SELECT id, name FROM treatments');
    const result = [];

    for (const t of treatments) {
      const [accessories] = await pool.query(`
        SELECT ta.id as mapping_id, ta.quantity_required, i.id, i.item_name, i.quantity, i.threshold
        FROM treatment_accessories ta
        JOIN inventory i ON ta.inventory_id = i.id
        WHERE ta.treatment_id = ?
      `, [t.id]);

      result.push({
        treatment_id: t.id,
        treatment_name: t.name,
        accessories: accessories.map(a => ({
          mapping_id: a.mapping_id,
          inventory_id: a.id,
          item_name: a.item_name,
          quantity_required: a.quantity_required,
          current_stock: a.quantity,
          stock_ok: a.quantity >= a.quantity_required
        }))
      });
    }

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  LAB RESULTS
// ============================================================
app.get('/api/appointments/:id/lab-results', async (req, res) => {
  try {
    const { id } = req.params;
    const [apts] = await pool.query('SELECT lab_notes FROM appointments WHERE id = ?', [id]);
    const labNotes = apts.length > 0 ? apts[0].lab_notes : '';
    const [results] = await pool.query(`
      SELECT 
        lt.id as test_id, lt.test_name, lt.unit, lt.normal_min, lt.normal_max,
        plr.id as result_id, plr.value, plr.is_fit
      FROM lab_tests lt
      LEFT JOIN patient_lab_results plr ON lt.id = plr.lab_test_id AND plr.appointment_id = ?
    `, [id]);
    res.json({ results, lab_notes: labNotes });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/appointments/:id/lab-results', async (req, res) => {
  try {
    const { id } = req.params;
    const data = req.body;
    let results = [];
    let labNotes = '';

    // Support both old array format and new object format
    if (Array.isArray(data)) {
      results = data;
    } else {
      results = data.results || [];
      labNotes = data.lab_notes || '';
    }

    if (labNotes) {
      await pool.query('UPDATE appointments SET lab_notes = ? WHERE id = ?', [labNotes, id]);
    }

    for (const r of results) {
      if (r.is_fit == null) continue;
      const [existing] = await pool.query(
        'SELECT id FROM patient_lab_results WHERE appointment_id = ? AND lab_test_id = ?',
        [id, r.test_id]
      );
      if (existing.length > 0) {
        await pool.query('UPDATE patient_lab_results SET is_fit = ? WHERE id = ?', [r.is_fit, existing[0].id]);
      } else {
        await pool.query('INSERT INTO patient_lab_results (appointment_id, lab_test_id, is_fit) VALUES (?, ?, ?)', [id, r.test_id, r.is_fit]);
      }
    }
    res.json({ message: 'Lab results saved' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  MEDICAL REPORTS
// ============================================================
app.get('/api/reports', async (req, res) => {
  try {
    const [reports] = await pool.query('SELECT * FROM medical_reports ORDER BY uploaded_at DESC');
    res.json(reports);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/reports', async (req, res) => {
  try {
    const { patient_id, report_name, notes } = req.body;
    const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
    const [result] = await pool.query(
      'INSERT INTO medical_reports (patient_id, report_name, notes, uploaded_at) VALUES (?, ?, ?, ?)',
      [patient_id, report_name, notes || '', now]
    );
    res.json({ id: result.insertId, message: 'Report added' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  PATIENT CARDS
// ============================================================
app.get('/api/patient-cards', async (req, res) => {
  try {
    const [cards] = await pool.query(`
      SELECT pc.*,
        p.name as patient_name, p.phone as patient_phone, p.patient_uid,
        t.name as treatment_name,
        DATE_FORMAT(a.date, '%Y-%m-%d') as appointment_date,
        a.status as appointment_status
      FROM patient_cards pc
      JOIN patients p ON pc.patient_id = p.id
      JOIN appointments a ON pc.appointment_id = a.id
      JOIN treatments t ON a.treatment_id = t.id
      ORDER BY pc.created_at DESC
    `);
    // Fetch images for each card
    const result = [];
    for (const card of cards) {
      const [images] = await pool.query(
        'SELECT id, image_type, image_data, label, uploaded_at FROM patient_images WHERE patient_card_id = ? ORDER BY uploaded_at ASC',
        [card.id]
      );
      result.push({ ...card, images });
    }
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/patient-cards/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [cards] = await pool.query(`
      SELECT pc.*,
        p.name as patient_name, p.phone as patient_phone, p.patient_uid,
        t.name as treatment_name,
        DATE_FORMAT(a.date, '%Y-%m-%d') as appointment_date,
        a.status as appointment_status
      FROM patient_cards pc
      JOIN patients p ON pc.patient_id = p.id
      JOIN appointments a ON pc.appointment_id = a.id
      JOIN treatments t ON a.treatment_id = t.id
      WHERE pc.id = ?
    `, [id]);
    if (cards.length === 0) return res.status(404).json({ error: 'Card not found' });
    const [images] = await pool.query(
      'SELECT id, image_type, image_data, label, uploaded_at FROM patient_images WHERE patient_card_id = ? ORDER BY uploaded_at ASC',
      [id]
    );
    res.json({ ...cards[0], images });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/patient-cards/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { patient_uid, age, gender, email, address, blood_group, allergies, medical_history, emergency_contact, notes } = req.body;

    // Check if patient_uid is unique and update it
    if (patient_uid !== undefined) {
      const [cards] = await pool.query('SELECT patient_id FROM patient_cards WHERE id = ?', [id]);
      if (cards.length > 0) {
        const patient_id = cards[0].patient_id;

        if (patient_uid.trim() === '') {
          await pool.query('UPDATE patients SET patient_uid = NULL WHERE id = ?', [patient_id]);
        } else {
          // Check uniqueness
          const [existing] = await pool.query('SELECT id FROM patients WHERE patient_uid = ? AND id != ?', [patient_uid, patient_id]);
          if (existing.length > 0) {
            return res.status(400).json({ error: 'This ID is taken' });
          }

          // Update patient_uid
          await pool.query('UPDATE patients SET patient_uid = ? WHERE id = ?', [patient_uid, patient_id]);
        }
      }
    }

    await pool.query(
      `UPDATE patient_cards SET age=?, gender=?, email=?, address=?, blood_group=?, allergies=?, medical_history=?, emergency_contact=?, notes=? WHERE id=?`,
      [age || null, gender || null, email || null, address || null, blood_group || null, allergies || null, medical_history || null, emergency_contact || null, notes || null, id]
    );
    res.json({ message: 'Patient card updated' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Add image to patient card
app.post('/api/patient-cards/:id/images', async (req, res) => {
  try {
    const { id } = req.params;
    const { image_data, image_type, label } = req.body;
    if (!image_data) return res.status(400).json({ error: 'image_data is required' });
    const [result] = await pool.query(
      'INSERT INTO patient_images (patient_card_id, image_type, image_data, label) VALUES (?, ?, ?, ?)',
      [id, image_type || 'before', image_data, label || '']
    );
    res.json({ id: result.insertId, message: 'Image added' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/patient-cards/:cardId/images/:imgId', async (req, res) => {
  try {
    const { cardId, imgId } = req.params;
    await pool.query('DELETE FROM patient_images WHERE id = ? AND patient_card_id = ?', [imgId, cardId]);
    res.json({ message: 'Image removed' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  USAGE LOGS
// ============================================================
app.get('/api/inventory/logs', async (req, res) => {
  try {
    const [logs] = await pool.query(`
      SELECT 
        il.id, il.quantity_used, il.date,
        il.appointment_id,
        il.inventory_id,
        i.item_name,
        t.name as treatment_name,
        a.treatment_type,
        p.name as patient_name
      FROM inventory_logs il
      JOIN inventory i ON il.inventory_id = i.id
      JOIN appointments a ON il.appointment_id = a.id
      JOIN treatments t ON a.treatment_id = t.id
      JOIN patients p ON a.patient_id = p.id
      ORDER BY il.date DESC
    `);
    res.json(logs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ============================================================
//  REPORTS
// ============================================================
app.get('/api/reports', async (req, res) => {
  try {
    const [reports] = await pool.query(`
      SELECT r.*, p.name as patient_name 
      FROM medical_reports r
      JOIN patients p ON r.patient_id = p.id
      ORDER BY r.uploaded_at DESC
    `);
    res.json(reports);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/reports', async (req, res) => {
  try {
    const { patient_id, report_name, notes } = req.body;
    const [result] = await pool.query('INSERT INTO medical_reports (patient_id, report_name, notes, uploaded_at) VALUES (?, ?, ?, NOW())',
      [patient_id, report_name, notes || '']);
    res.json({ id: result.insertId, message: 'Report uploaded' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.use('/chatbot', express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'public')));

// ============================================================
//  CHATBOT API
// ============================================================
app.post('/api/chat', async (req, res) => {
  try {
    const rawPhone = String(req.body.phone || '').trim();
    const rawName = String(req.body.name || '').trim();
    const rawMessage = String(req.body.message || '').trim();
    const action = String(req.body.action || '').trim().toLowerCase();
    const date = String(req.body.date || '').trim();

    const safePhone = sanitizeInput(rawPhone);
    const safeName = sanitizeInput(rawName || 'Guest');
    const safeMessage = sanitizeInput(rawMessage);
    const lowerMsg = safeMessage.toLowerCase().trim();
    const normalizedPhone = normalizePhone(rawPhone);

    if (!isValidPhone(rawPhone)) {
      return res.status(400).json({ reply: 'Please provide a valid phone number (10-15 digits). Example: +1 555 123 4567.' });
    }

    const [allPatients] = await pool.query('SELECT id, name, phone FROM patients');
    const patientRecord = allPatients.find((p) => normalizePhone(p.phone) === normalizedPhone);
    let patientId = patientRecord?.id;
    if (!patientId) {
      const [inserted] = await pool.query('INSERT INTO patients (name, phone) VALUES (?, ?)', [safeName, safePhone]);
      patientId = inserted.insertId;
    } else if (rawName && patientRecord.name !== rawName) {
      await pool.query('UPDATE patients SET name = ? WHERE id = ?', [safeName, patientId]);
    }

    const displayName = sanitizeInput(patientRecord?.name || safeName);

    if (action === 'book' && date) {
      const [treatments] = await pool.query('SELECT id, name FROM treatments');
      if (treatments.length === 0) return res.json({ reply: "No treatments available at this time." });
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return res.json({ reply: "Invalid date format. Please use YYYY-MM-DD." });

      const [existing] = await pool.query("SELECT id FROM appointments WHERE date = ? AND status != 'canceled'", [date]);
      if (existing.length > 0) {
        return res.json({ reply: `❌ Sorry, ${sanitizeInput(date)} is already booked. Please select another available date.` });
      }

      const treatment = treatments[0];
      await pool.query('INSERT INTO appointments (patient_id, treatment_id, date, status) VALUES (?, ?, ?, ?)', [patientId, treatment.id, date, 'pending']);

      return res.json({ reply: `✅ Appointment request submitted for ${treatment.name} consultation on ${date}. Awaiting admin approval!` });
    }

    if (lowerMsg.includes('book')) return res.json({ reply: "Great! What date? (YYYY-MM-DD format)" });

    if (lowerMsg.includes('status')) {
      if (!patientId) return res.json({ reply: 'No appointments found for your number.' });

      const [apts] = await pool.query(`
        SELECT DATE_FORMAT(a.date, '%Y-%m-%d') as date, a.status, t.name as treatment 
        FROM appointments a JOIN treatments t ON a.treatment_id = t.id 
        WHERE a.patient_id = ? ORDER BY a.date DESC LIMIT 1
      `, [patientId]);

      if (apts.length === 0) return res.json({ reply: "No appointments found." });
      return res.json({ reply: `Your latest: ${apts[0].treatment} on ${apts[0].date} — Status: ${apts[0].status.toUpperCase()}` });
    }

    if (lowerMsg.includes('cancel')) {
      if (!patientId) return res.json({ reply: 'No appointments found for your number.' });

      const [apts] = await pool.query("SELECT id FROM appointments WHERE patient_id = ? AND status IN ('pending','confirmed') ORDER BY date DESC LIMIT 1", [patientId]);
      if (apts.length === 0) return res.json({ reply: "No active appointments to cancel." });

      await pool.query("UPDATE appointments SET status = 'canceled' WHERE id = ?", [apts[0].id]);
      return res.json({ reply: "Your appointment has been canceled." });
    }

    if (lowerMsg.includes('treatment')) {
      return res.json({ reply: "🏥 <b>Our 3 Treatment Types:</b><br><br>1️⃣ <b>ARTAS iX Robotic FUE:</b> The world's most advanced robotic hair transplant system. It uses AI to select the best grafts and robotics for precise extraction without linear scars.<br><br>2️⃣ <b>Hybrid FUE Transplant:</b> Combines the precision of robotic extraction with the artistry of manual implantation for specialized hairlines.<br><br>3️⃣ <b>Manual FUE Transplant:</b> Traditional Follicular Unit Extraction done entirely by hand by our expert surgeons." });
    }

    if (lowerMsg.includes('faq')) {
      return res.json({ reply: "❓ <b>Frequently Asked Questions:</b><br><br><b>Q: Is the procedure painful?</b><br>A: No! Local anesthesia is used, making the procedure virtually painless.<br><br><b>Q: How long is recovery?</b><br>A: Most patients return to normal activities within 3 to 7 days.<br><br><b>Q: Are results permanent?</b><br>A: Yes, transplanted hairs are genetically resistant to balding and will grow for a lifetime.<br><br><i>Have more questions? Reply with <b>treatments</b> or <b>book</b> to schedule a consultation!</i>" });
    }

    // Greetings / Small talk
    const greetings = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 'howdy'];
    if (greetings.includes(lowerMsg)) {
      return res.json({ reply: `Hello there, ${displayName}! 👋 It's great to hear from you. How can I help you today?<div class='quick-replies'><button class='quick-reply-btn' onclick='processUserInput(\"book\")'>📅 Book Appointment</button><button class='quick-reply-btn' onclick='processUserInput(\"status\")'>🔍 Check Status</button><button class='quick-reply-btn' onclick='processUserInput(\"treatments\")'>🏥 View Treatments</button><button class='quick-reply-btn' onclick='processUserInput(\"faq\")'>❓ FAQ</button></div>` });
    }

    if (lowerMsg.includes('how are you')) {
      return res.json({ reply: "I'm doing great, thank you for asking! 🤖 Ready to assist you with your clinic needs. How can I help?" });
    }

    if (lowerMsg.includes('thank') || lowerMsg === 'thx') {
      return res.json({ reply: "You're very welcome! Let me know if you need anything else. 😊" });
    }

    if (lowerMsg.includes('bye') || lowerMsg.includes('goodbye')) {
      return res.json({ reply: "Goodbye! Have a wonderful day. 👋" });
    }

    return res.json({
      reply: "👋 I didn't quite catch that. How can I assist you today?<div class='quick-replies'><button class='quick-reply-btn' onclick='processUserInput(\"book\")'>📅 Book Appointment</button><button class='quick-reply-btn' onclick='processUserInput(\"status\")'>🔍 Check Status</button><button class='quick-reply-btn' onclick='processUserInput(\"cancel\")'>❌ Cancel Appointment</button><button class='quick-reply-btn' onclick='processUserInput(\"treatments\")'>🏥 View Treatments</button><button class='quick-reply-btn' onclick='processUserInput(\"faq\")'>❓ FAQ</button></div>"
    });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
