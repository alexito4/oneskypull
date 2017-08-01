//
//  main.swift
//  oneskypull
//
//  Created by Alejandro Martinez on 22/01/2017.
//  Copyright © 2017 Alejandro Martinez. All rights reserved.
//

import Foundation

let keychain = KeychainSwift()

let ApiKey = ensure({
    keychain.get("OneSkyApiKey")
}, orSave: {
    _ = keychain.set($0, forKey: "OneSkyApiKey", withAccess: .accessibleAfterFirstUnlock)
}, byAsking: "Enter your OneSky API Key:")

let ApiSecret = ensure({
    keychain.get("OneSkyApiSecret")
}, orSave: {
    _ = keychain.set($0, forKey: "OneSkyApiSecret", withAccess: .accessibleAfterFirstUnlock)
}, byAsking: "Enter your OneSky API Secret:")

let ProjectId = ensure({
    UserDefaults.standard.string(forKey: "OneSkyProjectId")
}, orSave: {
    UserDefaults.standard.set($0, forKey: "OneSkyProjectId")
}, byAsking: "Enter your OneSky Project Id:")

let timestamp = String(Int(Date().timeIntervalSince1970))

let devHash = (timestamp + ApiSecret).md5
print(devHash)

class OneSky {
    
    let key: String
    let secret: String
    
    init(key: String, secret: String) {
        self.key = key
        self.secret = secret
    }
    
    // https://platform.api.onesky.io/1/projects/\(ProjectId)/files"
    
    struct Language {
        let code: String
        let isBase: Bool
    }
    
    func languages(for project: String) throws -> [Language] {
        let urlString = "https://platform.api.onesky.io/1/projects/\(ProjectId)/languages"
        
        let (responseData, _, error) = request(urlString: urlString)
        
        guard error == nil else {
            throw error!
        }
        
        guard let data = responseData else {
            throw "No data"
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? JSON else {
            throw "No valid JSON"
        }
        
        guard let langs = json["data"] as? Array<JSON> else {
            throw "JSON: No languages"
        }
        
        return try langs.map {
            
            guard let code = $0["code"] as? String else {
                throw "No langauge code as String"
            }
            
            guard let isBase = $0["is_base_language"] as? Bool else {
                throw "No is base language as Int"
            }
            
            return Language(code: code, isBase: isBase )
        }
    }
    
    struct FileExport {
        let name: String
        let language: String
        let filePath: URL
        
        init(name: String, language: Language, languagesDirectory: URL) {
            self.name = name
            self.language = language.code
            
            let languageCode: String
            if language.isBase {
                var baseCode = self.language
                // OneSky base language "en_GB", Project language is just "en"
                baseCode = baseCode.substring(to: baseCode.index(baseCode.startIndex, offsetBy: 2))
                languageCode = baseCode
            } else {
                languageCode = self.language
            }
            
            self.filePath = languagesDirectory
                .appendingPathComponent("\(languageCode).lproj", isDirectory: true)
                .appendingPathComponent(name)
        }
    }
    
    func export(file: FileExport, for project: String) throws {
        let urlString = "https://platform.api.onesky.io/1/projects/\(ProjectId)/translations"
        
        let params = [
            "locale": file.language,
            "source_file_name": file.name,
            "export_file_name": file.name
        ]
        let (responseData, urlResponse, error) = request(urlString: urlString, params: params)
        
        guard error == nil else {
            throw error!
        }
        
        guard let response = urlResponse as? HTTPURLResponse else {
            throw "No Response"
        }

        guard response.statusCode == 200 else {
            throw "File not ready. Unexpected status code \(response.statusCode)"
        }
        
        guard let data = responseData else {
            throw "No data"
        }
        
        print(">>> Writing in \(file.filePath)")
        do {
            let directory = file.filePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: file.filePath)
        } catch {
            print(error)
            throw error
        }
        print(">>> Written in \(file.filePath)")
    }
    
    private func request(urlString: String, params: Dictionary<String, String> = [:]) -> (Data?, URLResponse?, Error?) {
        var components = URLComponents(string: urlString)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: ApiKey),
            URLQueryItem(name: "timestamp", value: timestamp),
            URLQueryItem(name: "dev_hash", value: devHash)
        ] + params.map({ URLQueryItem(name: $0, value: $1) })
        let url = components.url!
        print(url)
        let request = URLRequest(url: url)
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["content-type" : "application/json"]
        
        let session = URLSession(configuration: config)
        return session.synchronousDataTask(with: request)
    }
    
}

let OS = OneSky(key: ApiKey, secret: ApiSecret)

let languages: [OneSky.Language] = try OS.languages(for: ProjectId)

// Modify this if you have the project in another folder
let languagesFolder = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("wa-ios", isDirectory: true)
    .appendingPathComponent("WorkAngel", isDirectory: true)
    .appendingPathComponent("Supporting Files", isDirectory: true)

let files = [
    "InfoPlist.strings",
    "Localizable.strings",
    "Localizable.stringsdict"
]

for lang in languages {
    for file in files {
        try OS.export(file: OneSky.FileExport(name: file, language: lang, languagesDirectory: languagesFolder), for: ProjectId)
    }
}
