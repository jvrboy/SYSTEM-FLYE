import Foundation
import Accelerate
import Combine

// MARK: - Negotiation Types

public struct NegotiationProposal: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var proposerID: UUID
    public var receiverID: UUID
    public var taskID: UUID
    public var capabilities: [String]
    public var offeredPrice: Double
    public var estimatedDuration: TimeInterval
    public var confidence: Double
    public var terms: [String: String]
    public var constraints: [String: String]
    public var validUntil: Date
    public var timestamp: Date
    public var status: ProposalStatus
    public var counterProposalID: UUID?

    public init(
        id: UUID = UUID(),
        proposerID: UUID,
        receiverID: UUID,
        taskID: UUID,
        capabilities: [String] = [],
        offeredPrice: Double = 0,
        estimatedDuration: TimeInterval = 1,
        confidence: Double = 1,
        terms: [String: String] = [:],
        constraints: [String: String] = [:],
        validUntil: Date = Date().addingTimeInterval(60),
        timestamp: Date = Date(),
        status: ProposalStatus = .pending,
        counterProposalID: UUID? = nil
    ) {
        self.id = id
        self.proposerID = proposerID
        self.receiverID = receiverID
        self.taskID = taskID
        self.capabilities = capabilities
        self.offeredPrice = offeredPrice
        self.estimatedDuration = estimatedDuration
        self.confidence = confidence
        self.terms = terms
        self.constraints = constraints
        self.validUntil = validUntil
        self.timestamp = timestamp
        self.status = status
        self.counterProposalID = counterProposalID
    }
}

public enum ProposalStatus: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case countered = "COUNTERED"
    case expired = "EXPIRED"
    case withdrawn = "WITHDRAWN"
    case awarded = "AWARDED"
}

public struct ContractNetMessage: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var managerID: UUID
    public var contractorID: UUID
    public var taskID: UUID
    public var messageType: ContractNetMessageType
    public var proposal: NegotiationProposal?
    public var payload: Data
    public var timestamp: Date
    public var deadline: Date
    public var evaluationCriteria: [String: Double]
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        managerID: UUID,
        contractorID: UUID,
        taskID: UUID,
        messageType: ContractNetMessageType,
        proposal: NegotiationProposal? = nil,
        payload: Data = Data(),
        timestamp: Date = Date(),
        deadline: Date = Date().addingTimeInterval(30),
        evaluationCriteria: [String: Double] = [:],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.managerID = managerID
        self.contractorID = contractorID
        self.taskID = taskID
        self.messageType = messageType
        self.proposal = proposal
        self.payload = payload
        self.timestamp = timestamp
        self.deadline = deadline
        self.evaluationCriteria = evaluationCriteria
        self.metadata = metadata
    }
}

public enum ContractNetMessageType: String, Codable, Sendable, CaseIterable {
    case callForProposals = "CFP"
    case proposal = "PROPOSAL"
    case accept = "ACCEPT"
    case reject = "REJECT"
    case counterProposal = "COUNTER"
    case cancel = "CANCEL"
}

public struct AuctionBid: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var bidderID: UUID
    public var auctionID: UUID
    public var bidAmount: Double
    public var estimatedValue: Double
    public var confidence: Double
    public var strategy: BiddingStrategy
    public var metadata: [String: String]
    public var timestamp: Date
    public var isBinding: Bool

    public init(
        id: UUID = UUID(),
        bidderID: UUID,
        auctionID: UUID,
        bidAmount: Double,
        estimatedValue: Double,
        confidence: Double = 1,
        strategy: BiddingStrategy = .straight,
        metadata: [String: String] = [:],
        timestamp: Date = Date(),
        isBinding: Bool = false
    ) {
        self.id = id
        self.bidderID = bidderID
        self.auctionID = auctionID
        self.bidAmount = bidAmount
        self.estimatedValue = estimatedValue
        self.confidence = confidence
        self.strategy = strategy
        self.metadata = metadata
        self.timestamp = timestamp
        self.isBinding = isBinding
    }
}

public enum BiddingStrategy: String, Codable, Sendable, CaseIterable {
    case straight = "STRAIGHT"
    case incremental = "INCREMENTAL"
    case shaded = "SHADED"
    case dynamic = "DYNAMIC"
    case lastMinute = "LAST_MINUTE"
}

public struct AuctionRound: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var auctionID: UUID
    public var roundNumber: Int
    public var bids: [AuctionBid]
    public var leadingBid: AuctionBid?
    public var startedAt: Date
    public var endedAt: Date?
    public var isActive: Bool

    public init(id: UUID = UUID(), auctionID: UUID, roundNumber: Int, bids: [AuctionBid] = []) {
        self.id = id
        self.auctionID = auctionID
        self.roundNumber = roundNumber
        self.bids = bids
        self.leadingBid = bids.max { $0.bidAmount < $1.bidAmount }
        self.startedAt = Date()
        self.endedAt = nil
        self.isActive = true
    }
}

public struct Auction: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var auctioneerID: UUID
    public var taskID: UUID
    public var auctionType: AuctionType
    public var startPrice: Double
    public var reservePrice: Double
    public var currentPrice: Double
    public var rounds: [AuctionRound]
    public var participants: [UUID]
    public var winnerID: UUID?
    public var winningBid: AuctionBid?
    public var status: AuctionStatus
    public var startTime: Date
    public var endTime: Date?
    public var minBidIncrement: Double
    public var roundDuration: TimeInterval
    public var maxRounds: Int
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        auctioneerID: UUID,
        taskID: UUID,
        auctionType: AuctionType = .english,
        startPrice: Double = 0,
        reservePrice: Double = 0,
        currentPrice: Double = 0,
        rounds: [AuctionRound] = [],
        participants: [UUID] = [],
        winnerID: UUID? = nil,
        winningBid: AuctionBid? = nil,
        status: AuctionStatus = .open,
        startTime: Date = Date(),
        endTime: Date? = nil,
        minBidIncrement: Double = 0.01,
        roundDuration: TimeInterval = 10,
        maxRounds: Int = 10,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.auctioneerID = auctioneerID
        self.taskID = taskID
        self.auctionType = auctionType
        self.startPrice = startPrice
        self.reservePrice = reservePrice
        self.currentPrice = currentPrice
        self.rounds = rounds
        self.participants = participants
        self.winnerID = winnerID
        self.winningBid = winningBid
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.minBidIncrement = minBidIncrement
        self.roundDuration = roundDuration
        self.maxRounds = maxRounds
        self.metadata = metadata
    }
}

public enum AuctionType: String, Codable, Sendable, CaseIterable {
    case english = "ENGLISH"
    case dutch = "DUTCH"
    case sealedBid = "SEALED_BID"
    case vickrey = "VICKREY"
    case combinatorial = "COMBINATORIAL"
}

public enum AuctionStatus: String, Codable, Sendable, CaseIterable {
    case open = "OPEN"
    case closed = "CLOSED"
    case pending = "PENDING"
    case awarded = "AWARDED"
    case cancelled = "CANCELLED"
}

public struct NegotiationSession: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var participants: [UUID]
    public var topic: String
    public var protocol: NegotiationProtocol
    public var proposals: [NegotiationProposal]
    public var currentRound: Int
    public var maxRounds: Int
    public var status: SessionStatus
    public var winnerID: UUID?
    public var winningProposalID: UUID?
    public var startTime: Date
    public var endTime: Date?
    public var timeout: TimeInterval
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        participants: [UUID],
        topic: String,
        protocol: NegotiationProtocol = .contractNet,
        proposals: [NegotiationProposal] = [],
        currentRound: Int = 0,
        maxRounds: Int = 10,
        status: SessionStatus = .active,
        winnerID: UUID? = nil,
        winningProposalID: UUID? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        timeout: TimeInterval = 60,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.participants = participants
        self.topic = topic
        self.protocol = protocol
        self.proposals = proposals
        self.currentRound = currentRound
        self.maxRounds = maxRounds
        self.status = status
        self.winnerID = winnerID
        self.winningProposalID = winningProposalID
        self.startTime = startTime
        self.endTime = endTime
        self.timeout = timeout
        self.metadata = metadata
    }
}

public enum NegotiationProtocol: String, Codable, Sendable, CaseIterable {
    case contractNet = "CONTRACT_NET"
    case auction = "AUCTION"
    case bargaining = "BARGAINING"
    case mediation = "MEDIATION"
    case arbitration = "ARBITRATION"
}

public enum SessionStatus: String, Codable, Sendable, CaseIterable {
    case active = "ACTIVE"
    case completed = "COMPLETED"
    case expired = "EXPIRED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"
}

public struct NegotiationMetrics: Sendable {
    public var totalSessions: Int
    public var completedSessions: Int
    public var failedSessions: Int
    public var averageDuration: TimeInterval
    public var averageRounds: Double
    public var contractNetSuccessRate: Double
    public var auctionSuccessRate: Double
    public var averageBidCount: Double
    public var averageProposalCount: Double

    public init(
        totalSessions: Int = 0,
        completedSessions: Int = 0,
        failedSessions: Int = 0,
        averageDuration: TimeInterval = 0,
        averageRounds: Double = 0,
        contractNetSuccessRate: Double = 0,
        auctionSuccessRate: Double = 0,
        averageBidCount: Double = 0,
        averageProposalCount: Double = 0
    ) {
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.failedSessions = failedSessions
        self.averageDuration = averageDuration
        self.averageRounds = averageRounds
        self.contractNetSuccessRate = contractNetSuccessRate
        self.auctionSuccessRate = auctionSuccessRate
        self.averageBidCount = averageBidCount
        self.averageProposalCount = averageProposalCount
    }
}

// MARK: - Agent Negotiation Protocol

@MainActor
public final class AgentNegotiationProtocol: ObservableObject {
    public static let shared = AgentNegotiationProtocol()

    @Published public private(set) var sessions: [UUID: NegotiationSession] = [:]
    @Published public private(set) var auctions: [UUID: Auction] = [:]
    @Published public private(set) var proposals: [UUID: NegotiationProposal] = [:]
    @Published public private(set) var bids: [UUID: AuctionBid] = [:]
    @Published public private(set) var metrics: NegotiationMetrics
    @Published public private(set) var activeSessionCount: Int = 0

    public private(set) var sessionHistory: [NegotiationSession] = []
    public private(set) var auctionHistory: [Auction] = []
    public private(set) var timeoutHandlers: [UUID: Task<Void, Never>] = [:]
    public private(set) var negotiationState: [UUID: NegotiationState] = [:]

    public private let lock = NSLock()
    public private let defaultTimeout: TimeInterval = 60
    public private let roundDuration: TimeInterval = 5
    public private var sessionCounter: Int = 0

    public init(metrics: NegotiationMetrics = .init()) {
        self.metrics = metrics
        super.init()
    }

    deinit {
        timeoutHandlers.values.forEach { $0.cancel() }
    }
}

// MARK: - Contract Net Protocol

extension AgentNegotiationProtocol {
    public func initiateContractNet(managerID: UUID, contractorIDs: [UUID], taskID: UUID, capabilities: [String], deadline: TimeInterval = 30) -> UUID {
        let session = NegotiationSession(
            participants: [managerID] + contractorIDs,
            topic: "task_\(taskID)",
            protocol: .contractNet,
            timeout: deadline,
            metadata: ["task_id": taskID.uuidString, "capabilities": capabilities.joined(separator: ",")]
        )

        sessions[session.id] = session
        startTimeoutTimer(for: session.id)

        for contractorID in contractorIDs {
            let cfp = ContractNetMessage(
                managerID: managerID,
                contractorID: contractorID,
                taskID: taskID,
                messageType: .callForProposals,
                deadline: Date().addingTimeInterval(deadline),
                metadata: ["session_id": session.id.uuidString]
            )
            sendMessage(cfp)
        }

        activeSessionCount += 1
        updateMetrics()
        return session.id
    }

    public func submitProposal(
        sessionID: UUID,
        proposerID: UUID,
        receiverID: UUID,
        taskID: UUID,
        capabilities: [String],
        offeredPrice: Double,
        estimatedDuration: TimeInterval,
        confidence: Double = 1,
        terms: [String: String] = [:]
    ) -> UUID {
        let proposal = NegotiationProposal(
            proposerID: proposerID,
            receiverID: receiverID,
            taskID: taskID,
            capabilities: capabilities,
            offeredPrice: offeredPrice,
            estimatedDuration: estimatedDuration,
            confidence: confidence,
            terms: terms
        )

        guard var session = sessions[sessionID] else { return proposal.id }
        session.proposals.append(proposal)
        sessions[sessionID] = session
        proposals[proposal.id] = proposal

        let message = ContractNetMessage(
            managerID: receiverID,
            contractorID: proposerID,
            taskID: taskID,
            messageType: .proposal,
            proposal: proposal,
            metadata: ["session_id": sessionID.uuidString]
        )
        sendMessage(message)

        updateNegotiationState(for: sessionID)
        updateMetrics()
        return proposal.id
    }

    public func evaluateProposals(_ sessionID: UUID, criteria: [String: Double] = [:]) -> NegotiationProposal? {
        guard let session = sessions[sessionID] else { return nil }
        let validProposals = session.proposals.filter { proposal in
            proposal.status == .pending && Date() < proposal.validUntil
        }

        guard !validProposals.isEmpty else { return nil }

        let weights: [String: Double] = criteria.isEmpty ? [
            "price": 0.4,
            "duration": 0.3,
            "confidence": 0.2,
            "capabilities": 0.1
        ] : criteria

        let evaluated = validProposals.map { proposal -> (proposal: NegotiationProposal, score: Double) in
            let priceScore = 1 / max(proposal.offeredPrice, 0.01)
            let durationScore = 1 / max(proposal.estimatedDuration, 0.01)
            let capabilityScore = Double(proposal.capabilities.count) / 10
            let score = priceScore * (weights["price"] ?? 0) +
                       durationScore * (weights["duration"] ?? 0) +
                       proposal.confidence * (weights["confidence"] ?? 0) +
                       capabilityScore * (weights["capabilities"] ?? 0)
            return (proposal, score)
        }

        return evaluated.max { $0.score < $1.score }?.proposal
    }

    public func awardContract(_ sessionID: UUID, proposalID: UUID) {
        guard var session = sessions[sessionID],
              let proposal = proposals[proposalID] else { return }

        session.winnerID = proposal.proposerID
        session.winningProposalID = proposalID
        session.status = .completed
        session.endTime = Date()
        sessions[sessionID] = session

        if var updatedProposal = proposals[proposalID] {
            updatedProposal.status = .awarded
            proposals[proposalID] = updatedProposal
        }

        let acceptMessage = ContractNetMessage(
            managerID: proposal.receiverID,
            contractorID: proposal.proposerID,
            taskID: proposal.taskID,
            messageType: .accept,
            proposal: proposal,
            metadata: ["session_id": sessionID.uuidString]
        )
        sendMessage(acceptMessage)

        for proposal in session.proposals where proposal.id != proposalID {
            if var rejected = proposals[proposal.id] {
                rejected.status = .rejected
                proposals[proposal.id] = rejected
            }
            let rejectMessage = ContractNetMessage(
                managerID: proposal.receiverID,
                contractorID: proposal.proposerID,
                taskID: proposal.taskID,
                messageType: .reject,
                proposal: proposal,
                metadata: ["session_id": sessionID.uuidString]
            )
            sendMessage(rejectMessage)
        }

        timeoutHandlers[sessionID]?.cancel()
        timeoutHandlers.removeValue(forKey: sessionID)
        sessionHistory.append(session)
        activeSessionCount = max(0, activeSessionCount - 1)
        updateMetrics()
    }

    public func rejectProposal(_ sessionID: UUID, proposalID: UUID) {
        guard var session = sessions[sessionID],
              var proposal = proposals[proposalID] else { return }

        proposal.status = .rejected
        proposals[proposalID] = proposal
        session.proposals.removeAll { $0.id == proposalID }
        sessions[sessionID] = session

        let rejectMessage = ContractNetMessage(
            managerID: proposal.receiverID,
            contractorID: proposal.proposerID,
            taskID: proposal.taskID,
            messageType: .reject,
            proposal: proposal,
            metadata: ["session_id": sessionID.uuidString]
        )
        sendMessage(rejectMessage)
        updateMetrics()
    }

    public func cancelSession(_ sessionID: UUID) {
        guard var session = sessions[sessionID] else { return }
        session.status = .cancelled
        session.endTime = Date()
        sessions[sessionID] = session
        timeoutHandlers[sessionID]?.cancel()
        timeoutHandlers.removeValue(forKey: sessionID)

        for proposal in session.proposals {
            if var p = proposals[proposal.id] {
                p.status = .expired
                proposals[proposal.id] = p
            }
        }

        sessionHistory.append(session)
        activeSessionCount = max(0, activeSessionCount - 1)
        updateMetrics()
    }
}

// MARK: - Auction Mechanisms

extension AgentNegotiationProtocol {
    public func startEnglishAuction(auctioneerID: UUID, taskID: UUID, startPrice: Double, participants: [UUID], roundDuration: TimeInterval = 10, maxRounds: Int = 10) -> UUID {
        let auction = Auction(
            auctioneerID: auctioneerID,
            taskID: taskID,
            auctionType: .english,
            startPrice: startPrice,
            currentPrice: startPrice,
            participants: participants,
            roundDuration: roundDuration,
            maxRounds: maxRounds
        )
        auctions[auction.id] = auction

        for participant in participants {
            let bid = AuctionBid(
                bidderID: participant,
                auctionID: auction.id,
                bidAmount: startPrice,
                estimatedValue: startPrice * 1.2
            )
            bids[bid.id] = bid
        }

        startAuctionTimer(for: auction.id)
        auctionHistory.append(auction)
        updateMetrics()
        return auction.id
    }

    public func startDutchAuction(auctioneerID: UUID, taskID: UUID, startPrice: Double, reservePrice: Double, participants: [UUID], roundDuration: TimeInterval = 5) -> UUID {
        let auction = Auction(
            auctioneerID: auctioneerID,
            taskID: taskID,
            auctionType: .dutch,
            startPrice: startPrice,
            reservePrice: reservePrice,
            currentPrice: startPrice,
            participants: participants,
            roundDuration: roundDuration,
            maxRounds: 20
        )
        auctions[auction.id] = auction
        startAuctionTimer(for: auction.id)
        auctionHistory.append(auction)
        updateMetrics()
        return auction.id
    }

    public func placeBid(auctionID: UUID, bidderID: UUID, bidAmount: Double, strategy: BiddingStrategy = .straight) -> UUID? {
        guard var auction = auctions[auctionID],
              auction.status == .open else { return nil }

        switch auction.auctionType {
        case .english:
            guard bidAmount > auction.currentPrice + auction.minBidIncrement else { return nil }
        case .dutch:
            guard bidAmount >= auction.currentPrice else { return nil }
        case .sealedBid, .vickrey, .combinatorial:
            break
        }

        let estimatedValue = bidAmount * 1.2
        let bid = AuctionBid(
            bidderID: bidderID,
            auctionID: auctionID,
            bidAmount: bidAmount,
            estimatedValue: estimatedValue,
            strategy: strategy
        )

        bids[bid.id] = bid
        auction.currentPrice = bidAmount

        if let currentRound = auction.rounds.last {
            var newRound = currentRound
            newRound.bids.append(bid)
            newRound.leadingBid = bid
            auction.rounds[auction.rounds.count - 1] = newRound
        } else {
            let newRound = AuctionRound(auctionID: auctionID, roundNumber: 1, bids: [bid])
            auction.rounds.append(newRound)
        }

        auction.participants.append(bidderID)
        auctions[auctionID] = auction
        updateMetrics()
        return bid.id
    }

    public func closeAuction(_ auctionID: UUID) {
        guard var auction = auctions[auctionID] else { return }
        auction.status = .closed
        auction.endTime = Date()

        let validBids = bids.values.filter { $0.auctionID == auctionID }
        if let winningBid = validBids.max(by: { $0.bidAmount < $1.bidAmount }) {
            auction.winnerID = winningBid.bidderID
            auction.winningBid = winningBid
            auction.status = .awarded
        }

        auctions[auctionID] = auction
        timeoutHandlers[auctionID]?.cancel()
        timeoutHandlers.removeValue(forKey: auctionID)
        updateMetrics()
    }

    public func cancelAuction(_ auctionID: UUID) {
        guard var auction = auctions[auctionID] else { return }
        auction.status = .cancelled
        auction.endTime = Date()
        auctions[auctionID] = auction
        timeoutHandlers[auctionID]?.cancel()
        timeoutHandlers.removeValue(forKey: auctionID)
        updateMetrics()
    }
}

// MARK: - Bargaining and Mediation

extension AgentNegotiationProtocol {
    public func initiateBargaining(participantIDs: [UUID], topic: String, initialOffers: [UUID: Double], timeout: TimeInterval = 45) -> UUID {
        let session = NegotiationSession(
            participants: participantIDs,
            topic: topic,
            protocol: .bargaining,
            timeout: timeout,
            metadata: ["type": "bargaining"]
        )

        for (participantID, offer) in initialOffers {
            if let session = sessions[session.id] {
                let proposal = NegotiationProposal(
                    proposerID: participantID,
                    receiverID: session.participants.first ?? participantID,
                    taskID: UUID(),
                    offeredPrice: offer,
                    terms: ["bargaining_round": "0"]
                )
                var mutableSession = session
                mutableSession.proposals.append(proposal)
                sessions[session.id] = mutableSession
                proposals[proposal.id] = proposal
            }
        }

        sessions[session.id] = session
        startTimeoutTimer(for: session.id)
        activeSessionCount += 1
        updateMetrics()
        return session.id
    }

    public func mediate(sessionID: UUID, mediatorID: UUID) -> UUID? {
        guard var session = sessions[sessionID] else { return nil }
        guard session.protocol == .bargaining else { return nil }

        if !session.participants.contains(mediatorID) {
            session.participants.append(mediatorID)
        }

        let proposals = session.proposals
        let sortedProposals = proposals.sorted { $0.offeredPrice < $1.offeredPrice }
        let midIndex = sortedProposals.count / 2
        let median = sortedProposals.count > 0 ? sortedProposals[midIndex] : nil

        if let medianProposal = median {
            let mediatorProposal = NegotiationProposal(
                proposerID: mediatorID,
                receiverID: session.participants.first ?? mediatorID,
                taskID: UUID(),
                offeredPrice: medianProposal.offeredPrice,
                terms: ["mediated": "true", "round": String(session.currentRound)]
            )
            var mutableSession = session
            mutableSession.proposals.append(mediatorProposal)
            sessions[session.id] = mutableSession
            proposals[mediatorProposal.id] = mediatorProposal
            updateMetrics()
            return mediatorProposal.id
        }
        return nil
    }
}

// MARK: - Timers and State

extension AgentNegotiationProtocol {
    private func startTimeoutTimer(for sessionID: UUID) {
        timeoutHandlers[sessionID]?.cancel()
        timeoutHandlers[sessionID] = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(defaultTimeout))
            await MainActor.run {
                self.expireSession(sessionID)
            }
        }
    }

    private func startAuctionTimer(for auctionID: UUID) {
        timeoutHandlers[auctionID]?.cancel()
        timeoutHandlers[auctionID] = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: .seconds(30))
            await MainActor.run {
                self.closeAuction(auctionID)
            }
        }
    }

    private func expireSession(_ sessionID: UUID) {
        guard var session = sessions[sessionID] else { return }
        session.status = .expired
        session.endTime = Date()
        sessions[sessionID] = session

        for proposal in session.proposals {
            if var p = proposals[proposal.id] {
                p.status = .expired
                proposals[proposal.id] = p
            }
        }

        sessionHistory.append(session)
        activeSessionCount = max(0, activeSessionCount - 1)
        updateMetrics()
    }

    private func sendMessage(_ message: ContractNetMessage) {
        AgentCommunicationBus.shared.publish(
            AgentMessage(
                senderID: message.managerID,
                recipientID: message.contractorID,
                topic: .negotiation,
                payload: try! JSONEncoder().encode(message)
            )
        )
    }

    private func updateNegotiationState(for sessionID: UUID) {
        guard let session = sessions[sessionID] else { return }
        let validProposals = session.proposals.filter { $0.status == .pending }
        negotiationState[sessionID] = NegotiationState(
            sessionID: sessionID,
            proposalCount: validProposals.count,
            currentRound: session.currentRound,
            maxRounds: session.maxRounds,
            status: session.status
        )
    }
}

// MARK: - State and Metrics

public struct NegotiationState: Sendable {
    public let sessionID: UUID
    public let proposalCount: Int
    public let currentRound: Int
    public let maxRounds: Int
    public let status: SessionStatus
}

extension AgentNegotiationProtocol {
    private func updateMetrics() {
        let completed = sessionHistory.filter { $0.status == .completed }
        let failed = sessionHistory.filter { $0.status == .failed || $0.status == .expired }
        let totalDuration = completed.compactMap { session in
            guard let end = session.endTime else { return nil }
            return end.timeIntervalSince(session.startTime)
        }
        let avgDuration = totalDuration.isEmpty ? 0 : totalDuration.reduce(0, +) / Double(totalDuration.count)

        let contractNetSessions = sessionHistory.filter { $0.protocol == .contractNet }
        let successfulContractNet = contractNetSessions.filter { $0.status == .completed }
        let auctionSessions = auctionHistory.filter { $0.status == .awarded }
        let totalAuctions = auctionHistory.count

        let avgRounds = sessionHistory.isEmpty ? 0 :
            Double(sessionHistory.map(\.currentRound).reduce(0, +)) / Double(sessionHistory.count)
        let avgBids = auctionHistory.isEmpty ? 0 :
            Double(auctionHistory.map { $0.rounds.flatMap(\.bids).count }.reduce(0, +)) / Double(max(auctionHistory.count, 1))
        let avgProposals = sessionHistory.isEmpty ? 0 :
            Double(sessionHistory.map(\.proposals.count).reduce(0, +)) / Double(max(sessionHistory.count, 1))

        metrics = NegotiationMetrics(
            totalSessions: sessionHistory.count,
            completedSessions: completed.count,
            failedSessions: failed.count,
            averageDuration: avgDuration,
            averageRounds: avgRounds,
            contractNetSuccessRate: contractNetSessions.isEmpty ? 0 : Double(successfulContractNet.count) / Double(contractNetSessions.count),
            auctionSuccessRate: totalAuctions > 0 ? Double(auctionSessions.count) / Double(totalAuctions) : 0,
            averageBidCount: avgBids,
            averageProposalCount: avgProposals
        )
    }
}

// MARK: - Query and Analysis

extension AgentNegotiationProtocol {
    public func getSession(_ sessionID: UUID) -> NegotiationSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[sessionID]
    }

    public func getAuction(_ auctionID: UUID) -> Auction? {
        lock.lock()
        defer { lock.unlock() }
        return auctions[auctionID]
    }

    public func getActiveSessions() -> [NegotiationSession] {
        lock.lock()
        defer { lock.unlock() }
        return sessions.values.filter { $0.status == .active }.sorted { $0.startTime > $1.startTime }
    }

    public func getSessionHistory(limit: Int = 50) -> [NegotiationSession] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sessionHistory.suffix(limit))
    }

    public func getAuctionHistory(limit: Int = 50) -> [Auction] {
        lock.lock()
        defer { lock.unlock() }
        return Array(auctionHistory.suffix(limit))
    }

    public func getNegotiationMetrics() -> NegotiationMetrics {
        metrics
    }

    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        sessionHistory.removeAll()
        auctionHistory.removeAll()
        proposals.removeAll()
        bids.removeAll()
    }
}
