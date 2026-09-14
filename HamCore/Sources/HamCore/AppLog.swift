import os

public enum AppLog {
    public static let database = Logger(subsystem: "com.sotalog.app", category: "database")
    public static let network = Logger(subsystem: "com.sotalog.app", category: "network")
    public static let sync = Logger(subsystem: "com.sotalog.app", category: "sync")
}
