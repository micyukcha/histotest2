//
//  Date.swift
//  ChatChat
//
//  Created by Michael Chang on 12/6/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import Foundation

extension DateFormatter {
    convenience init(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) {
        self.init()
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }
}

extension Date {
    struct Formatter {
        static let datetime = DateFormatter(dateStyle: .medium, timeStyle: .medium)
    }
    
    var datetime: String {
        return Formatter.datetime.string(from: self)
    }
}
