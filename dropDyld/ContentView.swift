//
//  ContentView.swift
//  dropDyld
//
//  Created by Lakr Aream on 2021/7/28.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var windowObserver = WindowObserver()
    
    var body: some View {
        Button(action: {
            startJobs(inWindow: windowObserver.window!)
        }, label: {
            Text("AirDrop my dyld cache now!")
                .bold()
        })
        .background(
            HostingWindowFinder { [weak windowObserver] window in
                windowObserver?.window = window
            }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#if canImport(UIKit)
    typealias Window = UIWindow
#elseif canImport(AppKit)
    typealias Window = NSWindow
#else
    #error("Unsupported platform")
#endif

class WindowObserver: ObservableObject {
    weak var window: Window?
}

#if canImport(UIKit)
    struct HostingWindowFinder: UIViewRepresentable {
        var callback: (Window?) -> Void

        func makeUIView(context _: Context) -> UIView {
            let view = UIView()
            DispatchQueue.main.async { [weak view] in
                self.callback(view?.window)
            }
            return view
        }

        func updateUIView(_: UIView, context _: Context) {}
    }

#elseif canImport(AppKit)
    struct HostingWindowFinder: NSViewRepresentable {
        var callback: (Window?) -> Void

        func makeNSView(context _: Self.Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async { [weak view] in
                self.callback(view?.window)
            }
            return view
        }

        func updateNSView(_: NSView, context _: Context) {}
    }
#else
    #error("Unsupported platform")
#endif
