//
//  SymbolCell.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct SymbolCell: View {
    let name: String
    let isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
                    Image(systemName: name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .frame(width: 56, height: 56)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(height: 28)
        }
        .frame(width: 80, height: 90)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
