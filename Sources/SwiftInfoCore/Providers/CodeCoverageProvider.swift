import Foundation

public struct CodeCoverageProvider: InfoProvider {

    public static let identifier: String = "code_coverage"
    static let tempFileName = "swiftinfo_codecov.txt"


    static var tempFile: URL {
        return URL(fileURLWithPath: "./\(tempFileName)")
    }

    public let description: String = "Code Coverage"
    public let percentage: Int

    public init(percentage: Int) {
        self.percentage = percentage
    }

    public static func extract() throws -> CodeCoverageProvider {
        guard let testLog = FileUtils().testLog else {
            fail("No build log!")
        }
        guard let reportFilePath = testLog.match(regex: "(?<=Generated coverage report: ).*").first else {
            fail("Couldn't find code coverage report, is it enabled?")
        }
        let shell = Shell()
        removeTemporaryFile()
        _ = shell.run(supressOutput: true, "xcrun xccov view \(reportFilePath) --json > \(tempFileName)")
        let data = try! Data(contentsOf: tempFile)
        removeTemporaryFile()
        let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
        let targets = json["targets"] as! [[String: Any]]
        guard let desiredTarget = targets.first(where: {
            let name = ($0["name"] as? String ?? "")
            return name.hasSuffix(".app")
        }) else {
            fail("Couldn't find .app target in code coverage report.")
        }
        let codeCoverage = desiredTarget["lineCoverage"] as! Double
        let rounded = Int(1000 * codeCoverage)
        return CodeCoverageProvider(percentage: rounded)
    }

    static func removeTemporaryFile() {
        _ = Shell().run(supressOutput: true, "rm \(tempFile.path)")
    }

    public func summary(comparingWith other: CodeCoverageProvider?) -> String {
        let regularMessage = "Code Coverage: \(percentage)"
        guard let other = other else {
            return regularMessage
        }
        if percentage == other.percentage {
            return regularMessage
        }
        let difference = abs(other.percentage - percentage)
        let modifier = percentage > other.percentage ? "*grew*" : "was *reduced*"
        return "Test count \(modifier) by \(Double(difference) / 10) (\(Double(percentage) / 10))"
    }
}