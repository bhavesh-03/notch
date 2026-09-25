//
//  ContentView.swift
//  Notch
//
//  Created by Vineet Parmar on 25/09/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isExpanded = false;
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(.black)
                .frame(width: isExpanded ? 400 : 200,
                       height: isExpanded ? 150 : 32)
                .overlay {
                    HStack(spacing: 8) {
                        Image(systemName: "battery.100")
                        if (isExpanded) {
                            Text("Hello from inside the Notch")
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .foregroundStyle(.white)
                }
                .onTapGesture {
                    withAnimation(.snappy) {
                        isExpanded.toggle()
                    }
                }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
