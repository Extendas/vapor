import Async
import Service

extension Worker where Self: HasContainer {
    /// Returns a future database connection for the
    /// supplied database identifier if one can be fetched.
    /// The database connection will be cached on this worker.
    /// The same database connection will always be returned for
    /// a given worker.
    public func withDatabase<Database, F>(
        _ database: DatabaseIdentifier<Database>,
        closure: @escaping (Database.Connection) throws -> F
    ) -> Future<F.Expectation> where F: FutureType {
        return then {
            let pool: DatabaseConnectionPool<Database>

            /// this is the first attempt to connect to this
            /// db for this request
            if let existing = self.eventLoop.getConnectionPool(database: database) {
                pool = existing
            } else {
                if let container = self.container {
                    pool = try self.eventLoop.makeConnectionPool(
                        database: database,
                        using: container.make(Databases.self, for: Self.self)
                    )
                } else {
                    throw "no container to create databases for connection pools"
                }
            }

            /// request a connection from the pool
            return pool.requestConnection().then { conn in
                return try closure(conn).map { res in
                    pool.releaseConnection(conn)
                    return res
                }
            }
        }
    }

    /// Requests a connection to the database.
    /// important: you must be sure to call `.releaseConnection`
    public func requestConnection<Database>(
        _ database: DatabaseIdentifier<Database>
    ) -> Future<Database.Connection> {
        print("REQUEST \(database)")
        return then {
            let pool: DatabaseConnectionPool<Database>

            /// this is the first attempt to connect to this
            /// db for this request
            if let existing = self.eventLoop.getConnectionPool(database: database) {
                pool = existing
            } else {
                if let container = self.container {
                    pool = try self.eventLoop.makeConnectionPool(
                        database: database,
                        using: container.make(Databases.self, for: Self.self)
                    )
                } else {
                    throw "no container to create databases for connection pools"
                }
            }

            /// request a connection from the pool
            return pool.requestConnection()
        }
    }

    /// Releases a connection back to the pool.
    /// important: make sure to return connections called by `requestConnection`
    /// to this function.
    public func releaseConnection<Database>(
        _ database: DatabaseIdentifier<Database>,
        _ conn: Database.Connection
    ) throws {
        print("RELEASE \(database)")
        /// this is the first attempt to connect to this
        /// db for this request
        guard let pool = self.eventLoop.getConnectionPool(database: database) else {
            throw "no existing pool to release connection"
        }
        pool.releaseConnection(conn)
    }
}

/// MARK:  ConnectionRepresentable

extension Extendable where Self: HasContainer, Self: Worker {
    /// See ConnectionRepresentable.makeConnection
    /// important: make sure to release this connection later.
    public func makeConnection<D>(_ database: DatabaseIdentifier<D>) -> Future<D.Connection> {
        if let active = connections[database.uid]?.connection as? Future<D.Connection> {
            return active
        }

        return requestConnection(database).map { conn in
            self.connections[database.uid] = ActiveConnection(connection: conn) {
                try self.releaseConnection(database, conn)
            }

            return conn
        }
    }

    /// Releases all active connections.
    public func releaseConnections() throws {
        let conns = connections
        connections = [:]
        for (_, conn) in conns {
            try conn.release()
        }
    }

    /// This worker's active connections.
    fileprivate var connections: [String: ActiveConnection] {
        get { return extend["fluent:connections"] as? [String: ActiveConnection] ?? [:] }
        set { return extend["fluent:connections"] = newValue }
    }
}

/// Represents an active connection.
fileprivate struct ActiveConnection {
    var connection: Any
    var release: () throws -> ()
}
