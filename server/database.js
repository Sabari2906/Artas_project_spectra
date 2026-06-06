const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  uri: process.env.MYSQL_URI || 'mysql://root:password@localhost:3306/clinic',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

async function initDb() {
  try {
    const conn = await pool.getConnection();
    console.log("Connected to MySQL via Pool.");

    // ========================
    //  CORE TABLES
    // ========================
    await conn.query(`
      CREATE TABLE IF NOT EXISTS patients (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        phone VARCHAR(255) UNIQUE NOT NULL,
        whatsapp_id VARCHAR(255)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS treatments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL UNIQUE
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS inventory (
        id INT AUTO_INCREMENT PRIMARY KEY,
        item_name VARCHAR(255) NOT NULL UNIQUE,
        quantity INT NOT NULL DEFAULT 0,
        threshold INT NOT NULL DEFAULT 5
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS treatment_accessories (
        id INT AUTO_INCREMENT PRIMARY KEY,
        treatment_id INT,
        inventory_id INT,
        quantity_required INT,
        FOREIGN KEY(treatment_id) REFERENCES treatments(id),
        FOREIGN KEY(inventory_id) REFERENCES inventory(id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS appointments (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id INT,
        treatment_id INT,
        date DATE NOT NULL,
        status ENUM('pending','confirmed','completed','canceled') NOT NULL DEFAULT 'confirmed',
        FOREIGN KEY(patient_id) REFERENCES patients(id),
        FOREIGN KEY(treatment_id) REFERENCES treatments(id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS inventory_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        appointment_id INT,
        inventory_id INT,
        quantity_used INT,
        date DATETIME NOT NULL,
        FOREIGN KEY(appointment_id) REFERENCES appointments(id),
        FOREIGN KEY(inventory_id) REFERENCES inventory(id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS medical_reports (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id INT,
        report_name VARCHAR(255) NOT NULL,
        notes TEXT,
        uploaded_at DATETIME NOT NULL,
        FOREIGN KEY(patient_id) REFERENCES patients(id)
      )
    `);

    // ========================
    //  NEW WORKFLOW TABLES
    // ========================
    await conn.query(`
      CREATE TABLE IF NOT EXISTS lab_tests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        test_name VARCHAR(255) NOT NULL,
        unit VARCHAR(100) DEFAULT '',
        normal_min DECIMAL(10,2) DEFAULT NULL,
        normal_max DECIMAL(10,2) DEFAULT NULL
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS patient_lab_results (
        id INT AUTO_INCREMENT PRIMARY KEY,
        appointment_id INT NOT NULL,
        lab_test_id INT NOT NULL,
        value VARCHAR(100) DEFAULT '',
        is_fit TINYINT(1) DEFAULT NULL,
        recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(appointment_id) REFERENCES appointments(id),
        FOREIGN KEY(lab_test_id) REFERENCES lab_tests(id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS prescriptions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        appointment_id INT NOT NULL,
        treatment_details TEXT,
        medicines TEXT,
        comments TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(appointment_id) REFERENCES appointments(id)
      )
    `);

    // ========================
    //  PATIENT DATA TABLES
    // ========================
    await conn.query(`
      CREATE TABLE IF NOT EXISTS patient_cards (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id INT NOT NULL,
        appointment_id INT NOT NULL,
        age VARCHAR(10) DEFAULT NULL,
        gender VARCHAR(20) DEFAULT NULL,
        email VARCHAR(255) DEFAULT NULL,
        address TEXT DEFAULT NULL,
        blood_group VARCHAR(10) DEFAULT NULL,
        allergies TEXT DEFAULT NULL,
        medical_history TEXT DEFAULT NULL,
        emergency_contact VARCHAR(255) DEFAULT NULL,
        notes TEXT DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_patient_appointment (patient_id, appointment_id),
        FOREIGN KEY(patient_id) REFERENCES patients(id),
        FOREIGN KEY(appointment_id) REFERENCES appointments(id)
      )
    `);

    await conn.query(`
      CREATE TABLE IF NOT EXISTS patient_images (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_card_id INT NOT NULL,
        image_type ENUM('before','after','other') DEFAULT 'before',
        image_data MEDIUMTEXT NOT NULL,
        label VARCHAR(255) DEFAULT NULL,
        uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(patient_card_id) REFERENCES patient_cards(id) ON DELETE CASCADE
      )
    `);

    // ========================
    //  SCHEMA MIGRATIONS
    // ========================
    const alterSafe = async (sql) => {
      try { await conn.query(sql); } catch(e) { /* column may already exist */ }
    };

    await alterSafe("ALTER TABLE treatments ADD COLUMN type ENUM('fully_robotic','hybrid','manual') DEFAULT 'fully_robotic'");
    await alterSafe("ALTER TABLE treatments ADD COLUMN price DECIMAL(10,2) DEFAULT 0");
    await alterSafe("ALTER TABLE treatments ADD COLUMN description TEXT DEFAULT NULL");

    await alterSafe("ALTER TABLE patients ADD COLUMN patient_uid VARCHAR(50) UNIQUE DEFAULT NULL");

    await alterSafe("ALTER TABLE appointments MODIFY COLUMN status ENUM('pending','confirmed','testing','cleared','not_cleared','completed','canceled') NOT NULL DEFAULT 'pending'");
    await alterSafe("ALTER TABLE appointments ADD COLUMN treatment_type ENUM('fully_robotic','hybrid','manual') DEFAULT NULL");
    await alterSafe("ALTER TABLE appointments ADD COLUMN doctor_notes TEXT DEFAULT NULL");
    await alterSafe("ALTER TABLE appointments ADD COLUMN lab_notes TEXT DEFAULT NULL");
    await alterSafe("ALTER TABLE appointments ADD COLUMN treatment_date DATE DEFAULT NULL");

    await alterSafe("ALTER TABLE inventory ADD COLUMN batch_no VARCHAR(100) DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN expiry_date VARCHAR(20) DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN supplier VARCHAR(255) DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN category VARCHAR(100) DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN is_deleted BOOLEAN DEFAULT false");
    await alterSafe("ALTER TABLE inventory ADD COLUMN deleted_at DATETIME DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN delete_reason VARCHAR(500) DEFAULT NULL");
    await alterSafe("ALTER TABLE inventory ADD COLUMN deleted_by VARCHAR(100) DEFAULT NULL");

    // Audit log table for inventory transactions
    await conn.query(`
      CREATE TABLE IF NOT EXISTS inventory_audit_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        inventory_id INT NOT NULL,
        old_quantity INT NOT NULL,
        new_quantity INT NOT NULL,
        quantity_change INT NOT NULL,
        reason VARCHAR(500) DEFAULT NULL,
        user_id VARCHAR(100) DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(inventory_id) REFERENCES inventory(id) ON DELETE CASCADE,
        INDEX idx_inventory_id (inventory_id),
        INDEX idx_created_at (created_at)
      )
    `);

    // ========================
    //  SEED DATA
    // ========================
    const [rows] = await conn.query('SELECT COUNT(*) as count FROM treatments');
    if (rows[0].count === 0) {
      console.log("Seeding initial data...");

      const [t1r] = await conn.execute("INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)",
        ['ARTAS iX Robotic Hair Transplant', 'fully_robotic', 150000, 'Fully robotic FUE hair transplant using ARTAS iX system']);
      const t1 = t1r.insertId;
      const [t2r] = await conn.execute("INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)",
        ['Hybrid FUE Transplant', 'hybrid', 100000, 'Robotic extraction with manual implantation']);
      const t2 = t2r.insertId;
      const [t3r] = await conn.execute("INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)",
        ['Manual FUE Transplant', 'manual', 60000, 'Traditional manual FUE hair transplant']);
      const t3 = t3r.insertId;
      const [t4r] = await conn.execute("INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)",
        ['PRP Hair Therapy', 'manual', 25000, 'Platelet-Rich Plasma therapy for hair restoration']);
      const t4 = t4r.insertId;
      const [t5r] = await conn.execute("INSERT INTO treatments (name, type, price, description) VALUES (?, ?, ?, ?)",
        ['Scalp Micropigmentation', 'manual', 35000, 'Non-surgical scalp tattoo for density illusion']);
      const t5 = t5r.insertId;

      const insertInv = async (name, q, th) => {
        const [r] = await conn.execute('INSERT INTO inventory (item_name, quantity, threshold) VALUES (?, ?, ?)', [name, q, th]);
        return r.insertId;
      };
      const inv1 = await insertInv('Punch Cartridges', 1, 3);
      const inv2 = await insertInv('Sterile Needles', 50, 20);
      const inv3 = await insertInv('Graft Tray', 2, 5);
      const inv4 = await insertInv('Sterile Drapes', 10, 5);
      const inv5 = await insertInv('PRP Kit', 8, 4);
      const inv6 = await insertInv('Centrifuge Tubes', 15, 10);
      const inv7 = await insertInv('Micropigmentation Ink (Black)', 3, 2);
      const inv8 = await insertInv('Micropigmentation Needles', 20, 10);
      const inv9 = await insertInv('Implanter Pens', 5, 3);
      const inv10 = await insertInv('Saline Solution', 20, 10);

      const insertAcc = async (t_id, inv_id, count) => {
        await conn.execute('INSERT INTO treatment_accessories (treatment_id, inventory_id, quantity_required) VALUES (?, ?, ?)', [t_id, inv_id, count]);
      };
      await insertAcc(t1, inv1, 2); await insertAcc(t1, inv2, 10); await insertAcc(t1, inv3, 1); await insertAcc(t1, inv4, 2);
      await insertAcc(t2, inv1, 1); await insertAcc(t2, inv2, 8); await insertAcc(t2, inv3, 1); await insertAcc(t2, inv9, 2);
      await insertAcc(t3, inv2, 10); await insertAcc(t3, inv3, 1); await insertAcc(t3, inv4, 2); await insertAcc(t3, inv9, 3);
      await insertAcc(t4, inv5, 1); await insertAcc(t4, inv2, 5); await insertAcc(t4, inv6, 2);
      await insertAcc(t5, inv7, 1); await insertAcc(t5, inv8, 3);

      const insertPatient = async (name, phone) => {
        const [r] = await conn.execute('INSERT INTO patients (name, phone) VALUES (?, ?)', [name, phone]);
        return r.insertId;
      };
      const p1 = await insertPatient('Ravi Kumar', '+919876543210');
      const p2 = await insertPatient('Sarah Johnson', '+14155551234');
      const p3 = await insertPatient('Ahmed Khan', '+971501234567');

      const d1 = new Date(); d1.setDate(d1.getDate() + 3);
      const d2 = new Date(); d2.setDate(d2.getDate() + 5);
      const d3 = new Date(); d3.setDate(d3.getDate() - 2);
      const d1Str = d1.toISOString().split('T')[0];
      const d2Str = d2.toISOString().split('T')[0];
      const d3Str = d3.toISOString().split('T')[0];

      await conn.execute('INSERT INTO appointments (patient_id, treatment_id, date, status) VALUES (?, ?, ?, ?)', [p1, t1, d1Str, 'pending']);
      await conn.execute('INSERT INTO appointments (patient_id, treatment_id, date, status) VALUES (?, ?, ?, ?)', [p2, t4, d2Str, 'confirmed']);
      await conn.execute('INSERT INTO appointments (patient_id, treatment_id, date, status, treatment_type) VALUES (?, ?, ?, ?, ?)', [p3, t5, d3Str, 'completed', 'manual']);

      const d3dt = d3.toISOString().slice(0, 19).replace('T', ' ');
      await conn.execute('INSERT INTO inventory_logs (appointment_id, inventory_id, quantity_used, date) VALUES (?, ?, ?, ?)', [3, inv7, 1, d3dt]);
      await conn.execute('INSERT INTO inventory_logs (appointment_id, inventory_id, quantity_used, date) VALUES (?, ?, ?, ?)', [3, inv8, 3, d3dt]);

      const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
      await conn.execute('INSERT INTO medical_reports (patient_id, report_name, notes, uploaded_at) VALUES (?, ?, ?, ?)',
        [p3, 'Post-Treatment Report - SMP', 'Initial session completed successfully.', now]);

      console.log("Seed data inserted.");
    }

    // Seed lab tests
    const [ltRows] = await conn.query('SELECT COUNT(*) as count FROM lab_tests');
    if (ltRows[0].count === 0) {
      console.log("Seeding lab tests...");
      const labTests = [
        ['Blood Pressure (Systolic)', 'mmHg', 90, 140],
        ['Blood Pressure (Diastolic)', 'mmHg', 60, 90],
        ['Blood Sugar (Fasting)', 'mg/dL', 70, 110],
        ['Hemoglobin', 'g/dL', 12.0, 17.5],
        ['Platelet Count', '×10³/µL', 150, 400],
        ['WBC Count', '×10³/µL', 4.5, 11.0],
        ['Creatinine', 'mg/dL', 0.6, 1.2],
        ['HIV Test', 'Result', 0, 0],
        ['Hepatitis B', 'Result', 0, 0],
        ['PT/INR', 'seconds', 11, 15],
      ];
      for (const [name, unit, min, max] of labTests) {
        await conn.execute('INSERT INTO lab_tests (test_name, unit, normal_min, normal_max) VALUES (?, ?, ?, ?)', [name, unit, min, max]);
      }
      console.log("Lab tests seeded.");
    }

    console.log("Database initialized successfully.");
    conn.release();
  } catch (err) {
    console.error("DB Initialization Error:", err);
  }
}

initDb();

module.exports = pool;
