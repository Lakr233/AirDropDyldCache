//
//  dispatchJobs.swift
//  dropDyld
//
//  Created by Lakr Aream on 2021/7/28.
//

import UIKit
import ZipArchive

extension UIWindow {
    func targetViewController() -> UIViewController? {
        var head = rootViewController
        while let next = head?.presentedViewController {
            head = next
        }
        return head
    }
}

private var kProgressLocked = NSLock()

func startJobs(inWindow window: UIWindow) {
    
    if !kProgressLocked.try() {
        print("another operation is processing")
        return
    }
    
    let blocker = DispatchSemaphore(value: 0)
    var alertDecision = true
    
    func blockForAlertAnimation() {
        alertDecision = true
        while alertDecision {
            asyncMain {
                if !(window.targetViewController() is UIAlertController) {
                    alertDecision = false
                }
                blocker.signal()
            }
            blocker.wait()
            usleep(500)
        }
    }
    
    DispatchQueue.global().async {
        
        defer {
            kProgressLocked.unlock()
        }
        
        // 拷贝
        do {
            var alert: UIAlertController?
            do {
                asyncMain {
                    alert = UIAlertController(title: "⏳", message: "正在复制目标缓存文件，请稍后。", preferredStyle: .alert)
                    window.targetViewController()?.present(alert!, animated: true, completion: nil)
                }
                try duplicateCacheToDocumentDir()
                asyncMain {
                    alert?.dismiss(animated: true, completion: nil)
                }
            } catch {
                asyncMain {
                    alert!.dismiss(animated: true, completion: nil)
                    let errorAlert = UIAlertController(title: "❌", message: "无法复制缓存文件\n\(error.localizedDescription)", preferredStyle: .alert)
                    window.targetViewController()?.present(errorAlert, animated: true, completion: nil)
                }
                return
            }
        }
        blockForAlertAnimation()
                
        // 压缩
        var targetArchive: URL
        do {
            var alert: UIAlertController?
            do {
                asyncMain {
                    alert = UIAlertController(title: "⏳", message: "正在压缩目标缓存文件，请稍后！", preferredStyle: .alert)
                    window.targetViewController()?.present(alert!, animated: true, completion: nil)
                }
                targetArchive = try compressTarget()
                asyncMain {
                    alert?.dismiss(animated: true, completion: nil)
                }
            } catch {
                asyncMain {
                    alert!.dismiss(animated: true, completion: nil)
                    let errorAlert = UIAlertController(title: "❌", message: "无法复制缓存文件\n\(error.localizedDescription)", preferredStyle: .alert)
                    window.targetViewController()?.present(errorAlert, animated: true, completion: nil)
                }
                return
            }
        }
        blockForAlertAnimation()
        
        // 分享
        print("archive available at: \(targetArchive.path)")
        asyncMain {
            let shareSheet = UIActivityViewController(activityItems: [targetArchive], applicationActivities: nil)
            shareSheet.popoverPresentationController?.sourceView = UIView()
            window.targetViewController()?.present(shareSheet, animated: true, completion: nil)
        }
    }
    
    
}

func asyncMain(_ job: @escaping () -> ()) {
    DispatchQueue.main.async {
        job()
    }
}

func duplicateCacheToDocumentDir() throws {
    let copyFrom = "/System/Library/Caches/com.apple.dyld"
    let documentDirectoryURL = try FileManager
        .default
        .url(for: .documentDirectory,
             in: .userDomainMask,
             appropriateFor: nil,
             create: true)
    let copyTo = documentDirectoryURL.appendingPathComponent("dyld")
    try? FileManager.default.removeItem(at: copyTo)
    try FileManager.default.copyItem(atPath: copyFrom, toPath: copyTo.path)
}

func compressTarget() throws -> URL {
    let documentDirectoryURL = try FileManager
        .default
        .url(for: .documentDirectory,
             in: .userDomainMask,
             appropriateFor: nil,
             create: true)
    let compressDir = documentDirectoryURL.appendingPathComponent("dyld")
    let compressWriteTo = documentDirectoryURL.appendingPathComponent("dyld.zip")
    try? FileManager.default.removeItem(at: compressWriteTo)
    SSZipArchive.createZipFile(atPath: compressWriteTo.path, withContentsOfDirectory: compressDir.path)
    return compressWriteTo
}
