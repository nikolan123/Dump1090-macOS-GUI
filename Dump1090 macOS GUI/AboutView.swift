//
//  AboutView.swift
//  Dump1090 macOS GUI
//
//  Created by Niko on 27.08.25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            VStack {
                Spacer()
                Image(nsImage: NSApp.applicationIconImage)
                Spacer()
                VStack {
                    Text("Dump1090 macOS GUI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Commit TBD")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Link(destination: URL(string: "https://github.com/nikolan123/Dump1090-macOS-GUI")!) {
                            HStack {
                                Image(colorScheme == .dark ? "github-mark-white" : "github-mark")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                Text("GitHub Repository")
                            }
                        }
                        Text("•")
                        Link("Licenses", destination: URL(string: "https://github.com/nikolan123/Dump1090-macOS-GUI/tree/main/licenses")!)
                    }
                    .font(.caption)
                    .padding()
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                    
                }
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Preview
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            AboutView()
                .preferredColorScheme(.light)
            
            AboutView()
                .preferredColorScheme(.dark)
        }
        .frame(width: 500, height: 300)
    }
}
