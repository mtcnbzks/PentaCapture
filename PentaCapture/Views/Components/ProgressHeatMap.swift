//
//  ProgressHeatMap.swift
//  PentaCapture
//
//  Created for Smile Hair Clinic Hackathon
//

import SwiftUI

/// Heat map showing difficulty/time spent on each angle
/// Provides insights into user experience and challenging angles
struct ProgressHeatMap: View {
    let angleStats: [AngleStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                
                Text("Çekim İstatistikleri")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Legend
                HStack(spacing: 12) {
                    LegendItem(color: .green, label: "Kolay")
                    LegendItem(color: .yellow, label: "Orta")
                    LegendItem(color: .red, label: "Zor")
                }
                .font(.caption2)
            }
            
            // Heat map bars
            VStack(spacing: 12) {
                ForEach(angleStats) { stat in
                    AngleStatRow(stat: stat)
                }
            }
            
            // Summary
            if !angleStats.isEmpty {
                HeatMapSummary(stats: angleStats)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// Note: AngleStats is now defined in CaptureSession.swift and shared across the app

/// Single row for angle stat
struct AngleStatRow: View {
    let stat: AngleStats
    @State private var animateBar = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Angle icon
            Image(systemName: stat.angle.symbolName)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30)
            
            // Angle name
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.angle.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if stat.isCompleted {
                    Text("\(Int(stat.timeSpent))s • \(stat.attempts) deneme")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Henüz çekilmedi")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Difficulty bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 24)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(stat.difficulty.color)
                    .frame(width: animateBar ? barWidth : 0, height: 24)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateBar)
                
                // Difficulty label
                Text(stat.difficulty.label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }
            
            // Status icon
            if stat.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .onAppear {
            animateBar = true
        }
    }
    
    private var barWidth: CGFloat {
        if !stat.isCompleted { return 0 }
        // Normalize time spent to 0-80 width
        let maxTime: CGFloat = 30
        let normalizedTime = min(CGFloat(stat.timeSpent), maxTime)
        return (normalizedTime / maxTime) * 80
    }
}

/// Heat map summary
struct HeatMapSummary: View {
    let stats: [AngleStats]
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, 4)
            
            HStack(spacing: 20) {
                // Total time
                SummaryItem(
                    icon: "clock.fill",
                    value: formatTime(totalTime),
                    label: "Toplam Süre"
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 30)
                
                // Average attempts
                SummaryItem(
                    icon: "repeat.circle.fill",
                    value: String(format: "%.1f", averageAttempts),
                    label: "Ort. Deneme"
                )
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .frame(height: 30)
                
                // Hardest angle
                if let hardest = hardestAngle {
                    SummaryItem(
                        icon: "exclamationmark.triangle.fill",
                        value: hardest.title,
                        label: "En Zor"
                    )
                }
            }
        }
    }
    
    private var totalTime: TimeInterval {
        stats.reduce(0) { $0 + $1.timeSpent }
    }
    
    private var averageAttempts: Double {
        let completed = stats.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        return Double(completed.reduce(0) { $0 + $1.attempts }) / Double(completed.count)
    }
    
    private var hardestAngle: CaptureAngle? {
        stats.filter { $0.isCompleted }
            .max(by: { $0.timeSpent < $1.timeSpent })?
            .angle
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }
}

/// Summary item component
struct SummaryItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Legend item
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

/// Compact heat map (for in-flow display)
struct CompactHeatMap: View {
    let angleStats: [AngleStats]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(angleStats) { stat in
                VStack(spacing: 4) {
                    Image(systemName: stat.angle.symbolName)
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Circle()
                        .fill(stat.difficulty.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
    }
}

// MARK: - Preview
#if DEBUG
struct ProgressHeatMap_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                ProgressHeatMap(angleStats: [
                    AngleStats(angle: .frontFace, attempts: 1, timeSpent: 3.5, isCompleted: true),
                    AngleStats(angle: .rightProfile, attempts: 2, timeSpent: 8.2, isCompleted: true),
                    AngleStats(angle: .leftProfile, attempts: 1, timeSpent: 5.1, isCompleted: true),
                    AngleStats(angle: .vertex, attempts: 4, timeSpent: 18.7, isCompleted: true),
                    AngleStats(angle: .donorArea, attempts: 3, timeSpent: 15.3, isCompleted: true)
                ])
                
                Spacer()
            }
            .padding()
        }
    }
}
#endif

