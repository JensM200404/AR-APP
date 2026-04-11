// This follows the Repository pattern, decoupling the data
// source from the presentation layer. For a production system, the JSON
// could be replaced by actual data from the cemetary, but I need to look intro
// privacy rules and stuff first. So for now, mockadata.

import Foundation
import Combine

protocol GraveDataServiceProtocol {
    var allGraves: [GraveRecord] { get }

    func search(query: String) -> [GraveRecord]

    func load() async
}

@MainActor
final class GraveDataService: ObservableObject, GraveDataServiceProtocol {

    @Published private(set) var allGraves: [GraveRecord] = []
    @Published private(set) var loadError: Error?
    @Published private(set) var isLoading: Bool = false

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let url = Bundle.main.url(forResource: "graves", withExtension: "json") else {
                throw DataError.fileNotFound("graves.json not found in bundle")
            }

            let graves = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([GraveRecord].self, from: data)
            }.value

            self.allGraves = graves
        } catch {
            self.loadError = error
            print("[GraveDataService] Failed to load graves: \(error)")
        }
    }

    func search(query: String) -> [GraveRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allGraves }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        return allGraves
            .filter { grave in
                grave.fullName.range(of: trimmed, options: options) != nil
                    || grave.section.range(of: trimmed, options: options) != nil
            }
            .sorted { a, b in
                let aPrefix = a.fullName.range(of: trimmed, options: [options, .anchored]) != nil
                let bPrefix = b.fullName.range(of: trimmed, options: [options, .anchored]) != nil
                if aPrefix != bPrefix { return aPrefix }
                return a.lastName < b.lastName
            }
    }
}

enum DataError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let msg):   return "Data file not found: \(msg)"
        case .decodingFailed(let msg): return "Failed to decode data: \(msg)"
        }
    }
}
