import SwiftUI

/// Standard loading / empty / error states used across feature screens.

/// Full-screen loading state (used at splash + first data load).
struct GagLoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: GagShapes.spacingM) {
            ProgressView()
                .tint(GagColors.brandOrange)
                .scaleEffect(1.3)
            Text(message)
                .font(GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GagColors.background)
    }
}

/// Centered empty state with icon + message.
struct GagEmptyView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: GagShapes.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(GagColors.onSurfaceDim)
            Text(title)
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
            if let message {
                Text(message)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                GagButton(title: actionTitle, style: .secondary, action: action)
                    .frame(width: 200)
            }
        }
        .padding(GagShapes.spacingXXL)
        .frame(maxWidth: .infinity)
        .background(GagColors.background)
    }
}

/// Centered error state with retry.
struct GagErrorView: View {
    let message: String
    var retryTitle: String = "Try Again"
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: GagShapes.spacingM) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(GagColors.error)
            Text("Something went wrong")
                .font(GagTypography.titleMedium)
                .foregroundStyle(GagColors.onSurface)
            Text(message)
                .font(GagTypography.bodyMedium)
                .foregroundStyle(GagColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            if let onRetry {
                GagButton(title: retryTitle, style: .secondary, action: onRetry)
                    .frame(width: 180)
            }
        }
        .padding(GagShapes.spacingXXL)
        .frame(maxWidth: .infinity)
        .background(GagColors.background)
    }
}

/// Banner shown when the backend anon key hasn't been configured yet.
struct GagNotConfiguredBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: GagShapes.spacingS) {
            Image(systemName: "key.slash")
                .foregroundStyle(GagColors.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Backend not configured")
                    .font(GagTypography.labelLarge)
                    .foregroundStyle(GagColors.onSurface)
                Text("Paste your Supabase anon key into Core/Config/Secrets.swift and rebuild.")
                    .font(GagTypography.labelMedium)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(GagShapes.spacingM)
        .background(GagColors.surfaceVariant)
        .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))
    }
}
