import SwiftUI
#if canImport(Core)
import Core
#endif

/// Card that displays pairing status for a child's devices
struct PairingStatusCard: View {
    let pairings: [ChildDevicePairing]
    let onRevokePairing: (String) -> Void // deviceId
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text("Device Pairing")
                    .font(.headline)
                
                Spacer()
            }
            
            if pairings.isEmpty {
                emptyState
            } else {
                pairedDevicesList
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("No devices paired")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Generate a pairing code to link your child's device")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private var pairedDevicesList: some View {
        VStack(spacing: 12) {
            ForEach(pairings, id: \.deviceId) { pairing in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDeviceName(from: pairing.deviceId))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Paired \(pairing.pairedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        onRevokePairing(pairing.deviceId)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
                
                if pairing != pairings.last {
                    Divider()
                }
            }
        }
    }
    
    private func getDeviceName(from deviceId: String) -> String {
        // In a real implementation, we might store device names
        // For now, we'll just show a generic name with the device ID
        return "Device \(deviceId.prefix(8))"
    }
}

#Preview {
    PairingStatusCard(
        pairings: [
            ChildDevicePairing(
                childId: ChildID("child-1"),
                deviceId: "device-123456789",
                pairedAt: Date().addingTimeInterval(-86400), // 1 day ago
                pairingCode: "123456"
            ),
            ChildDevicePairing(
                childId: ChildID("child-1"),
                deviceId: "device-987654321",
                pairedAt: Date().addingTimeInterval(-3600), // 1 hour ago
                pairingCode: "654321"
            )
        ],
        onRevokePairing: { _ in }
    )
    .padding()
}