//
//  DatabaseManager.swift
//  vault
//
//  SQLite database manager for users and vaults
//

import Foundation
import SQLite3
import CoreLocation

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {
        openDatabase()
        createTables()
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("VaultDatabase.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTables() {
        // Users table
        let createUsersTable = """
        CREATE TABLE IF NOT EXISTS Users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """
        
        // Vaults table - WITH uuid column
        let createVaultsTable = """
        CREATE TABLE IF NOT EXISTS Vaults (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            uuid TEXT NOT NULL UNIQUE,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            center_latitude REAL NOT NULL,
            center_longitude REAL NOT NULL,
            shape_type TEXT NOT NULL,
            shape_data TEXT NOT NULL,
            color TEXT NOT NULL,
            blocked_apps TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE
        );
        """
        
        executeSQL(createUsersTable)
        executeSQL(createVaultsTable)
        
        // Add migration for existing databases
        addUUIDColumnIfNeeded()
    }
    
    private func addUUIDColumnIfNeeded() {
        // Check if uuid column exists
        let checkSQL = "PRAGMA table_info(Vaults);"
        var statement: OpaquePointer?
        var hasUUID = false
        
        if sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let name = sqlite3_column_text(statement, 1) {
                    let columnName = String(cString: name)
                    if columnName == "uuid" {
                        hasUUID = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(statement)
        
        // Add uuid column if it doesn't exist
        if !hasUUID {
            print("Adding uuid column to Vaults table...")
            executeSQL("ALTER TABLE Vaults ADD COLUMN uuid TEXT;")
            
            // Generate UUIDs for existing rows
            let selectSQL = "SELECT id FROM Vaults;"
            if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
                var existingIds: [Int] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    existingIds.append(Int(sqlite3_column_int(statement, 0)))
                }
                sqlite3_finalize(statement)
                
                // Update each row with a UUID
                for id in existingIds {
                    let uuid = UUID().uuidString
                    let updateSQL = "UPDATE Vaults SET uuid = ? WHERE id = ?;"
                    var updateStatement: OpaquePointer?
                    if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK {
                        sqlite3_bind_text(updateStatement, 1, (uuid as NSString).utf8String, -1, nil)
                        sqlite3_bind_int(updateStatement, 2, Int32(id))
                        sqlite3_step(updateStatement)
                    }
                    sqlite3_finalize(updateStatement)
                }
                print("Migration complete: Added UUIDs to \(existingIds.count) existing vaults")
            }
        }
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error executing SQL: \(sql)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - User Management
    
    func registerUser(name: String, email: String, password: String) -> (success: Bool, userId: Int?, error: String?) {
        let insertSQL = "INSERT INTO Users (name, email, password) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (email as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (password as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                let userId = Int(sqlite3_last_insert_rowid(db))
                sqlite3_finalize(statement)
                return (true, userId, nil)
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                sqlite3_finalize(statement)
                if errorMessage.contains("UNIQUE") {
                    return (false, nil, "Email already exists")
                }
                return (false, nil, "Registration failed")
            }
        }
        
        sqlite3_finalize(statement)
        return (false, nil, "Database error")
    }
    
    func loginUser(email: String, password: String) -> (success: Bool, userId: Int?, name: String?) {
        let querySQL = "SELECT id, name, password FROM Users WHERE email = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (email as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let userId = Int(sqlite3_column_int(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let storedPassword = String(cString: sqlite3_column_text(statement, 2))
                
                sqlite3_finalize(statement)
                
                if storedPassword == password {
                    return (true, userId, name)
                }
            }
        }
        
        sqlite3_finalize(statement)
        return (false, nil, nil)
    }
    
    // MARK: - Vault Management
    
    func saveVault(userId: Int, vault: VaultLocation) -> Bool {
        let insertSQL = """
        INSERT INTO Vaults (uuid, user_id, name, center_latitude, center_longitude, shape_type, shape_data, color, blocked_apps)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        
        // Serialize shape data
        let shapeType: String
        let shapeData: String
        
        switch vault.shape {
        case .circle(let radius):
            shapeType = "circle"
            shapeData = String(radius)
            
        case .quadrilateral(let corners):
            shapeType = "quadrilateral"
            let coordStrings = corners.map { "\($0.latitude),\($0.longitude)" }
            shapeData = coordStrings.joined(separator: ";")
        }
        
        // Serialize blocked apps
        let blockedAppsJSON = vault.blockedApps.joined(separator: ",")
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (vault.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(userId))
            sqlite3_bind_text(statement, 3, (vault.name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 4, vault.coordinate.latitude)
            sqlite3_bind_double(statement, 5, vault.coordinate.longitude)
            sqlite3_bind_text(statement, 6, (shapeType as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 7, (shapeData as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 8, (vault.color as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 9, (blockedAppsJSON as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Error saving vault: \(errorMessage)")
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func updateVault(userId: Int, vault: VaultLocation) -> Bool {
        let updateSQL = """
        UPDATE Vaults 
        SET name = ?, center_latitude = ?, center_longitude = ?, shape_type = ?, shape_data = ?, color = ?, blocked_apps = ?
        WHERE uuid = ? AND user_id = ?;
        """
        var statement: OpaquePointer?
        
        // Serialize shape data
        let shapeType: String
        let shapeData: String
        
        switch vault.shape {
        case .circle(let radius):
            shapeType = "circle"
            shapeData = String(radius)
            
        case .quadrilateral(let corners):
            shapeType = "quadrilateral"
            let coordStrings = corners.map { "\($0.latitude),\($0.longitude)" }
            shapeData = coordStrings.joined(separator: ";")
        }
        
        // Serialize blocked apps
        let blockedAppsJSON = vault.blockedApps.joined(separator: ",")
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (vault.name as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 2, vault.coordinate.latitude)
            sqlite3_bind_double(statement, 3, vault.coordinate.longitude)
            sqlite3_bind_text(statement, 4, (shapeType as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 5, (shapeData as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 6, (vault.color as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 7, (blockedAppsJSON as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 8, (vault.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 9, Int32(userId))
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Error updating vault: \(errorMessage)")
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func loadVaults(userId: Int) -> [VaultLocation] {
        let querySQL = """
        SELECT uuid, name, center_latitude, center_longitude, shape_type, shape_data, color, blocked_apps
        FROM Vaults WHERE user_id = ?;
        """
        var statement: OpaquePointer?
        var vaults: [VaultLocation] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(userId))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let uuidString = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let centerLat = sqlite3_column_double(statement, 2)
                let centerLon = sqlite3_column_double(statement, 3)
                let shapeType = String(cString: sqlite3_column_text(statement, 4))
                let shapeData = String(cString: sqlite3_column_text(statement, 5))
                let color = String(cString: sqlite3_column_text(statement, 6))
                let blockedAppsString = String(cString: sqlite3_column_text(statement, 7))
                
                guard let uuid = UUID(uuidString: uuidString) else { continue }
                
                // Deserialize shape
                let shape: VaultShape
                if shapeType == "circle" {
                    let radius = Double(shapeData) ?? 100.0
                    shape = .circle(radius: radius)
                } else {
                    let coordPairs = shapeData.split(separator: ";")
                    let corners = coordPairs.compactMap { pair -> CLLocationCoordinate2D? in
                        let coords = pair.split(separator: ",")
                        guard coords.count == 2,
                              let lat = Double(coords[0]),
                              let lon = Double(coords[1]) else { return nil }
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                    shape = .quadrilateral(corners: corners)
                }
                
                let blockedApps = blockedAppsString.split(separator: ",").map { String($0) }
                
                let vault = VaultLocation(
                    id: uuid,
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    shape: shape,
                    blockedApps: blockedApps,
                    color: color
                )
                
                vaults.append(vault)
            }
        }
        
        sqlite3_finalize(statement)
        return vaults
    }
    
    func deleteVault(userId: Int, vaultId: UUID) -> Bool {
        let deleteSQL = "DELETE FROM Vaults WHERE user_id = ? AND uuid = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(userId))
            sqlite3_bind_text(statement, 2, (vaultId.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
}
