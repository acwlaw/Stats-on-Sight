//
//  Payload.swift
//  Stats on Sight
//
//  Created by Alex Law on 2020-01-11.
//  Copyright © 2020 Alex Law. All rights reserved.
//

import Foundation

class Payload: Decodable {
    let homeTeam: TeamPayload
    let awayTeam: TeamPayload
    
    enum CodingKeys: String, CodingKey {
        case homeTeam = "home", awayTeam = "away"
    }
}

class TeamPayload: Decodable {
    let name: String
    let onIce: [Players]
    let goals: Int
    let abbreviation: String
    
    enum CodingKeys: String, CodingKey {
        case name, onIce, goals, abbreviation
    }
}

class Players: Decodable {
    let fullName: String
    let number: String
    let positionCode: String
    
    enum CodingKeys: String, CodingKey {
        case fullName, number, positionCode
    }
}
