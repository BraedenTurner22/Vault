//
//  AppList.swift
//  vault
//
//  Created by Braeden Turner on 2025-11-08
//  Full App List with bundle IDs and dynamic icon fetching
//

import Foundation

// MARK: - Model
struct MockApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    var iconURL: URL? = nil
}

// MARK: - App Store API Fetcher
struct AppIconFetcher {
    static func fetchIconURL(for bundleId: String, completion: @escaping (URL?) -> Void) {
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let iconString = first["artworkUrl512"] as? String,
                  let iconURL = URL(string: iconString) else {
                completion(nil)
                return
            }

            completion(iconURL)
        }.resume()
    }
}

// MARK: - App List
struct AppList {
    static var popularApps: [MockApp] = [
        // Top priority apps
        MockApp(name: "Instagram", bundleId: "com.burbn.instagram"),
        MockApp(name: "Snapchat", bundleId: "com.toyopagroup.picaboo"),

        // Social Media
        MockApp(name: "TikTok", bundleId: "com.zhiliaoapp.musically"),
        MockApp(name: "X", bundleId: "com.atebits.Tweetie2"),
        MockApp(name: "Facebook", bundleId: "com.facebook.Facebook"),
        MockApp(name: "Reddit", bundleId: "com.reddit.Reddit"),
        MockApp(name: "LinkedIn", bundleId: "com.linkedin.LinkedIn"),
        MockApp(name: "Pinterest", bundleId: "pinterest"),
        MockApp(name: "Discord", bundleId: "com.hammerandchisel.discord"),

        // Entertainment
        MockApp(name: "YouTube", bundleId: "com.google.ios.youtube"),
        MockApp(name: "Netflix", bundleId: "com.netflix.Netflix"),
        MockApp(name: "Hulu", bundleId: "com.hulu.plus"),
        MockApp(name: "Twitch", bundleId: "tv.twitch"),
        MockApp(name: "Spotify", bundleId: "com.spotify.client"),

        // Gaming
        MockApp(name: "Roblox", bundleId: "com.roblox.robloxmobile"),
        MockApp(name: "Minecraft", bundleId: "com.mojang.minecraftpe"),
        MockApp(name: "Among Us", bundleId: "com.innersloth.amongus"),

        // News & Reading
        MockApp(name: "Apple News", bundleId: "com.apple.news"),
        MockApp(name: "Medium", bundleId: "com.medium.reader"),

        // Shopping
        MockApp(name: "Amazon", bundleId: "com.amazon.Amazon"),
        MockApp(name: "Etsy", bundleId: "com.etsy.etsyforios"),

        // Productivity
        MockApp(name: "Slack", bundleId: "com.tinyspeck.chatlyio"),
        MockApp(name: "Zoom", bundleId: "us.zoom.videomeetings"),

        // Other
        MockApp(name: "WhatsApp", bundleId: "net.whatsapp.WhatsApp"),
        MockApp(name: "Telegram", bundleId: "ph.telegra.Telegraph"),
        MockApp(name: "Chrome", bundleId: "com.google.chrome.ios"),
        MockApp(name: "Safari", bundleId: "com.apple.mobilesafari"),
    ]
}
