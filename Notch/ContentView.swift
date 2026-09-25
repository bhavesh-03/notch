//
//  ContentView.swift
//  Notch
//
//  Created by Vineet Parmar on 25/09/26.
//

import SwiftUI

struct ContentView: View {
    
    let viewModel: NotchViewModel
    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: viewModel.isExpanded ? 24 : 10,
            bottomTrailingRadius: viewModel.isExpanded ? 24 : 10
        )
    }
    
    var body: some View {
        notchShape.fill(.black)
            .frame(width: viewModel.isExpanded ? 400 : 179,
                   height: viewModel.isExpanded ? 150 : 32
            )
            .overlay {
                HStack(spacing: 8) {
                    Image(systemName: "battery.100")
                    if viewModel.isExpanded {
                        Text("Hello from inside the Notch")
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .foregroundStyle(.white)
            }
            .clipShape(notchShape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    ContentView(viewModel: NotchViewModel())
}

#Preview("Expanded") {
    let model = NotchViewModel()
    model.isExpanded = true
    return ContentView(viewModel: model)
        .frame(width: 400, height: 150)
}
