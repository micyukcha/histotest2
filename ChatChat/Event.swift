//
//  Event.swift
//  ChatChat
//
//  Created by Michael Chang on 11/17/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import Foundation

internal class Event {
    internal let event_id: String
    internal let event_title: String
    internal let event_year: String
    //    internal let monthday: String?
    //    internal let sentiment_polarity: Double
    //    internal let sentiment_subjectivity: Double?
    internal let title: String
    
    //    init(event_id: Int, event_title: String, event_year: String, monthday: String, sentiment_polarity: Double, sentiment_subjectivity: Double, title: String) {
    //        self.event_id = event_id
    //        self.event_title = event_title
    //        self.event_year = event_year
    //        self.monthday = monthday
    //        self.sentiment_polarity = sentiment_polarity
    //        self.sentiment_subjectivity = sentiment_subjectivity
    //        self.title = title
    //    }
    
    init(event_id: String,
         event_title: String,
         event_year: String,
         title: String) {
        self.event_id = event_id
        self.event_title = event_title
        self.event_year = event_year
        //        self.monthday = monthday
        //        self.sentiment_polarity = sentiment_polarity
        //        self.sentiment_subjectivity = sentiment_subjectivity
        self.title = title
    }
}
