//
//  FilosHelpers.swift
//  Filos
//
//  Created by lunginspector on 7/22/26.
//

import Darwin
import SwiftUI

enum FolderType {
    case normal, bundle, container
}

func getFolderType(url: URL) -> FolderType {
    let parent = url.deletingLastPathComponent().path
    
    if parent == FSPaths.appBundles {
        return .bundle
    } else if parent == FSPaths.appContainers {
        return .container
    }
    return .normal
}

// skidded from worse_query. thx forcequit 1000x!!
func getBIDFromXattr(_ url: URL) -> String? {
    let handle = wq.grantAccess(path: url.path).1
    guard handle >= 0 else { return nil }
    defer { wq.releaseHandle(handle) }

    var buf = [CChar](repeating: 0, count: 512)
    let len = getxattr(url.path, "com.apple.containermanager.identifier", &buf, 511, 0, 0)
    let xattrError: Int32? = len < 0 ? errno : nil

    if len > 0 {
        let bid = String(cString: buf)
        if !bid.isEmpty {
            return bid
        }
    }

    // Some containers do not expose an identifier xattr. Try their metadata
    // while the container's sandbox extension is still held.
    let metadataNames = [
        ".com.apple.mobile_container_manager.metadata.plist",
        "com.apple.mobile_container_manager.metadata.plist"
    ]
    for name in metadataNames {
        let metadataURL = url.appendingPathComponent(name)
        if let data = try? Data(contentsOf: metadataURL),
           let bid = metadataID(from: data),
           !bid.isEmpty {
            return bid
        }
    }

    if let xattrError {
        print("failed to read xattr: \(String(cString: strerror(xattrError))) (errno \(xattrError))")
    }
    print("(fs) failed to identify container: \(url.path)")
    return nil
}

func metadataID(from data: Data) -> String? {
    let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    return plist?["MCMMetadataIdentifier"] as? String
}

func readMetaKey(at url: URL, key: String) -> String? {
    if url.path.contains("/var/mobile/Containers/Shared/AppGroup") && ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26 {
        let handle = worse_query(url.path, group, true, false)
        guard handle >= 0 else { return nil }
        do { worse_query_release(handle) }
    } else {
        let handle = worse_query(url.path, group, false, false)
        guard handle >= 0 else { return nil }
        do { worse_query_release(handle) }
    }
     
    guard let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
        return nil
    }

    return plist[key] as? String
}

enum SysBID {
    static var phone = "com.apple.mobilephone"
    static var poster = "com.apple.PosterBoard"
}
