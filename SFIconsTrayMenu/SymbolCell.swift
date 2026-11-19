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
    /// Double-click copies the symbol's name.
    var onDoubleTap: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 4) {
            // The catalog only contains symbols this Mac can render, so no existence check.
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 56, height: 56)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
            
            Text(name)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(height: 28)
        }
        .frame(width: 80, height: 90)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onTap() }
    }
}
