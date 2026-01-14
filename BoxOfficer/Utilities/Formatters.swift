//
//  Formatters.swift
//  BoxOfficer
//
//  Created by Nick Spiro on 10/13/25.
//

import Foundation

struct Formatters {
    static func currency(amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 0
        
        if abs(amount) >= 1_000_000_000 {
            let billions = Double(amount) / 1_000_000_000
            return "$\(String(format: "%.1f", billions))B"
        } else if abs(amount) >= 1_000_000 {
            let millions = Double(amount) / 1_000_000
            return "$\(String(format: "%.1f", millions))M"
        } else if abs(amount) >= 1_000 {
            let thousands = Double(amount) / 1_000
            return "$\(String(format: "%.1f", thousands))K"
        } else {
            return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        }
    }
    
    static func releaseDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
