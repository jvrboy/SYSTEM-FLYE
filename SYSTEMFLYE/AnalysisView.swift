import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var marketDataManager: MarketDataManager
    @State private var selectedPair: String = "EURUSD"
    @State private var selectedTimeframe: HistoricalDataRequest.Timeframe = .oneDay
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technical Analysis")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        
                        Text("In-depth analysis of forex pairs")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Pair Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Pair")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(marketDataManager.popularPairs, id: \.symbol) { pair in
                                    Button(action: { selectedPair = pair.symbol }) {
                                        Text(pair.symbol)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(selectedPair == pair.symbol ? .white : .gray)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedPair == pair.symbol ? Color(UIColor(red: 0.2, green: 0.5, blue: 1, alpha: 1)) : Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    // Chart Area
                    if let price = marketDataManager.currentPrices[selectedPair] {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Price Chart")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                            
                            SimpleChartView(price: price)
                                .frame(height: 200)
                                .padding(.horizontal, 20)
                        }
                        
                        Divider()
                            .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                            .padding(.vertical, 20)
                    }
                    
                    // Technical Indicators
                    if let indicators = marketDataManager.technicalIndicators[selectedPair] {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Technical Indicators")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            // RSI
                            IndicatorCard(
                                title: "Relative Strength Index (RSI)",
                                value: String(format: "%.2f", indicators.rsi),
                                max: 100,
                                status: rsiStatus(indicators.rsi),
                                description: "Momentum oscillator measuring speed and magnitude of price changes"
                            )
                            .padding(.horizontal, 20)
                            
                            // MACD
                            VStack(alignment: .leading, spacing: 12) {
                                Text("MACD (Moving Average Convergence Divergence)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    MetricColumn(
                                        label: "MACD Line",
                                        value: String(format: "%.5f", indicators.macd.macdLine)
                                    )
                                    
                                    MetricColumn(
                                        label: "Signal Line",
                                        value: String(format: "%.5f", indicators.macd.signalLine)
                                    )
                                    
                                    MetricColumn(
                                        label: "Histogram",
                                        value: String(format: "%.5f", indicators.macd.histogram),
                                        color: indicators.macd.histogram > 0 ? .green : .red
                                    )
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            
                            // Bollinger Bands
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Bollinger Bands")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Upper")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(String(format: "%.5f", indicators.bollingerBands.upper))
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.red)
                                    }
                                    
                                    HStack {
                                        Text("Middle (SMA)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(String(format: "%.5f", indicators.bollingerBands.middle))
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    HStack {
                                        Text("Lower")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(String(format: "%.5f", indicators.bollingerBands.lower))
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            
                            // Moving Averages
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Moving Averages")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 10) {
                                    MABox(label: "MA20", value: indicators.movingAverages.ma20)
                                    MABox(label: "MA50", value: indicators.movingAverages.ma50)
                                    MABox(label: "MA100", value: indicators.movingAverages.ma100)
                                    MABox(label: "MA200", value: indicators.movingAverages.ma200)
                                }
                            }
                            .padding(16)
                            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            
                            // Volatility and ATR
                            if let analysis = marketDataManager.marketAnalysis[selectedPair] {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 12) {
                                        MetricColumn(
                                            label: "Volatility",
                                            value: String(format: "%.2f%%", analysis.volatility)
                                        )
                                        
                                        MetricColumn(
                                            label: "ATR",
                                            value: String(format: "%.5f", indicators.atr)
                                        )
                                        
                                        MetricColumn(
                                            label: "BB Width",
                                            value: String(format: "%.2f%%", indicators.bollingerBands.bandwidth)
                                        )
                                    }
                                }
                                .padding(16)
                                .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .background(Color(UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)))
        }
    }
    
    private func rsiStatus(_ rsi: Double) -> String {
        if rsi > 70 {
            return "Overbought"
        } else if rsi < 30 {
            return "Oversold"
        } else {
            return "Neutral"
        }
    }
}

struct SimpleChartView: View {
    let price: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Price")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text(String(format: "%.5f", price))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("24h Change")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("+0.35%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
            .cornerRadius(8)
            
            // Simple line visualization
            Canvas { context, size in
                let width = min(300.0, size.width)
                let height = 120.0
                
                // Draw grid
                let gridColor = Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1))
                
                for i in stride(from: 0, to: Int(height), by: 20) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: CGFloat(i)))
                    path.addLine(to: CGPoint(x: width, y: CGFloat(i)))
                    context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
                }
                
                // Draw sample curve
                var path = Path()
                for i in 0..<50 {
                    let x = (width / 50) * CGFloat(i)
                    let y = height / 2 + CGFloat(sin(Double(i) * 0.2) * 30)
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                context.stroke(path, with: .color(.blue), lineWidth: 2)
            }
            .frame(height: 80)
            .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
            .cornerRadius(8)
        }
    }
}

struct IndicatorCard: View {
    let title: String
    let value: String
    let max: Double
    let status: String
    let description: String
    
    var statusColor: Color {
        switch status {
        case "Overbought":
            return .red
        case "Oversold":
            return .green
        default:
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(status)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * CGFloat(Double(value) ?? 0 / max))
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)))
        .cornerRadius(12)
    }
}

struct MetricColumn: View {
    let label: String
    let value: String
    var color: Color = .white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MABox: View {
    let label: String
    let value: Double
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            
            Text(String(format: "%.5f", value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)))
        .cornerRadius(6)
    }
}

#Preview {
    AnalysisView()
        .environmentObject(MarketDataManager())
}
