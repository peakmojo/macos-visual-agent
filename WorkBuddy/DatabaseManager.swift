import Foundation
import SQLite3

class DatabaseManager: ObservableObject {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("workbuddy.sqlite")
        
        dbPath = fileURL.path
        openDatabase()
        createTables()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("Successfully opened connection to database at \(dbPath)")
        } else {
            print("Unable to open database")
        }
    }
    
    private func createTables() {
        createBuddiesTable()
        createScreenshotsTable()
        createActivityTable()
    }
    
    private func createBuddiesTable() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS Buddies(
            Id TEXT PRIMARY KEY,
            Name TEXT,
            Status TEXT,
            Avatar TEXT,
            ProfileImage TEXT,
            IsEnabled INTEGER,
            LastActivity TEXT);
        """
        
        if sqlite3_exec(db, createTableString, nil, nil, nil) == SQLITE_OK {
            print("Buddies table created.")
        } else {
            print("Buddies table could not be created.")
        }
    }
    
    private func createScreenshotsTable() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS Screenshots(
            Id INTEGER PRIMARY KEY AUTOINCREMENT,
            Timestamp TEXT,
            FilePath TEXT,
            BuddyId TEXT,
            FOREIGN KEY(BuddyId) REFERENCES Buddies(Id));
        """
        
        if sqlite3_exec(db, createTableString, nil, nil, nil) == SQLITE_OK {
            print("Screenshots table created.")
        } else {
            print("Screenshots table could not be created.")
        }
    }
    
    private func createActivityTable() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS Activity(
            Id INTEGER PRIMARY KEY AUTOINCREMENT,
            Timestamp TEXT,
            ActivityType TEXT,
            Data TEXT,
            BuddyId TEXT,
            FOREIGN KEY(BuddyId) REFERENCES Buddies(Id));
        """
        
        if sqlite3_exec(db, createTableString, nil, nil, nil) == SQLITE_OK {
            print("Activity table created.")
        } else {
            print("Activity table could not be created.")
        }
    }
    
    func saveBuddy(_ buddy: Buddy) {
        let insertSQL = "INSERT OR REPLACE INTO Buddies (Id, Name, Status, Avatar, ProfileImage, IsEnabled, LastActivity) VALUES (?, ?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, buddy.id, -1, nil)
            sqlite3_bind_text(statement, 2, buddy.name, -1, nil)
            sqlite3_bind_text(statement, 3, String(describing: buddy.status), -1, nil)
            sqlite3_bind_text(statement, 4, buddy.avatar, -1, nil)
            sqlite3_bind_text(statement, 5, buddy.profileImage, -1, nil)
            sqlite3_bind_int(statement, 6, buddy.status != .disabled ? 1 : 0)
            sqlite3_bind_text(statement, 7, ISO8601DateFormatter().string(from: Date()), -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Successfully saved buddy")
            } else {
                print("Could not save buddy")
            }
        } else {
            print("INSERT statement could not be prepared")
        }
        
        sqlite3_finalize(statement)
    }
    
    func loadBuddies() -> [Buddy] {
        let querySQL = "SELECT Id, Name, Status, Avatar, ProfileImage, IsEnabled FROM Buddies"
        var statement: OpaquePointer?
        var buddies: [Buddy] = []
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(describing: String(cString: sqlite3_column_text(statement, 0)))
                let name = String(describing: String(cString: sqlite3_column_text(statement, 1)))
                let statusString = String(describing: String(cString: sqlite3_column_text(statement, 2)))
                let avatar = String(describing: String(cString: sqlite3_column_text(statement, 3)))
                let profileImagePointer = sqlite3_column_text(statement, 4)
                let profileImage = profileImagePointer != nil ? String(cString: profileImagePointer!) : nil
                let isEnabled = sqlite3_column_int(statement, 5) == 1
                
                let status: BuddyStatus
                switch statusString {
                case "watching": status = .watching
                case "onBreak": status = .onBreak
                case "disabled": status = .disabled
                default: status = isEnabled ? .watching : .disabled
                }
                
                let buddy = Buddy(id: id, name: name, status: status, avatar: avatar, profileImage: profileImage)
                buddies.append(buddy)
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(statement)
        return buddies
    }
    
    func saveScreenshot(filePath: String, buddyId: String) {
        let insertSQL = "INSERT INTO Screenshots (Timestamp, FilePath, BuddyId) VALUES (?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 2, filePath, -1, nil)
            sqlite3_bind_text(statement, 3, buddyId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Successfully saved screenshot record")
            } else {
                print("Could not save screenshot record")
            }
        } else {
            print("INSERT statement could not be prepared")
        }
        
        sqlite3_finalize(statement)
    }
    
    func saveActivity(type: String, data: String, buddyId: String) {
        let insertSQL = "INSERT INTO Activity (Timestamp, ActivityType, Data, BuddyId) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 2, type, -1, nil)
            sqlite3_bind_text(statement, 3, data, -1, nil)
            sqlite3_bind_text(statement, 4, buddyId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Successfully saved activity record")
            } else {
                print("Could not save activity record")
            }
        } else {
            print("INSERT statement could not be prepared")
        }
        
        sqlite3_finalize(statement)
    }
    
    deinit {
        sqlite3_close(db)
    }
}