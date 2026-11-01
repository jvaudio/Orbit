// Public-key-only verification of the signed feed and its exact release archive.
import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif
import CryptoKit

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "OrbitReleaseVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
final class Feed: NSObject, XMLParserDelegate {
    var enclosures: [[String: String]] = []
    var version = "", shortVersion = "", element = ""
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        element = name
        if name == "enclosure" { enclosures.append(attributes) }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if element == "sparkle:version" { version += string }
        if element == "sparkle:shortVersionString" { shortVersion += string }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { element = "" }
}
do {
    let args = CommandLine.arguments
    try require(args.count == 4 || args.count == 5, "Usage: verify_appcast.swift Info.plist appcast.xml archive.zip [expected-download-url]")
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: args[1])), format: nil) as! [String: Any]
    let publicData = Data(base64Encoded: info["SUPublicEDKey"] as? String ?? "") ?? Data()
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicData)
    let feedData = try Data(contentsOf: URL(fileURLWithPath: args[2]))
    let prefix = Data("<!-- sparkle-signatures:\n".utf8)
    guard let start = feedData.range(of: prefix, options: .backwards),
          let end = feedData.range(of: Data("-->".utf8), in: start.upperBound..<feedData.endIndex) else {
        throw NSError(domain: "OrbitReleaseVerification", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing signed feed block"])
    }
    let content = feedData[..<start.lowerBound]
    let lines = String(decoding: feedData[start.upperBound..<end.lowerBound], as: UTF8.self).split(separator: "\n")
    let signature = lines.first { $0.hasPrefix("edSignature:") }.map { String($0.dropFirst("edSignature:".count)).trimmingCharacters(in: .whitespaces) } ?? ""
    let length = lines.first { $0.hasPrefix("length:") }.flatMap { Int($0.dropFirst("length:".count).trimmingCharacters(in: .whitespaces)) }
    try require(length == content.count, "Signed feed length mismatch")
    try require(key.isValidSignature(Data(base64Encoded: signature) ?? Data(), for: content), "Feed signature rejected")
    let feed = Feed(), parser = XMLParser(data: Data(content))
    parser.shouldResolveExternalEntities = false
    parser.delegate = feed
    try require(parser.parse() && feed.enclosures.count == 1, "Expected one valid release enclosure")
    let enclosure = feed.enclosures[0]
    let archive = try Data(contentsOf: URL(fileURLWithPath: args[3]))
    let version = info["CFBundleShortVersionString"] as? String ?? ""
    let expectedURL = args.count == 5 ? args[4] : "https://github.com/jvaudio/Orbit/releases/download/v\(version)/Orbit-\(version)-macOS-universal.zip"
    try require(enclosure["url"] == expectedURL, "Unexpected archive download URL")
    try require(feed.version == info["CFBundleVersion"] as? String && feed.shortVersion == version, "Feed/app version mismatch")
    try require(Int(enclosure["length"] ?? "") == archive.count, "Archive length mismatch")
    try require(key.isValidSignature(Data(base64Encoded: enclosure["sparkle:edSignature"] ?? "") ?? Data(), for: archive), "Archive signature rejected")
    print("Feed and archive verified against shipped public key (\(version), \(archive.count) bytes)")
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
