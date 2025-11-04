# db.py
import sqlite3
import os
from datetime import datetime


class ScanDatabase:
    def __init__(self, db_path='./db/scans.db'):
        self.db_path = db_path
        self.init_database()

    def init_database(self):
        """Initialize the database and create table if it doesn't exist"""
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('''
            CREATE TABLE IF NOT EXISTS scans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fname TEXT NOT NULL,
                date TEXT NOT NULL,
                departam TEXT NOT NULL,
                curr_date TEXT NOT NULL,
            
                unp TEXT
                
            )
        ''')

        conn.commit()
        conn.close()
        print(f"Database initialized at {self.db_path}")

    def insert_scan(self, fname, date, departam, unp):
        """Insert a new scan record with all scanned fields"""
        current_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('''
            INSERT INTO scans (fname, date, departam, curr_date, unp)
            VALUES (?, ?, ?, ?, ?)
        ''', (fname, date, departam, current_date, unp))

        conn.commit()
        scan_id = cursor.lastrowid
        conn.close()

        print(f"Record inserted with ID: {scan_id}")
        return scan_id

    def get_all_scans(self):
        """Retrieve all scan records"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('SELECT * FROM scans')
        scans = cursor.fetchall()

        conn.close()
        return scans

    def get_scan_by_id(self, scan_id):
        """Retrieve a specific scan by ID"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('SELECT * FROM scans WHERE id = ?', (scan_id,))
        scan = cursor.fetchone()

        conn.close()
        return scan

    def search_by_departam(self, departam):
        """Search scans by departamment"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('SELECT * FROM scans WHERE departam LIKE ?', (f'%{departam}%',))
        scans = cursor.fetchall()

        conn.close()
        return scans

    def delete_scan(self, scan_id):
        """Delete a scan record by ID"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute('DELETE FROM scans WHERE id = ?', (scan_id,))
        conn.commit()
        deleted = cursor.rowcount
        conn.close()

        return deleted > 0