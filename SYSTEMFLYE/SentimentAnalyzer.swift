import Foundation
import NaturalLanguage
import CoreML
import Combine

// MARK: - Sentiment Models
struct SentimentDocument: Codable, Identifiable {
    let id = UUID()
    var text: String
    var source: String
    var timestamp: Date
    var author: String?
    var url: String?
    var language: String
    var wordCount: Int
    var sentences: [Sentence]

    struct Sentence: Codable, Identifiable {
        let id = UUID()
        var text: String
        var sentiment: SentimentScore
        var entities: [Entity]
        var keywords: [String]
        var topics: [String]
    }

    init(text: String, source: String = "unknown", timestamp: Date = Date(), author: String? = nil, url: String? = nil, language: String = "en") {
        self.id = UUID()
        self.text = text
        self.source = source
        self.timestamp = timestamp
        self.author = author
        self.url = url
        self.language = language
        self.wordCount = text.split { !$0.isLetter }.count
        self.sentences = []
    }
}

struct SentimentScore: Codable, Identifiable {
    let id = UUID()
    var positive: Double
    var negative: Double
    var neutral: Double
    var compound: Double
    var magnitude: Double
    var subjectivity: Double
    var confidence: Double
    var label: Label

    enum Label: String, Codable { case positive = "POSITIVE", negative = "NEGATIVE", neutral = "NEUTRAL", mixed = "MIXED" }

    init(positive: Double = 0, negative: Double = 0, neutral: Double = 0, compound: Double = 0, magnitude: Double = 0, subjectivity: Double = 0, confidence: Double = 0, label: Label = .neutral) {
        self.id = UUID()
        self.positive = max(-1, min(1, positive))
        self.negative = max(-1, min(1, negative))
        self.neutral = max(0, neutral)
        self.compound = max(-1, min(1, compound))
        self.magnitude = max(0, magnitude)
        self.subjectivity = max(0, min(1, subjectivity))
        self.confidence = max(0, min(1, confidence))
        self.label = label
    }

    var dominantEmotion: String {
        if positive > negative && positive > neutral { return "joy" }
        if negative > positive && negative > neutral { return "anger" }
        if neutral > positive && neutral > negative { return "neutral" }
        return "mixed"
    }
}

struct Entity: Codable, Identifiable {
    let id = UUID()
    var text: String
    var type: EntityType
    var confidence: Double
    var mentionCount: Int
    var sentiment: SentimentScore
    var relatedEntities: [String]
    var salience: Double

    enum EntityType: String, Codable, CaseIterable {
        case person = "PERSON"
        case organization = "ORG"
        case location = "GPE"
        case date = "DATE"
        case time = "TIME"
        case currency = "MONEY"
        case percent = "PERCENT"
        case product = "PRODUCT"
        case event = "EVENT"
        case workOfArt = "WORK_OF_ART"
        case law = "LAW"
        case language = "LANGUAGE"
        case ordinal = "ORDINAL"
        case cardinal = "CARDINAL"
        case quantity = "QUANTITY"
        case unknown = "UNKNOWN"
    }
}

struct TopicModel: Codable, Identifiable {
    let id = UUID()
    var topics: [Topic]
    var documentTopicMatrix: [[Double]]
    var coherenceScore: Double
    var perplexity: Double
    var iterations: Int
    var algorithm: Algorithm

    struct Topic: Codable, Identifiable {
        let id = UUID()
        var index: Int
        var keywords: [String]
        var weights: [Double]
        var label: String
        var coherence: Double
        var representativeDocuments: [String]
    }

    enum Algorithm: String, Codable { case lda = "LDA", nmf = "NMF", bertopic = "BERTOPIC", lsa = "LSA" }
}

struct SentimentSummary: Codable, Identifiable {
    let id = UUID()
    var overallSentiment: SentimentScore
    var sentimentOverTime: [(Date, SentimentScore)]
    var entitySentiments: [Entity: SentimentScore]
    var topicSentiments: [String: SentimentScore]
    var keywordFrequency: [String: Int]
    var trendingTopics: [String]
    var alerts: [SentimentAlert]
    var timestamp: Date

    struct SentimentAlert: Codable, Identifiable {
        let id = UUID()
        var severity: Severity
        var message: String
        var affectedEntities: [String]
        var timestamp: Date

        enum Severity: String, Codable { case info = "INFO", warning = "WARNING", critical = "CRITICAL" }
    }
}

// MARK: - Sentiment Analyzer Engine
@MainActor
final class SentimentAnalyzer: ObservableObject {
    static let shared = SentimentAnalyzer()
    @Published private(set) var sentimentScores: [String: SentimentScore] = [:]
    @Published private(set) var summaries: [SentimentSummary] = []
    @Published private(set) var isAnalyzing = false
    private var cancellationToken: Task<Void, Never>?
    private let lexicon = loadSentimentLexicon()
    private let stopwords: Set<String> = ["the", "a", "an", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "shall", "can", "need", "to", "of", "in", "for", "on", "with", "at", "by", "from", "as", "into", "through", "during", "before", "after", "above", "below", "between", "out", "off", "over", "under", "again", "further", "then", "once", "here", "there", "when", "where", "why", "how", "all", "both", "each", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "just", "because", "but", "and", "or", "if", "while", "although", "though"]
    private let maxSummaries = 50

    func analyze(text: String, source: String = "unknown", language: String = "en") async -> SentimentScore {
        let tokens = tokenize(text)
        let sentences = splitIntoSentences(text)
        let sentenceScores = sentences.map { analyzeSentence($0, tokens: tokens) }
        let avgPositive = sentenceScores.map { $0.positive }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let avgNegative = sentenceScores.map { $0.negative }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let avgNeutral = sentenceScores.map { $0.neutral }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let compound = sentenceScores.map { $0.compound }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let magnitude = sentenceScores.map { $0.magnitude }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let confidence = sentenceScores.map { $0.confidence }.reduce(0, +) / Double(max(1, sentenceScores.count))
        let subjectivity = calculateSubjectivity(tokens: tokens)
        let label: SentimentScore.Label = compound > 0.05 ? .positive : compound < -0.05 ? .negative : .neutral
        let score = SentimentScore(positive: avgPositive, negative: avgNegative, neutral: avgNeutral, compound: compound, magnitude: magnitude, subjectivity: subjectivity, confidence: confidence, label: label)
        sentimentScores[source] = score
        return score
    }

    func analyzeBatch(documents: [SentimentDocument]) async -> [SentimentDocument] {
        var results: [SentimentDocument] = []
        for document in documents {
            let score = await analyze(text: document.text, source: document.source)
            let sentences = document.text.splitIntoSentences().map { sentence -> SentimentDocument.Sentence in
                let sentiment = analyzeSentence(sentence, tokens: Array(document.text.split { !$0.isLetter }.map(String.init)))
                let entities = extractEntities(from: sentence)
                let keywords = extractKeywords(from: sentence)
                return SentimentDocument.Sentence(text: sentence, sentiment: sentiment, entities: entities, keywords: keywords, topics: [])
            }
            var doc = document
            doc.sentences = sentences
            results.append(doc)
        }
        return results
    }

    func generateSummary(for documents: [SentimentDocument]) async -> SentimentSummary {
        var sentimentOverTime: [(Date, SentimentScore)] = []
        var entitySentiments: [Entity: SentimentScore] = [:]
        var topicSentiments: [String: SentimentScore] = [:]
        var keywordFrequency: [String: Int] = [:]
        for document in documents {
            let score = await analyze(text: document.text, source: document.source)
            sentimentOverTime.append((document.timestamp, score))
            for sentence in document.sentences {
                for entity in sentence.entities {
                    entitySentiments[entity, default: SentimentScore()] = SentimentScore(positive: (entitySentiments[entity]?.positive ?? 0) + sentence.sentiment.positive, negative: (entitySentiments[entity]?.negative ?? 0) + sentence.sentiment.negative, neutral: (entitySentiments[entity]?.neutral ?? 0) + sentence.sentiment.neutral, compound: (entitySentiments[entity]?.compound ?? 0) + sentence.sentiment.compound, magnitude: (entitySentiments[entity]?.magnitude ?? 0) + sentence.sentiment.magnitude, confidence: (entitySentiments[entity]?.confidence ?? 0) + sentence.sentiment.confidence)
                }
                for keyword in sentence.keywords {
                    keywordFrequency[keyword, default: 0] += 1
                }
            }
        }
        let overallSentiment = SentimentScore(positive: sentimentOverTime.map { $0.1.positive }.reduce(0, +) / Double(max(1, sentimentOverTime.count)), negative: sentimentOverTime.map { $0.1.negative }.reduce(0, +) / Double(max(1, sentimentOverTime.count)), neutral: sentimentOverTime.map { $0.1.neutral }.reduce(0, +) / Double(max(1, sentimentOverTime.count)), compound: sentimentOverTime.map { $0.1.compound }.reduce(0, +) / Double(max(1, sentimentOverTime.count)), magnitude: sentimentOverTime.map { $0.1.magnitude }.reduce(0, +) / Double(max(1, sentimentOverTime.count)), confidence: sentimentOverTime.map { $0.1.confidence }.reduce(0, +) / Double(max(1, sentimentOverTime.count)))
        let trendingTopics = keywordFrequency.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
        let alerts: [SentimentSummary.SentimentAlert] = []
        if overallSentiment.compound < -0.7 { alerts.append(SentimentSummary.SentimentAlert(severity: .critical, message: "Strong negative sentiment detected", affectedEntities: Array(entitySentiments.keys.map { $0.text }), timestamp: Date())) }
        if overallSentiment.positive > 0.8 { alerts.append(SentimentSummary.SentimentAlert(severity: .warning, message: "Extreme positive sentiment - possible overbought signal", affectedEntities: [], timestamp: Date())) }
        let summary = SentimentSummary(overallSentiment: overallSentiment, sentimentOverTime: sentimentOverTime, entitySentiments: entitySentiments, topicSentiments: topicSentiments, keywordFrequency: keywordFrequency, trendingTopics: trendingTopics, alerts: alerts, timestamp: Date())
        if summaries.count >= maxSummaries { summaries.removeFirst() }
        summaries.append(summary)
        return summary
    }

    func performTopicModeling(documents: [SentimentDocument], algorithm: TopicModel.Algorithm = .lda, topicCount: Int = 5) async -> TopicModel? {
        guard documents.count >= topicCount * 2 else { return nil }
        let vocabulary = buildVocabulary(from: documents)
        let documentTermMatrix = buildDocumentTermMatrix(documents: documents, vocabulary: vocabulary)
        let (topics, documentTopicMatrix) = performLDA(documentTermMatrix: documentTermMatrix, topicCount: topicCount, iterations: 100)
        let topicList = topics.enumerated().map { index, topicKeywords in
            let topKeywords = topicKeywords.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
            return TopicModel.Topic(id: UUID(), index: index, keywords: topKeywords, weights: Array(topicKeywords.values.prefix(10)), label: "Topic \(index + 1)", coherence: calculateTopicCoherence(topicKeywords: topicKeywords, vocabulary: vocabulary), representativeDocuments: [])
        }
        let coherenceScore = topicList.map { $0.coherence }.reduce(0, +) / Double(max(1, topicList.count))
        return TopicModel(topics: topicList, documentTopicMatrix: documentTopicMatrix, coherenceScore: coherenceScore, perplexity: 0, iterations: 100, algorithm: algorithm)
    }

    private func analyzeSentence(_ sentence: String, tokens: [String]) -> SentimentScore {
        var positiveScore = 0.0
        var negativeScore = 0.0
        var neutralScore = 0.0
        var totalMagnitude = 0.0
        for token in tokens {
            if let entry = lexicon[token.lowercased()] {
                switch entry.polarity {
                case .positive: positiveScore += entry.weight
                case .negative: negativeScore += entry.weight
                case .neutral: neutralScore += entry.weight
                }
                totalMagnitude += abs(entry.weight)
            }
        }
        let compound = tanh((positiveScore - negativeScore) / max(totalMagnitude, 0.001)) * 0.8
        let magnitude = totalMagnitude / max(Double(tokens.count), 1)
        let confidence = min(1.0, magnitude * 2.0)
        let label: SentimentScore.Label = compound > 0.1 ? .positive : compound < -0.1 ? .negative : .neutral
        return SentimentScore(positive: positiveScore / max(Double(tokens.count), 1), negative: negativeScore / max(Double(tokens.count), 1), neutral: neutralScore / max(Double(tokens.count), 1), compound: compound, magnitude: magnitude, confidence: confidence, label: label)
    }

    private func tokenize(_ text: String) -> [String] {
        return text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        return text.components(separatedBy: CharacterSet(charactersIn: ".!?").inverted).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func extractEntities(from text: String) -> [Entity] {
        var entities: [Entity] = []
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, tag != .otherWord {
                let entityText = String(text[range])
                let type = Entity.EntityType(rawValue: tag.rawValue) ?? .unknown
                entities.append(Entity(text: entityText, type: type, confidence: 0.8, mentionCount: 1, sentiment: SentimentScore(), relatedEntities: [], salience: 0.5))
            }
            return true
        }
        return entities
    }

    private func extractKeywords(from text: String) -> [String] {
        let tokens = tokenize(text).filter { !stopwords.contains($0) && $0.count > 2 }
        let frequency = Dictionary(tokens.map { ($0, 1) }, uniquingKeysWith: +)
        return frequency.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }

    private func calculateSubjectivity(tokens: [String]) -> Double {
        var subjectiveCount = 0
        for token in tokens {
            if lexicon[token]?.polarity == .positive || lexicon[token]?.polarity == .negative {
                subjectiveCount += 1
            }
        }
        return Double(subjectiveCount) / Double(max(1, tokens.count))
    }

    private func buildVocabulary(from documents: [SentimentDocument]) -> [String: Int] {
        var vocabulary: [String: Int] = [:]
        var index = 0
        for document in documents {
            for token in tokenize(document.text) where !stopwords.contains(token) && token.count > 2 {
                if vocabulary[token] == nil { vocabulary[token] = index; index += 1 }
            }
        }
        return vocabulary
    }

    private func buildDocumentTermMatrix(documents: [SentimentDocument], vocabulary: [String: Int]) -> [[Double]] {
        return documents.map { document in
            let tokens = tokenize(document.text)
            var row = Array(repeating: 0.0, count: vocabulary.count)
            for token in tokens {
                if let index = vocabulary[token] { row[index] += 1 }
            }
            let sum = row.reduce(0, +)
            return sum > 0 ? row.map { $0 / sum } : row
        }
    }

    private func performLDA(documentTermMatrix: [[Double]], topicCount: Int, iterations: Int) -> ([String: Double], [[Double]]) {
        let docCount = documentTermMatrix.count
        let vocabSize = documentTermMatrix.first?.count ?? 0
        var topicWordMatrix = Array(repeating: Array(repeating: 1.0 / Double(topicCount), count: vocabSize), count: topicCount)
        var docTopicMatrix = Array(repeating: Array(repeating: 1.0 / Double(topicCount), count: topicCount), count: docCount)
        for _ in 0..<iterations {
            for d in 0..<docCount {
                for w in 0..<vocabSize {
                    if documentTermMatrix[d][w] > 0 {
                        var probs: [Double] = []
                        for t in 0..<topicCount { probs.append(docTopicMatrix[d][t] * topicWordMatrix[t][w]) }
                        let sum = probs.reduce(0, +)
                        let normalized = sum > 0 ? probs.map { $0 / sum } : Array(repeating: 1.0 / Double(topicCount), count: topicCount)
                        for t in 0..<topicCount { docTopicMatrix[d][t] = normalized[t] }
                    }
                }
            }
            for t in 0..<topicCount {
                for w in 0..<vocabSize {
                    var sum = 0.0
                    for d in 0..<docCount { sum += documentTermMatrix[d][w] * docTopicMatrix[d][t] }
                    topicWordMatrix[t][w] = sum / Double(max(1, docCount))
                }
            }
        }
        return (topicWordMatrix[0], docTopicMatrix)
    }

    private func calculateTopicCoherence(topicKeywords: [String: Double], vocabulary: [String: Int]) -> Double {
        let topWords = topicKeywords.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
        guard topWords.count >= 2 else { return 0 }
        var coherence = 0.0
        for i in 0..<topWords.count {
            for j in i + 1..<topWords.count {
                coherence += exp(-Double(abs(i - j)) * 0.5)
            }
        }
        return coherence / Double(max(1, topWords.count * (topWords.count - 1) / 2))
    }
}

private struct LexiconEntry { let polarity: Polarity; let weight: Double }
private enum Polarity { case positive, negative, neutral }

private func loadSentimentLexicon() -> [String: LexiconEntry] {
    var lexicon: [String: LexiconEntry] = [:]
    let positiveWords = ["good", "great", "excellent", "amazing", "wonderful", "fantastic", "superb", "outstanding", "brilliant", "positive", "optimistic", "bullish", "strong", "robust", "healthy", "gains", "profit", "growth", "rise", "surge", "rally", "breakthrough", "success", "win", "advantage", "benefit", "improve", "recovery", "boom", "thriving", "prosperous"]
    let negativeWords = ["bad", "terrible", "awful", "horrible", "poor", "weak", "negative", "pessimistic", "bearish", "crash", "collapse", "decline", "drop", "fall", "loss", "deficit", "risk", "danger", "threat", "crisis", "recession", "downturn", "failure", "problem", "issue", "concern", "worry", "fear", "panic", "selloff", "plunge"]
    for word in positiveWords { lexicon[word] = LexiconEntry(polarity: .positive, weight: 1.0) }
    for word in negativeWords { lexicon[word] = LexiconEntry(polarity: .negative, weight: 1.0) }
    return lexicon
}

// MARK: - String Extension
extension String {
    func splitIntoSentences() -> [String] {
        return self.components(separatedBy: CharacterSet(charactersIn: ".!?").inverted).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
