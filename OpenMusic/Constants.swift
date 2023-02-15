//
//  Constants.swift
//  OpenMusic
//
//  Created by Matteo Riva on 08/09/2016.
//  Copyright © 2016 Matteo Riva. All rights reserved.
//

import UIKit

enum TouchActions: String {
    case shuffleAll = "it.teoriva.MeratiMusic.shuffleAll"
    case playFavorites = "it.teoriva.MeratiMusic.playTopSongs"
    case findSong = "it.teoriva.MeratiMusic.findNewSong"
}

extension NSNotification.Name {
    static let AppStatusDidChange = Notification.Name(rawValue: "AppStatusDidChange")
}
