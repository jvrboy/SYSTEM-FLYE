import Foundation

struct NewsArticle: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let domain: String
    let publishedAt: Date?
    let tone: Double
}

struct NewsSentimentSnapshot: Codable, Equatable {
    let pair: String
    let score: Double
    let articleCount: Int
    let bullishCount: Int
    let bearishCount: Int
    let neutralCount: Int
    let articles: [NewsArticle]
    let fetchedAt: Date
}

@MainActor
final class NewsSentimentService: ObservableObject {
    static let shared = NewsSentimentService()
    @Published private(set) var snapshots: [String: NewsSentimentSnapshot] = [:]
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    private var monitorTask: Task<Void, Never>?

    func startMonitoring(pairs: [String], interval: TimeInterval = 300) {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                for pair in pairs { _ = await self?.fetch(pair: pair) }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    deinit { monitorTask?.cancel() }

    func fetch(pair: String, timespan: String = "2h", maxRecords: Int = 50) async -> NewsSentimentSnapshot? {
        guard !pair.isEmpty else { return nil }
        isLoading = true
        defer { isLoading = false }
        let query = "\(pair.prefix(3)) OR \(pair.suffix(3)) OR forex"
        var components = URLComponents(string: "https://api.gdeltproject.org/api/v2/doc/doc")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "mode", value: "ArtList"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "maxrecords", value: String(min(250, max(1, maxRecords)))),
            URLQueryItem(name: "timespan", value: timespan),
            URLQueryItem(name: "sort", value: "datedesc")
        ]
        guard let url = components?.url else { lastError = "Invalid news URL"; return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw NewsError.invalidResponse }
            let decoded = try JSONDecoder().decode(GDELTArticleResponse.self, from: data)
            let articles = decoded.articles.compactMap { article -> NewsArticle? in
                guard let title = article.title, let link = article.url else { return nil }
                let tone = Self.score(text: title, pair: pair)
                return NewsArticle(id: UUID(), title: title, url: link, domain: article.domain ?? "unknown", publishedAt: Self.parse(date: article.seendate), tone: tone)
            }
            let bullish = articles.filter { $0.tone > 0.12 }.count
            let bearish = articles.filter { $0.tone < -0.12 }.count
            let neutral = articles.count - bullish - bearish
            let score = articles.isEmpty ? 0 : articles.map(\.tone).reduce(0, +) / Double(articles.count)
            let snapshot = NewsSentimentSnapshot(pair: pair, score: min(1, max(-1, score)), articleCount: articles.count, bullishCount: bullish, bearishCount: bearish, neutralCount: neutral, articles: articles, fetchedAt: Date())
            snapshots[pair] = snapshot
            lastError = nil
            return snapshot
        } catch {
            lastError = "News sentiment failed: \(error.localizedDescription)"
            return nil
        }
    }

    private static func score(text: String, pair: String) -> Double {
        let tokens = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        let positive = Set(["gain", "gains", "growth", "strong", "strength", "rally", "rallies", "bullish", "optimism", "recovery", "improves", "improved", "beat", "surplus", "hawkish", "support"])
        let negative = Set(["loss", "losses", "weak", "weakness", "fall", "falls", "bearish", "risk", "recession", "decline", "declines", "miss", "deficit", "dovish", "crisis", "war"])
        let positiveScore = tokens.intersection(positive).count
        let negativeScore = tokens.intersection(negative).count
        let relevance = tokens.contains(pair.prefix(3).lowercased()) || tokens.contains(pair.suffix(3).lowercased()) ? 1.25 : 1
        return min(1, max(-1, Double(positiveScore - negativeScore) / Double(max(1, positiveScore + negativeScore)) * relevance))
    }

    private static func parse(date: String?) -> Date? {
        guard let date, date.count >= 14 else { return nil }
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: String(date.prefix(14)))
    }
}

private struct GDELTArticleResponse: Decodable {
    let articles: [GDELTArticle]
}

private struct GDELTArticle: Decodable {
    let title: String?
    let url: String?
    let domain: String?
    let seendate: String?
}

enum NewsError: LocalizedError {
    case invalidResponse
    var errorDescription: String? { "The live news provider returned an invalid response." }
}
