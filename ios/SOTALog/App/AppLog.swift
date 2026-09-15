import os

enum AppLog {
    static let database = Logger(subsystem: "com.sotalog.app", category: "database")
    static let network = Logger(subsystem: "com.sotalog.app", category: "network")
    static let sync = Logger(subsystem: "com.sotalog.app", category: "sync")
}
