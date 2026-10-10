//
//  DateSerial.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Excel stores a date as a day count from 1900 — and, for compatibility
//  with Lotus 1-2-3, believes 29 February 1900 existed. So 1 March 1900 is
//  day 61, not 60, and every date after it is one more than the arithmetic
//  says. The 1904 system (old Mac workbooks) has no such day.
//

import Foundation

/// Calendar dates to Excel day numbers and back.
enum DateSerial {

    /// The day number for a date.
    static func serial(year: Int, month: Int, day: Int, uses1904: Bool = false) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let epoch = calendar.date(from: DateComponents(year: uses1904 ? 1904 : 1899, month: uses1904 ? 1 : 12,
                                                       day: uses1904 ? 1 : 31))!
        var days = calendar.dateComponents([.day], from: epoch, to: date).day!
        if !uses1904, days >= 60 { days += 1 }   // the day that never was
        return days
    }

    /// The date for a day number.
    static func date(serial: Int, uses1904: Bool = false) -> (year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var days = serial
        if !uses1904, days > 60 { days -= 1 }
        let epoch = calendar.date(from: DateComponents(year: uses1904 ? 1904 : 1899, month: uses1904 ? 1 : 12,
                                                       day: uses1904 ? 1 : 31))!
        let date = calendar.date(byAdding: .day, value: days, to: epoch)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year!, parts.month!, parts.day!)
    }
}
