/// Displays all routes registered to the `Application`'s `Router` in an ASCII-formatted table.
///
///     $ swift run Run routes
///     +------+------------------+
///     | GET  | /search          |
///     +------+------------------+
///     | GET  | /hash/:string    |
///     +------+------------------+
///
/// A colon preceding a path component indicates a variable parameter. A colon with no text following
/// is a parameter whose result will be discarded.
///
/// An asterisk indicates a catch-all. Any path components after a catch-all will be discarded and ignored.
public struct RoutesCommand: Command {
    /// See `Command`.
    public var arguments: [CommandArgument] {
        return []
    }

    /// See `Command`.
    public var options: [CommandOption] {
        return []
    }

    /// See `Command`.
    public var help: [String] {
        return ["Displays all registered routes."]
    }

    /// `Router` to use for printing routes.
    private let routes: Routes

    /// Create a new `RoutesCommand`.
    public init(routes: Routes) {
        self.routes = routes
    }

    /// See `Command`.
    public func run(using context: CommandContext) throws -> EventLoopFuture<Void> {
        let console = context.console
        
        var longestMethod = 0
        var longestPath = 0

        for route in self.routes.routes {
            let method = route.method.string
            if method.count > longestMethod {
                longestMethod = method.count
            }

            var pathLength = 0

            for path in route.path {
                switch path {
                case .constant(let const):
                    pathLength += const.count + 1 // /const
                case .parameter(let param):
                    pathLength += param.count + 2 // /:param
                case .anything, .catchall:
                    pathLength += 2 // /*
                }
            }

            if pathLength > longestPath {
                longestPath = pathLength
            }
        }

        func hr() {
            console.print("+-", newLine: false)
            for _ in 0..<longestMethod {
                console.print("-", newLine: false)
            }
            console.print("-+-", newLine: false)
            for _ in 0..<longestPath {
                console.print("-", newLine: false)
            }
            console.print("-+")
        }

        hr()

        for route in routes.routes {
            console.print("| ", newLine: false)

            let method = route.method.string
            console.success(method, newLine: false)

            for _ in 0..<longestMethod - method.count {
                console.print(" ", newLine: false)
            }

            console.print(" | ", newLine: false)

            var pathLength = 0

            route.path.forEach { comp in
                switch comp {
                case .constant(let const):
                    console.info("/", newLine: false)
                    console.print(const, newLine: false)
                    pathLength += const.count + 1
                case .parameter(let param):
                    console.info("/", newLine: false)
                    console.print(":", newLine: false)
                    console.info(param, newLine: false)
                    pathLength += param.count + 2
                case .anything:
                    console.info("/:", newLine: false)
                    pathLength += 2
                case .catchall:
                    console.info("/*", newLine: false)
                    pathLength += 2
                }
            }

            for _ in 0..<longestPath - pathLength {
                console.print(" ", newLine: false)
            }

            console.print(" |")
            hr()
        }

        return context.eventLoop.makeSucceededFuture(())
    }
}

private extension Data {
    /// Converts `Data` to a `String`.
    var string: String {
        return String(data: self, encoding: .utf8) ?? "<invalid utf8>"
    }
}
